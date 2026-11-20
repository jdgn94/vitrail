pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../kit"
import QtQuick.Shapes
import QtQuick.Effects
import "../kit/base"
import "../kit/frame.js" as Frame
import "capture.js" as Capture

// The capture overlay: the frozen screen, an editable selection and the action
// bar, one layer surface per monitor.
//
// The shell freezes the screen (`python3 -m vitrail.capture freeze`), hands the
// result in `capture` and loads this item. Nothing is captured from the live
// screen: the selection is composed from the frozen images afterwards, so what
// the overlay shows is exactly what gets saved.
//
// The surface of the monitor under the pointer at open takes the keyboard and
// hosts the toolbar; every surface takes the mouse, so a selection may be
// dragged across monitors. `confirmed` carries the rectangle in layout
// coordinates and what to do with it.
Item {
    id: root

    // { monitors: [{ name, x, y, width, height, scale, image }], bounds, pointer }
    property var capture: ({})
    // "region" | "window" | "full" | "record": what the overlay opens for.
    property string mode: "region"
    // The clients the window mode picks from (focus order), from the shell.
    property var windows: []
    // The drawn area glides like the launch drop (preference captureAnimation);
    // off, it is the exact selection at once.
    property bool animation: true
    // The "Ask AI" action (preference captureAi) and the text recognition
    // languages shown in its tooltip.
    property bool ai: true
    property string languages: ""
    // Background detection of text and codes in the selection (preference
    // captureDetect); off, every action is offered.
    property bool detect: true

    property var t: function (key) {
        return key
    }

    // `text` is the question of the "ask" action, "" for the others.
    signal confirmed(var selection, string action, int timer, string text)
    signal cancelled()
    signal windowModeRequested()
    // The shell runs these in the background and answers with
    // `detected(token, result)` and `setCard(kind, result)`.
    signal detectRequested(var selection, int token)
    signal inspect(string kind, var selection)
    signal copyRequested(string text)
    signal openRequested(string url)
    signal colorPicked(string hex)

    readonly property var monitors: root.capture.monitors || []
    readonly property var bounds: root.capture.bounds || ({ x: 0, y: 0, w: 0, h: 0 })
    readonly property var host: {
        var list = root.monitors
        if (list.length === 0)
            return null
        var point = root.capture.pointer || ({ x: list[0].x + 1, y: list[0].y + 1 })
        for (var index = 0; index < list.length; index++) {
            var one = list[index]
            if (point.x >= one.x && point.x < one.x + one.width && point.y >= one.y && point.y < one.y + one.height)
                return one
        }
        return list[0]
    }

    // Everything below is layout coordinates; each surface translates.
    property var selection: null
    property var pointer: ({ x: 0, y: 0 })
    property var anchor: null
    property var last: null
    property string gesture: ""
    property string handle: ""
    property bool windowMode: false
    // A click in the window mode takes that window (no drag, no second step).
    property bool windowPicked: false
    property int timer: 0
    property var hoveredWindow: null
    // The last change of `selection` was a jump (a window, the whole screen)
    // rather than a drag or a key nudge: the drawn area glides to it with the
    // launch drop's neck.
    property bool glide: false
    // The question card is up instead of the toolbar (the "ask" action).
    property bool asking: false
    // What the selection holds, found in the background once it settled:
    // `token` counts the settled selections so a late answer for an older one
    // is ignored.
    property var found: ({ text: false, codes: 0 })
    property bool detecting: false
    property int token: 0
    // The result card (translation, QR code) or null: { kind, phase, text,
    // url, message, note }.
    property var card: null
    // The colour picker's sub-mode: a loupe follows the pointer over the frozen
    // screen and a click takes the pixel under it.
    property bool picking: false

    onSelectionChanged: root.settle()

    Timer {
        id: settling

        interval: VitrailTokens.capture.detect
        onTriggered: {
            if (root.selection && root.detect)
                root.detectRequested(root.selection, root.token)
        }
    }

    // The selection changed: forget what was found, close what was shown for
    // the old one, and look again once it rests.
    function settle() {
        root.token++
        root.found = ({ text: false, codes: 0 })
        root.card = null
        root.detecting = root.detect && root.selection !== null
        if (root.detecting)
            settling.restart()
        else
            settling.stop()
    }

    function detected(token, result) {
        if (!Capture.fresh(token, root.token))
            return
        root.detecting = false
        root.found = ({ text: !!(result && result.text), codes: result && result.codes ? result.codes : 0 })
    }

    readonly property bool textReady: !root.detect || root.found.text
    readonly property bool codeReady: !root.detect || root.found.codes > 0

    // Translate and QR answer on a card; the shell fills it in.
    function startInspect(kind) {
        if (!root.selection)
            root.selectAll()
        if (kind === "qr" ? !root.codeReady : !root.textReady)
            return
        root.card = ({ kind: kind, phase: "loading", text: "", url: "",
                       note: root.t(kind === "qr" ? "capture.qr" : "capture.translate"),
                       message: root.t(kind === "qr" ? "capture.qr.loading" : "capture.translate.loading") })
        root.inspect(kind, root.selection)
    }

    function setCard(kind, card) {
        if (root.card && root.card.kind === kind)
            root.card = card
    }

    function closeCard() {
        root.card = null
    }

    function beginPick() {
        root.picking = true
        root.card = null
        root.asking = false
    }

    function finishPick(hex) {
        if (hex === "")
            return
        root.picking = false
        root.colorPicked(hex)
    }

    function monitorNamed(name) {
        for (var index = 0; index < root.monitors.length; index++) {
            if (root.monitors[index].name === name)
                return root.monitors[index]
        }
        return null
    }

    function selectAll() {
        root.glide = true
        root.selection = ({ x: root.bounds.x, y: root.bounds.y, w: root.bounds.w, h: root.bounds.h })
        root.handle = ""
    }

    function windowUnder(point) {
        for (var index = 0; index < root.windows.length; index++) {
            var one = root.windows[index]
            if (point.x >= one.x && point.x < one.x + one.w && point.y >= one.y && point.y < one.y + one.h)
                return ({ x: one.x, y: one.y, w: one.w, h: one.h })
        }
        return null
    }

    function toggleWindowMode() {
        root.windowMode = !root.windowMode
        root.hoveredWindow = null
        if (root.windowMode)
            root.windowModeRequested()
    }

    function cycleTimer() {
        root.timer = root.timer === 0 ? 3 : root.timer === 3 ? 5 : 0
    }

    function activate(action, text) {
        if (!root.selection)
            root.selectAll()
        root.confirmed(root.selection, action, root.timer, text || "")
    }

    // "Ask AI" first asks the question; nothing is captured or sent until it
    // is submitted.
    function beginAsk() {
        if (!root.ai)
            return
        if (!root.selection)
            root.selectAll()
        root.asking = true
    }

    function endAsk() {
        root.asking = false
    }

    function press(point, monitor) {
        root.asking = false
        root.card = null
        root.pointer = point
        root.last = point
        root.anchor = point
        root.glide = false
        if (root.windowMode) {
            var picked = root.windowUnder(point)
            root.windowPicked = picked !== null
            if (picked) {
                root.glide = true
                root.selection = picked
            }
            root.windowMode = false
            root.hoveredWindow = null
            root.gesture = ""
            return
        }
        var local = Capture.toLocalRect(root.selection, monitor)
        var hit = local ? Capture.handleAt(Capture.toLocal(point, monitor), local, VitrailTokens.capture.handle) : ""
        root.handle = hit === "" || hit === "inside" ? "" : hit
        if (hit === "" || hit === "inside") {
            root.gesture = hit === "inside" ? "inside" : "new"
            if (root.gesture === "new")
                root.selection = null
        } else {
            root.gesture = hit
        }
    }

    function drag(point) {
        if (!root.last) {
            root.pointer = point
            return
        }
        var dx = point.x - root.last.x
        var dy = point.y - root.last.y
        root.glide = false
        root.pointer = point
        if (root.gesture === "new") {
            root.selection = Capture.move(Capture.normalize(root.anchor, point), 0, 0, root.bounds)
        } else if (root.gesture === "inside") {
            root.selection = Capture.move(root.selection, dx, dy, root.bounds)
        } else if (root.gesture !== "") {
            root.selection = Capture.resize(root.selection, root.gesture, dx, dy, root.bounds, 1)
        }
        root.last = point
    }

    function release(point) {
        if (root.windowPicked) {
            root.windowPicked = false
            root.gesture = ""
            root.last = null
            root.activate(root.mode === "record" ? "record" : "copy")
            return
        }
        root.drag(point)
        if (root.gesture === "new" && root.selection && (root.selection.w < 2 || root.selection.h < 2))
            root.selection = null
        root.gesture = ""
        root.last = null
    }

    function nudge(event) {
        var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
        var dx = event.key === Qt.Key_Left ? -step : event.key === Qt.Key_Right ? step : 0
        var dy = event.key === Qt.Key_Up ? -step : event.key === Qt.Key_Down ? step : 0
        if (!root.selection) {
            root.selectAll()
            return
        }
        root.glide = false
        root.selection = root.handle === ""
            ? Capture.move(root.selection, dx, dy, root.bounds)
            : Capture.resize(root.selection, root.handle, dx, dy, root.bounds, 1)
    }

    function cycleHandle(backwards) {
        var names = ["", ...Capture.HANDLES]
        var index = names.indexOf(root.handle)
        index = (index + (backwards ? -1 : 1) + names.length) % names.length
        root.handle = names[index]
    }

    function key(event) {
        // The question field owns the keyboard; it reports Enter and Escape.
        if (root.asking)
            return
        if (event.key === Qt.Key_Escape) {
            if (root.picking)
                root.picking = false
            else if (root.card)
                root.closeCard()
            else
                root.cancelled()
            return
        }
        if (root.picking)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(root.mode === "record" ? "record" : "copy")
            return
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.nudge(event)
            return
        }
        switch (event.key) {
        case Qt.Key_G: root.activate("save"); break
        case Qt.Key_A: root.activate("annotate"); break
        case Qt.Key_P: root.activate("pin"); break
        case Qt.Key_O:
            if (!root.selection || root.textReady)
                root.activate("ocr")
            break
        case Qt.Key_L: root.startInspect("translate"); break
        case Qt.Key_Q: root.startInspect("qr"); break
        case Qt.Key_C: root.beginPick(); break
        case Qt.Key_I: root.beginAsk(); break
        case Qt.Key_R: root.activate("record"); break
        case Qt.Key_T: root.cycleTimer(); break
        case Qt.Key_W: root.toggleWindowMode(); break
        case Qt.Key_F: root.selectAll(); break
        case Qt.Key_Tab: root.cycleHandle(event.modifiers & Qt.ShiftModifier); break
        default: break
        }
    }

    Component.onCompleted: {
        if (root.capture.pointer)
            root.pointer = root.capture.pointer
        if (root.mode === "full")
            root.selectAll()
        if (root.mode === "window")
            root.toggleWindowMode()
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: surface

                required property var modelData

                readonly property var record: root.monitorNamed(surface.modelData.name)
                readonly property bool host: root.host !== null && surface.record !== null
                    && surface.record.name === root.host.name
                readonly property var local: root.selection && surface.record
                    ? Capture.toLocalRect(root.selection, surface.record) : null
                readonly property var localPointer: surface.record
                    ? Capture.toLocal(root.pointer, surface.record) : ({ x: 0, y: 0 })
                readonly property real grip: VitrailTokens.capture.handle
                // The drawn area: its four edges are springs toward `local`, the
                // exact rect, so the selection itself (hit-testing, the capture)
                // never lags.
                property bool alive: false
                // Where the drop that bonds to the area was born (surface coords).
                property var source: ({ x: 0, y: 0 })
                readonly property bool liquid: root.animation && VitrailTokens.glass
                readonly property var shown: ({
                    x: mass.el, y: mass.et,
                    w: Math.max(0, mass.er - mass.el), h: Math.max(0, mass.eb - mass.et)
                })
                readonly property var tension: ({
                    rest: VitrailTokens.capture.liquid.rest,
                    swell: surface.liquid ? VitrailTokens.capture.liquid.swell : 0,
                    max: VitrailTokens.capture.liquid.max,
                    bow: surface.liquid ? VitrailTokens.capture.liquid.bow : 0,
                    bowMax: VitrailTokens.capture.liquid.bowMax
                })
                readonly property real radius: root.animation
                    ? Capture.softRadius(surface.local, surface.shown, surface.tension) : 0
                readonly property var bows: Capture.edgeBows(surface.local, surface.shown, surface.tension)
                // The neck and the birth drop of a jump or a new area, from frame.js.
                readonly property var goo: Frame.goo(
                    Capture.boxOf(Capture.dropAt(surface.source, VitrailTokens.capture.liquid.drop)),
                    Capture.boxOf(surface.shown),
                    surface.liquid ? liquidTimeline.look.bond : 0,
                    surface.radius, 1)
                readonly property string edge: Capture.outline(surface.shown, surface.bows, surface.radius)
                readonly property string hole: surface.edge
                    + (surface.goo.neck ? " " + surface.goo.originPath + " " + surface.goo.neck.path : "")
                readonly property var grips: {
                    if (!surface.alive)
                        return []
                    return Capture.grips(surface.shown, surface.bows, surface.radius)
                }
                readonly property var seat: {
                    var size = root.asking ? ({ w: question.width, h: question.height })
                             : root.card ? ({ w: answer.width, h: answer.height })
                             : ({ w: toolbar.width, h: toolbar.height })
                    var screen = ({ x: 0, y: 0, w: surface.width, h: surface.height })
                    if (!surface.alive) {
                        return {
                            x: Math.round((surface.width - size.w) / 2),
                            y: surface.height - size.h - VitrailTokens.gap("lg")
                        }
                    }
                    return Capture.toolbarPlacement(surface.shown, screen, size)
                }

                // The drawn area follows the exact one. Born, it is a drop at
                // the pointer that stretches into the rect; moved by a jump, it
                // also gets the launch drop's neck. Edges overshoot and wobble
                // to rest while the sides bow; a solid surface is critically
                // damped (smooth, no bow).
                function reach() {
                    var r = surface.local
                    if (!r)
                        return
                    mass.aim(r)
                }

                function follow() {
                    var r = surface.local
                    if (!r) {
                        surface.alive = false
                        return
                    }
                    var jump = root.glide && surface.alive
                    if (surface.alive && !jump) {
                        surface.reach()
                        return
                    }
                    var fromPointer = root.gesture === "new" && root.anchor ? root.anchor : root.pointer
                    var point = surface.record ? Capture.toLocal(fromPointer, surface.record) : fromPointer
                    if (jump)
                        point = Capture.centreOf(surface.shown)
                    surface.source = point
                    if (surface.liquid)
                        liquidTimeline.replay()
                    if (!surface.alive && !surface.liquid) {
                        mass.place(r)
                        surface.alive = true
                        return
                    }
                    if (!surface.alive) {
                        var seed = Capture.dropAt(point, VitrailTokens.capture.liquid.drop)
                        mass.place(seed)
                        surface.alive = true
                    }
                    surface.reach()
                }

                onLocalChanged: surface.follow()
                Component.onCompleted: surface.follow()

                visible: surface.record !== null
                screen: surface.modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "vitrail-capture"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: surface.host ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                // The whole surface takes the pointer: a selection may start
                // anywhere, and a window without a mask is click-through.
                mask: Region { item: gestures }

                // The frozen screen: a physical-pixel PNG stretched over the
                // monitor's logical size.
                Image {
                    id: frozen

                    anchors.fill: parent
                    source: surface.record ? "file://" + surface.record.image : ""
                    fillMode: Image.Stretch
                    asynchronous: false
                    cache: false
                    smooth: false
                }

                Item {
                    id: gestures

                    anchors.fill: parent
                    focus: surface.host
                    Keys.onPressed: function (event) {
                        root.key(event)
                        event.accepted = true
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: surface.record ? root.cursorFor(surface.record, root.pointer) : Qt.CrossCursor

                        onPressed: function (mouse) {
                            gestures.forceActiveFocus()
                            if (root.picking) {
                                root.pointer = Capture.toLayout(({ x: mouse.x, y: mouse.y }), surface.record)
                                root.finishPick(sampler.hex)
                                return
                            }
                            root.press(Capture.toLayout(({ x: mouse.x, y: mouse.y }), surface.record), surface.record)
                        }

                        onPositionChanged: function (mouse) {
                            var point = Capture.toLayout(({ x: mouse.x, y: mouse.y }), surface.record)
                            if (area.pressed)
                                root.drag(point)
                            else if (root.windowMode)
                                root.hoveredWindow = root.windowUnder(point)
                            else
                                root.pointer = point
                        }

                        onReleased: function (mouse) {
                            if (root.picking)
                                return
                            root.release(Capture.toLayout(({ x: mouse.x, y: mouse.y }), surface.record))
                        }
                    }
                }

                // The popup's liquid timeline, replayed at every birth and jump.
                VitrailLiquid {
                    id: liquidTimeline

                    openMs: VitrailTokens.capture.liquid.glide

                    function replay() {
                        liquidTimeline.animated = false
                        liquidTimeline.open = false
                        liquidTimeline.animated = true
                        liquidTimeline.open = true
                    }
                }

                // The four edges of the drawn area, each its own spring,
                // integrated by hand (Capture.springStep) one step per frame
                // while any of them moves. A Behavior would restart at every
                // pointer event and, with a real mouse, never advance; here a
                // new target only changes where the spring pulls and keeps its
                // velocity.
                Item {
                    id: mass

                    property real el: 0
                    property real et: 0
                    property real er: 0
                    property real eb: 0
                    property var speed: [0, 0, 0, 0]
                    property var goal: [0, 0, 0, 0]
                    readonly property var feel: ({
                        spring: VitrailTokens.capture.liquid.spring,
                        damping: surface.liquid ? VitrailTokens.capture.liquid.damping : 1,
                        mass: VitrailTokens.capture.liquid.mass,
                        epsilon: VitrailTokens.capture.liquid.epsilon
                    })

                    visible: false

                    // At once: the edges sit on `r`, still.
                    function place(r) {
                        mass.goal = [r.x, r.y, r.x + r.w, r.y + r.h]
                        mass.speed = [0, 0, 0, 0]
                        mass.el = r.x
                        mass.et = r.y
                        mass.er = r.x + r.w
                        mass.eb = r.y + r.h
                        pulse.running = false
                    }

                    // The edges move to `r` (at once without animation).
                    function aim(r) {
                        if (!root.animation) {
                            mass.place(r)
                            return
                        }
                        mass.goal = [r.x, r.y, r.x + r.w, r.y + r.h]
                        pulse.running = true
                    }

                    function advance(dt) {
                        var now = [mass.el, mass.et, mass.er, mass.eb]
                        var next = []
                        var speed = []
                        var rest = true
                        for (var i = 0; i < 4; ++i) {
                            var step = Capture.springStep({ x: now[i], v: mass.speed[i] }, mass.goal[i], dt, mass.feel)
                            next.push(step.x)
                            speed.push(step.v)
                            rest = rest && step.rest
                        }
                        mass.speed = speed
                        mass.el = next[0]
                        mass.et = next[1]
                        mass.er = next[2]
                        mass.eb = next[3]
                        if (rest)
                            pulse.running = false
                    }

                    FrameAnimation {
                        id: pulse

                        onTriggered: mass.advance(pulse.frameTime)
                    }
                }

                // The rest of the screen, darker: one veil with the liquid
                // shape cut out of it. The neck and the birth drop overlap the
                // area, so the cut is a mask (an even-odd fill would put the
                // veil back where they overlap).
                Rectangle {
                    id: veilFill

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    color: root.veil
                }

                Item {
                    id: holeMask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "black"
                            strokeColor: "transparent"
                            fillRule: ShapePath.WindingFill

                            PathSvg { path: surface.hole }
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    visible: surface.alive
                    source: veilFill
                    maskEnabled: true
                    maskInverted: true
                    maskSource: holeMask
                }

                // The guides that follow the pointer.
                Rectangle {
                    visible: surface.local === null
                    x: Math.round(surface.localPointer.x)
                    y: 0
                    width: VitrailTokens.capture.guide.width
                    height: parent.height
                    color: root.guide
                }

                Rectangle {
                    visible: surface.local === null
                    x: 0
                    y: Math.round(surface.localPointer.y)
                    width: parent.width
                    height: VitrailTokens.capture.guide.width
                    color: root.guide
                }

                // The selection's border: the stroke of the area's own outline.
                Shape {
                    anchors.fill: parent
                    visible: surface.alive
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.accent
                        strokeWidth: VitrailTokens.capture.border

                        PathSvg { path: surface.edge }
                    }
                }

                // The window mode's candidate.
                Rectangle {
                    visible: root.windowMode && root.hoveredWindow !== null && surface.record !== null
                    x: root.hoveredWindow ? root.hoveredWindow.x - surface.record.x : 0
                    y: root.hoveredWindow ? root.hoveredWindow.y - surface.record.y : 0
                    width: root.hoveredWindow ? root.hoveredWindow.w : 0
                    height: root.hoveredWindow ? root.hoveredWindow.h : 0
                    color: "transparent"
                    border.width: VitrailTokens.capture.window
                    border.color: root.accent
                }

                Repeater {
                    model: surface.grips

                    delegate: Rectangle {
                        required property var modelData

                        readonly property real at: surface.grip / 2
                        readonly property bool onSurface: modelData[1] >= -at && modelData[1] <= surface.width + at
                            && modelData[2] >= -at && modelData[2] <= surface.height + at

                        visible: surface.alive && onSurface
                        x: modelData[1] - at
                        y: modelData[2] - at
                        width: surface.grip
                        height: surface.grip
                        radius: VitrailTokens.gap("xs")
                        color: root.accent
                    }
                }

                // The size of the area, next to the pointer.
                Item {
                    visible: surface.alive
                    width: sizeLabel.width
                    height: sizeLabel.height
                    x: Math.min(Math.max(surface.localPointer.x + VitrailTokens.gap("md"), VitrailTokens.gap("sm")),
                                Math.max(VitrailTokens.gap("sm"), surface.width - sizeLabel.width - VitrailTokens.gap("sm")))
                    y: Math.min(Math.max(surface.localPointer.y + VitrailTokens.gap("md"), VitrailTokens.gap("sm")),
                                Math.max(VitrailTokens.gap("sm"), surface.height - sizeLabel.height - VitrailTokens.gap("sm")))

                    VitrailSurface {
                        id: sizeLabel

                        width: sizeText.implicitWidth + 2 * VitrailTokens.gap("sm")
                        height: sizeText.implicitHeight + 2 * VitrailTokens.gap("xs")
                        radius: VitrailTokens.gap("sm")

                        VitrailText {
                            id: sizeText

                            anchors.centerIn: parent
                            variant: "label"
                            text: root.selection ? Capture.label(root.selection) : ""
                        }
                    }
                }

                // The colour under the pointer, read from the frozen image: a
                // 1 px canvas that draws that pixel and reads it back.
                Canvas {
                    id: sampler

                    property string hex: ""
                    readonly property string source: surface.record ? "file://" + surface.record.image : ""
                    readonly property var pixel: surface.record ? Capture.pixelAt(root.pointer, surface.record)
                                                                : ({ x: 0, y: 0 })

                    width: 1
                    height: 1
                    visible: false
                    onSourceChanged: if (source !== "") loadImage(source)
                    onImageLoaded: requestPaint()
                    onPixelChanged: if (root.picking && isImageLoaded(source)) requestPaint()
                    onPaint: {
                        if (source === "" || !isImageLoaded(source))
                            return
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, 1, 1)
                        ctx.drawImage(source, pixel.x, pixel.y, 1, 1, 0, 0, 1, 1)
                        var data = ctx.getImageData(0, 0, 1, 1).data
                        sampler.hex = "#" + [data[0], data[1], data[2]].map(function (value) {
                            return ("0" + value.toString(16)).slice(-2)
                        }).join("")
                    }
                }

                // The loupe: the pixels around the pointer, enlarged, with the
                // colour's code under it.
                Item {
                    id: loupe

                    readonly property real zoom: VitrailTokens.capture.loupe.zoom
                    readonly property var clip: surface.record
                        ? Capture.loupeClip(sampler.pixel, VitrailTokens.capture.loupe.radius,
                                            ({ w: surface.record.width, h: surface.record.height }))
                        : ({ x: 0, y: 0, w: 1, h: 1 })
                    readonly property real side: clip.w * zoom
                    readonly property var seat: Capture.loupePlace(surface.localPointer,
                        ({ w: side, h: side + tag.height + VitrailTokens.gap("xs") }),
                        ({ x: 0, y: 0, w: surface.width, h: surface.height }), VitrailTokens.capture.loupe.gap)

                    visible: root.picking && surface.record !== null
                        && root.pointer.x >= surface.record.x && root.pointer.x < surface.record.x + surface.record.width
                        && root.pointer.y >= surface.record.y && root.pointer.y < surface.record.y + surface.record.height
                    x: seat.x
                    y: seat.y
                    width: side
                    height: side + tag.height + VitrailTokens.gap("xs")

                    VitrailSurface {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: loupe.side
                        height: loupe.side
                        radius: VitrailTokens.radius

                        // The frozen image already in memory, cropped: a
                        // clipped second Image would decode the whole PNG
                        // again at every pointer move.
                        ShaderEffectSource {
                            readonly property real ratio: surface.record && surface.width > 0
                                ? surface.record.width / surface.width : 1

                            anchors.fill: parent
                            anchors.margins: VitrailTokens.gap("xs")
                            sourceItem: frozen
                            sourceRect: Qt.rect(loupe.clip.x / ratio, loupe.clip.y / ratio,
                                                loupe.clip.w / ratio, loupe.clip.h / ratio)
                            smooth: false
                            hideSource: false
                        }

                        // The pixel that will be taken: one enlarged cell.
                        Rectangle {
                            anchors.centerIn: parent
                            width: loupe.zoom
                            height: loupe.zoom
                            color: "transparent"
                            border.width: VitrailTokens.capture.border
                            border.color: root.ink
                        }
                    }

                    VitrailSurface {
                        id: tag

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: tagText.implicitWidth + 2 * VitrailTokens.gap("sm")
                        height: tagText.implicitHeight + 2 * VitrailTokens.gap("xs")
                        radius: VitrailTokens.gap("sm")

                        VitrailText {
                            id: tagText

                            anchors.centerIn: parent
                            variant: "label"
                            text: sampler.hex
                        }
                    }
                }

                // The actions, once there is something to act on.
                CaptureToolbar {
                    id: toolbar

                    visible: surface.host && surface.alive && !root.asking && !root.card && !root.picking
                    x: surface.seat.x
                    y: surface.seat.y
                    t: root.t
                    mode: root.mode === "record" ? "record" : "shot"
                    timer: root.timer
                    ai: root.ai
                    languages: root.languages
                    detect: root.detect
                    detecting: root.detecting
                    hasText: root.found.text
                    hasCode: root.found.codes > 0
                    onShot: root.activate("copy")
                    onSave: root.activate("save")
                    onAnnotate: root.activate("annotate")
                    onPin: root.activate("pin")
                    onOcr: root.activate("ocr")
                    onTranslate: root.startInspect("translate")
                    onQr: root.startInspect("qr")
                    onPickColor: root.beginPick()
                    onAsk: root.beginAsk()
                    onRecord: root.activate("record")
                    onTimerCycled: root.cycleTimer()
                    onWindowMode: root.toggleWindowMode()
                    onFullScreen: root.selectAll()
                    onClosed: root.cancelled()
                }

                // The question of "Ask AI", where the toolbar was.
                CaptureAsk {
                    id: question

                    visible: surface.host && surface.alive && root.asking
                    x: surface.seat.x
                    y: surface.seat.y
                    t: root.t
                    onSubmitted: function (text) { root.activate("ask", text) }
                    onBack: {
                        root.endAsk()
                        gestures.forceActiveFocus()
                    }
                    Connections {
                        target: root

                        function onAskingChanged() {
                            if (root.asking && surface.host)
                                question.open()
                        }
                    }
                }

                // The answer of Translate and QR, where the toolbar was.
                CaptureCard {
                    id: answer

                    visible: surface.host && surface.alive && root.card !== null
                    x: surface.seat.x
                    y: surface.seat.y
                    t: root.t
                    kind: root.card ? root.card.kind : "translate"
                    phase: root.card ? root.card.phase : "loading"
                    text: root.card ? root.card.text : ""
                    url: root.card ? root.card.url : ""
                    message: root.card ? root.card.message : ""
                    note: root.card ? root.card.note : ""
                    onCopyRequested: function (text) { root.copyRequested(text) }
                    onOpenRequested: function (url) { root.openRequested(url) }
                    onClosed: root.closeCard()
                }

            }
        }
    }

    // The veil over everything outside the selection, the guide lines and the
    // accent every edge is drawn with.
    readonly property color surfaceTint: VitrailTokens.color("surface", "#1d2024")
    readonly property color ink: VitrailTokens.color("foreground", "#e2e2e9")
    readonly property color accent: VitrailTokens.color("primary", "#a8c7fa")
    readonly property color veil: Qt.rgba(root.surfaceTint.r, root.surfaceTint.g, root.surfaceTint.b,
                                          VitrailTokens.capture.dim)
    readonly property color guide: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, VitrailTokens.capture.guide.alpha)

    // The cursor over a surface: what the pointer would do there.
    function cursorFor(monitor, point) {
        if (root.windowMode)
            return Qt.PointingHandCursor
        var local = Capture.toLocalRect(root.selection, monitor)
        if (!local)
            return Qt.CrossCursor
        var hit = Capture.handleAt(Capture.toLocal(point, monitor), local, VitrailTokens.capture.handle)
        if (hit === "inside")
            return Qt.SizeAllCursor
        if (hit === "n" || hit === "s")
            return Qt.SizeVerCursor
        if (hit === "e" || hit === "w")
            return Qt.SizeHorCursor
        if (hit === "nw" || hit === "se")
            return Qt.SizeFDiagCursor
        if (hit === "ne" || hit === "sw")
            return Qt.SizeBDiagCursor
        return Qt.CrossCursor
    }
}
