// The screenshot editor's logic, free of QML: its options and what it remembers,
// the elements it draws (plain data, in the picture's own pixels, so what is
// shown is what is exported), the undo history, the arrow head, the view's
// scale and the keys. `editor` is `VitrailTokens.capture.editor`.
.pragma library
.import "../kit/color.js" as Color

// The tools, in the order of the tool row, and the letter that picks each one.
var tools = [
    { key: "pencil", letter: "P" },
    { key: "text", letter: "T" },
    { key: "shape", letter: "F" },
    { key: "arrow", letter: "A" }
]

function toolOf(name) {
    for (var index = 0; index < tools.length; index++) {
        if (tools[index].key === name)
            return name
    }
    return "pencil"
}

// --- options ------------------------------------------------------------------

function defaults(editor) {
    var start = editor.color.start
    return {
        pencil: { color: start, width: editor.pen.width.value, opacity: editor.pen.opacity.value, mode: "normal" },
        text: { color: start, size: editor.text.size.value, bold: false, background: "none" },
        shape: { kind: "rect", color: start, width: editor.shape.width.value, fill: "none" },
        arrow: { color: start, width: editor.arrow.width.value, heads: "one", line: "solid" },
        custom: ""
    }
}

function clamp(value, range) {
    return Math.max(range.min, Math.min(range.max, value))
}

// Saved values, one field at a time: a field that is not what it should be
// keeps the default, so a stale or edited file never breaks the editor.
function pickColor(saved, fallback) {
    return Color.isHex(saved) ? saved : fallback
}

function pickNumber(saved, fallback, range) {
    return typeof saved === "number" && isFinite(saved) ? clamp(saved, range) : fallback
}

function pickChoice(saved, fallback, choices) {
    return choices.indexOf(saved) >= 0 ? saved : fallback
}

function pickFlag(saved, fallback) {
    return typeof saved === "boolean" ? saved : fallback
}

// The options to start with: the defaults, overlaid with `saved` (the JSON
// text `serialize` wrote, or "").
function options(editor, saved) {
    var base = defaults(editor)
    var document = null
    try {
        document = JSON.parse(saved || "")
    } catch (error) {
        document = null
    }
    if (!document || typeof document !== "object" || Array.isArray(document))
        return base
    var pencil = document.pencil || ({})
    var text = document.text || ({})
    var shape = document.shape || ({})
    var arrow = document.arrow || ({})
    return {
        pencil: {
            color: pickColor(pencil.color, base.pencil.color),
            width: pickNumber(pencil.width, base.pencil.width, editor.pen.width),
            opacity: pickNumber(pencil.opacity, base.pencil.opacity, editor.pen.opacity),
            mode: pickChoice(pencil.mode, base.pencil.mode, ["normal", "highlighter"])
        },
        text: {
            color: pickColor(text.color, base.text.color),
            size: pickNumber(text.size, base.text.size, editor.text.size),
            bold: pickFlag(text.bold, base.text.bold),
            background: pickChoice(text.background, base.text.background, ["none", "solid"])
        },
        shape: {
            kind: pickChoice(shape.kind, base.shape.kind, ["rect", "ellipse"]),
            color: pickColor(shape.color, base.shape.color),
            width: pickNumber(shape.width, base.shape.width, editor.shape.width),
            fill: pickChoice(shape.fill, base.shape.fill, ["none", "solid", "translucent"])
        },
        arrow: {
            color: pickColor(arrow.color, base.arrow.color),
            width: pickNumber(arrow.width, base.arrow.width, editor.arrow.width),
            heads: pickChoice(arrow.heads, base.arrow.heads, ["one", "both"]),
            line: pickChoice(arrow.line, base.arrow.line, ["solid", "dashed"])
        },
        custom: pickColor(document.custom, base.custom)
    }
}

function serialize(current) {
    return JSON.stringify(current)
}

// --- colours ------------------------------------------------------------------

function luminance(hex) {
    var channels = [1, 3, 5].map(function (at) {
        var value = parseInt(hex.slice(at, at + 2), 16) / 255
        return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
    })
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}

// Of the two inks, the one that reads better on `hex`.
function contrastInk(hex, ink) {
    var own = luminance(hex)
    var against = function (other) {
        var light = Math.max(own, luminance(other))
        var dark = Math.min(own, luminance(other))
        return (light + 0.05) / (dark + 0.05)
    }
    return against(ink.dark) >= against(ink.light) ? ink.dark : ink.light
}

// --- elements -----------------------------------------------------------------

// An element is a plain object with everything it needs to be drawn, so the
// options can change afterwards without touching what is already there.

function penElement(editor, pen, points) {
    var wide = pen.mode === "highlighter"
    return {
        type: "pen",
        color: pen.color,
        width: wide ? pen.width * editor.pen.highlighter.width : pen.width,
        opacity: wide ? Math.min(pen.opacity, editor.pen.highlighter.opacity) : pen.opacity,
        round: !wide,
        points: points
    }
}

function shapeElement(editor, shape, from, to) {
    return {
        type: shape.kind === "ellipse" ? "ellipse" : "rect",
        x: Math.min(from.x, to.x),
        y: Math.min(from.y, to.y),
        w: Math.abs(to.x - from.x),
        h: Math.abs(to.y - from.y),
        color: shape.color,
        width: shape.width,
        fillAlpha: shape.fill === "solid" ? 1 : shape.fill === "translucent" ? editor.shape.fill : 0
    }
}

function arrowElement(editor, arrow, from, to) {
    return {
        type: "arrow",
        x1: from.x,
        y1: from.y,
        x2: to.x,
        y2: to.y,
        color: arrow.color,
        width: arrow.width,
        both: arrow.heads === "both",
        dashed: arrow.line === "dashed",
        headLength: Math.max(editor.arrow.headMin, arrow.width * editor.arrow.head),
        headAngle: editor.arrow.angle
    }
}

function textElement(editor, text, at, content) {
    return {
        type: "text",
        x: at.x,
        y: at.y,
        text: content,
        color: text.color,
        size: text.size,
        bold: text.bold,
        ground: text.background === "solid" ? contrastInk(text.color, editor.color.ink) : "",
        pad: Math.round(text.size * editor.text.pad)
    }
}

// A click, an empty label or a pen with no points draws nothing and is not
// worth an undo step.
function isEmpty(element, editor) {
    var least = editor.drag.least
    switch (element.type) {
    case "pen":
        return element.points.length === 0
    case "text":
        return String(element.text).trim() === ""
    case "arrow":
        return Math.hypot(element.x2 - element.x1, element.y2 - element.y1) < least
    default:
        return Math.max(element.w, element.h) < least
    }
}

function clampPoint(point, image) {
    return { x: Math.max(0, Math.min(image.w, point.x)), y: Math.max(0, Math.min(image.h, point.y)) }
}

// Adds a pen point unless it is closer than `least` to the last one.
function addPoint(points, point, least) {
    var last = points[points.length - 1]
    if (last && Math.hypot(point.x - last.x, point.y - last.y) < least)
        return points
    return points.concat([point])
}

function number(value) {
    return String(Number(value.toFixed(2)))
}

// The pen's SVG path: a dot, a line, or quadratic curves through the middle
// of each segment so a hand-drawn stroke has no corners.
function penPath(points) {
    if (points.length === 0)
        return ""
    var first = points[0]
    var out = "M " + number(first.x) + " " + number(first.y)
    if (points.length === 1)
        return out + " L " + number(first.x + 0.01) + " " + number(first.y)
    for (var index = 1; index < points.length - 1; index++) {
        var here = points[index]
        var next = points[index + 1]
        out += " Q " + number(here.x) + " " + number(here.y) + " " + number((here.x + next.x) / 2)
            + " " + number((here.y + next.y) / 2)
    }
    var last = points[points.length - 1]
    return out + " L " + number(last.x) + " " + number(last.y)
}

// The arrow as a line and its heads (triangles): the line stops at the base of
// each head, and a head never takes more than its half (or all, with one) of
// the arrow's length.
function arrowGeometry(arrow) {
    var dx = arrow.x2 - arrow.x1
    var dy = arrow.y2 - arrow.y1
    var length = Math.hypot(dx, dy)
    if (length === 0)
        return { line: null, heads: [] }
    var ux = dx / length
    var uy = dy / length
    var head = Math.min(arrow.headLength, arrow.both ? length / 2 : length)
    var half = head * Math.tan(arrow.headAngle * Math.PI / 180)
    var triangle = function (tipX, tipY, direction) {
        var baseX = tipX - direction * ux * head
        var baseY = tipY - direction * uy * head
        return {
            tip: { x: tipX, y: tipY },
            a: { x: baseX - uy * half, y: baseY + ux * half },
            b: { x: baseX + uy * half, y: baseY - ux * half }
        }
    }
    var heads = [triangle(arrow.x2, arrow.y2, 1)]
    if (arrow.both)
        heads.push(triangle(arrow.x1, arrow.y1, -1))
    return {
        line: {
            x1: arrow.x1 + (arrow.both ? ux * head : 0),
            y1: arrow.y1 + (arrow.both ? uy * head : 0),
            x2: arrow.x2 - ux * head,
            y2: arrow.y2 - uy * head
        },
        heads: heads
    }
}

function headPath(head) {
    return "M " + number(head.tip.x) + " " + number(head.tip.y)
        + " L " + number(head.a.x) + " " + number(head.a.y)
        + " L " + number(head.b.x) + " " + number(head.b.y) + " Z"
}

// The dash pattern, in line widths, for a Shape's `dashPattern`.
function dash(editor, dashed) {
    return dashed ? editor.arrow.dash.slice() : []
}

// --- history ------------------------------------------------------------------

// `done` is what is drawn, `undone` what Redo brings back. Every function
// returns a new state; none changes the one it is given.

function history() {
    return { done: [], undone: [] }
}

function commit(state, element) {
    return { done: state.done.concat([element]), undone: [] }
}

function canUndo(state) {
    return state.done.length > 0
}

function canRedo(state) {
    return state.undone.length > 0
}

function undo(state) {
    if (!canUndo(state))
        return state
    return {
        done: state.done.slice(0, -1),
        undone: state.undone.concat([state.done[state.done.length - 1]])
    }
}

function redo(state) {
    if (!canRedo(state))
        return state
    return {
        done: state.done.concat([state.undone[state.undone.length - 1]]),
        undone: state.undone.slice(0, -1)
    }
}

// The message that says how much a discard loses.
function discardKey(count) {
    return count === 1 ? "capture.editor.discard.one" : "capture.editor.discard.many"
}

// --- the view -----------------------------------------------------------------

// The scale (view px per picture px) that fits the picture in the view without
// cutting it, and never past the picture's own pixels: `ratio` is the
// monitor's pixels per view px, so a 2x monitor shows a picture one to one at
// 0.5. A view with no room still gets a scale, so nothing divides by zero.
function fitScale(view, image, ratio) {
    var own = 1 / Math.max(ratio, 0.01)
    if (image.w <= 0 || image.h <= 0)
        return own
    return Math.max(0.01, Math.min(own, view.w / image.w, view.h / image.h))
}

// One zoom press (direction 1 or -1) on a multiplier of the fit. Crossing the
// fit stops on it, so the way back is always one press.
function zoomLevel(level, direction, zoom) {
    var next = Math.max(zoom.min, Math.min(zoom.max, level * Math.pow(zoom.step, direction)))
    return (level - 1) * (next - 1) < 0 ? 1 : next
}

// The label: the picture's pixels shown per monitor pixel, as a percent.
function percent(scale, ratio) {
    return Math.round(scale * ratio * 100)
}

// The window that holds a picture shown one to one, between the least the
// layout needs and the share of the screen it may take; `chrome` is what the
// card spends around the canvas.
function windowSize(image, ratio, screen, chrome, limits) {
    var wanted = { w: Math.ceil(image.w / ratio) + chrome.w, h: Math.ceil(image.h / ratio) + chrome.h }
    var most = { w: Math.floor(screen.w * limits.share), h: Math.floor(screen.h * limits.share) }
    return {
        w: Math.min(most.w, Math.max(limits.width, wanted.w)),
        h: Math.min(most.h, Math.max(limits.height, wanted.h))
    }
}

// A point of the view in the picture's pixels.
function toImage(point, scale) {
    return { x: point.x / scale, y: point.y / scale }
}

// --- keys ---------------------------------------------------------------------

// What a key does in the editor, as the name of an action ("" for none):
// "tool:<name>", save, copy, undo, redo, discard, zoomIn, zoomOut, zoomFit.
// While a label is being typed the text keeps its own keys (copy, undo, the
// letters, Escape); only Ctrl+S still means save.
function shortcut(key, modifiers, typing) {
    var control = (modifiers & Qt.ControlModifier) !== 0
    var shift = (modifiers & Qt.ShiftModifier) !== 0
    if (modifiers & (Qt.AltModifier | Qt.MetaModifier))
        return ""
    if (control) {
        if (key === Qt.Key_S)
            return "save"
        if (typing)
            return ""
        switch (key) {
        case Qt.Key_C: return "copy"
        case Qt.Key_Z: return shift ? "redo" : "undo"
        case Qt.Key_Y: return "redo"
        case Qt.Key_Plus:
        case Qt.Key_Equal: return "zoomIn"
        case Qt.Key_Minus: return "zoomOut"
        case Qt.Key_0: return "zoomFit"
        default: return ""
        }
    }
    if (typing)
        return ""
    if (key === Qt.Key_Escape)
        return "discard"
    for (var index = 0; index < tools.length; index++) {
        if (key === Qt["Key_" + tools[index].letter])
            return "tool:" + tools[index].key
    }
    return ""
}
