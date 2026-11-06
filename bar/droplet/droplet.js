// The launch droplet: the state machine behind the splash that grows from an
// icon into the space a launching window will take.
//
// Pure, no QML types: the shell owns the request, this file decides when it
// starts, what space it holds, when the new window replaces that space and
// when it gives up. Geometry is screen-local; `local()` converts Hyprland's
// global window rect for the monitor that asked.
.pragma library

var TIMEOUT = 4000
// How long a newly mapped window may keep moving before the drop takes its
// rect anyway. Two equal reads settle it sooner.
var SETTLE = 250

function text(value) {
    return String(value === undefined || value === null ? "" : value)
}

// The key an app answers to, matching the dock's rule: lowercased, without
// the .desktop suffix and punctuation.
function keyOf(value) {
    return text(value).trim().toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
}

function number(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
}

function rect(value) {
    var source = value || ({})
    return {
        x: number(source.x, 0),
        y: number(source.y, 0),
        width: Math.max(0, number(source.width, 0)),
        height: Math.max(0, number(source.height, 0))
    }
}

// The last rect a window of this app/class had, or null. A dock/launcher launch
// reserves that real space instead of inventing a centred block.
function lastRect(app, rects) {
    var wanted = text(app && (app.id || app.desktop || app.name))
    var map = rects || ({})
    for (var address in map) {
        var window = map[address]
        if (window && matchesClass(window.class, wanted))
            return rect(window.rect)
    }
    return null
}

// An app that already has a window only takes the focus: no drop.
function isOpen(app) {
    return !!(app && app.open === true && text(app.address) !== "")
}

// A fresh request. `screen` is the monitor that owns it; origin and target are
// local to that monitor.
function request(app, origin, target, now, timeout, screen) {
    if (isOpen(app))
        return null
    var at = number(now, 0)
    var wait = number(timeout, TIMEOUT)
    return {
        id: text(app && (app.id || app.desktop || app.name)),
        app: app || ({}),
        origin: rect(origin),
        target: rect(target),
        phase: "hold",
        started: at,
        deadline: at + (wait > 0 ? wait : TIMEOUT),
        screen: text(screen)
    }
}

function addresses(toplevels) {
    var out = []
    var list = toplevels || []
    for (var i = 0; i < list.length; i++) {
        var address = text(list[i] && list[i].address)
        if (address !== "")
            out.push(address)
    }
    return out
}

function onScreen(box, screen) {
    if (!screen)
        return true
    var cx = box.x + box.width / 2
    var cy = box.y + box.height / 2
    return cx >= screen.x && cx <= screen.x + screen.width
           && cy >= screen.y && cy <= screen.y + screen.height
}

// Hyprland speaks in global coordinates; a layer is local to its monitor.
function local(box, screen) {
    var source = rect(box)
    var originX = screen ? number(screen.x, 0) : 0
    var originY = screen ? number(screen.y, 0) : 0
    return { x: source.x - originX, y: source.y - originY,
             width: source.width, height: source.height }
}

function matchesClass(klass, id) {
    var left = keyOf(klass)
    var right = keyOf(id)
    if (left === "" || right === "")
        return false
    return left === right || left.indexOf(right) >= 0 || right.indexOf(left) >= 0
}

function sameRect(left, right) {
    return left.x === right.x && left.y === right.y
           && left.width === right.width && left.height === right.height
}

// The plain window this drop knows: its address, class and global rect, or
// null while Hyprland has not reported a usable geometry yet.
function windowOf(top) {
    var source = top || ({})
    var address = text(source.address)
    if (address === "")
        return null
    var ipc = source.lastIpcObject || ({})
    var at = ipc.at
    var size = ipc.size
    if (!at || !size || at.length < 2 || size.length < 2)
        return null
    var box = { x: Number(at[0]), y: Number(at[1]),
                width: Number(size[0]), height: Number(size[1]) }
    if (!isFinite(box.x) || !isFinite(box.y) || !(box.width > 0) || !(box.height > 0))
        return null
    return {
        address: address,
        class: text(ipc["class"] || source["class"]),
        title: text(source.title || ipc.title),
        rect: box
    }
}

// The first window Hyprland gained since the launch started, on the monitor
// that asked for it. A class matching the app wins over the first newcomer.
function arrival(request, toplevels, known, screen) {
    if (!request)
        return null
    var seen = ({})
    var before = known || []
    for (var i = 0; i < before.length; i++)
        seen[text(before[i])] = true
    var list = toplevels || []
    var other = null
    for (var j = 0; j < list.length; j++) {
        var top = list[j] || ({})
        var address = text(top.address)
        if (address !== "" && seen[address] === true)
            continue
        var found = windowOf(top)
        if (!found || !onScreen(found.rect, screen))
            continue
        if (matchesClass(found.class, request.id))
            return found
        if (!other)
            other = found
    }
    return other
}

// The window mapped, but Hyprland may still be placing it: watch its rect until
// two reads agree (or `wait` passes) before the drop takes the space. The
// current target is kept meanwhile, so the drop never grows into a floating
// rect it will lose a frame later.
function watch(request, found, now, wait) {
    if (!request || !found)
        return request
    var at = number(now, 0)
    var hold = number(wait, SETTLE)
    return copy(request, {
        phase: "settling",
        address: text(found.address),
        pending: rect(found.rect),
        settleDeadline: at + (hold > 0 ? hold : SETTLE)
    })
}

// One read of a settling window. Returns the same request while the geometry is
// moving, or phase "settled" with the final rect when it has stopped.
function settle(request, toplevels, now) {
    if (!request || request.phase !== "settling")
        return request
    var list = toplevels || []
    var box = null
    for (var i = 0; i < list.length; i++) {
        if (text(list[i] && list[i].address) !== request.address)
            continue
        var found = windowOf(list[i])
        box = found ? found.rect : null
        break
    }
    var at = number(now, 0)
    var current = box || request.pending
    if (box && sameRect(box, request.pending))
        return copy(request, { phase: "settled", pending: box, final: box })
    if (at >= number(request.settleDeadline, 0))
        return copy(request, { phase: "settled", pending: current, final: current })
    return copy(request, { pending: current })
}

// The local origin of a keyboard launch: the pointer, converted to the monitor
// that will draw the drop.
function pointerOrigin(point, screen) {
    var source = point || ({})
    return {
        x: number(source.x, 0) - (screen ? number(screen.x, 0) : 0),
        y: number(source.y, 0) - (screen ? number(screen.y, 0) : 0),
        width: 2,
        height: 2
    }
}

// The monitor whose bounds contain a global point.
function screenFor(point, screens) {
    var x = number(point && point.x, 0)
    var y = number(point && point.y, 0)
    var list = screens || []
    for (var i = 0; i < list.length; i++) {
        var screen = list[i]
        if (x >= number(screen.x, 0) && x < number(screen.x, 0) + number(screen.width, 0)
                && y >= number(screen.y, 0) && y < number(screen.y, 0) + number(screen.height, 0))
            return screen
    }
    return null
}

// Window bookkeeping: every live toplevel's rect, plus what appeared and what
// closed since the previous read. A window without usable geometry keeps its
// previous entry so a transient IPC gap is not mistaken for a close.
function sync(previous, toplevels) {
    var before = previous || ({})
    var rects = ({})
    var list = toplevels || []
    for (var i = 0; i < list.length; i++) {
        var top = list[i] || ({})
        var address = text(top.address)
        if (address === "")
            continue
        var found = windowOf(top)
        if (found)
            rects[address] = found
        else if (before[address])
            rects[address] = before[address]
    }
    var added = []
    var closed = []
    for (var open in rects) {
        if (!before[open])
            added.push(rects[open])
    }
    for (var gone in before) {
        if (!rects[gone])
            closed.push(before[gone])
    }
    return { rects: rects, added: added, closed: closed }
}

// Vitrail's own windows (the settings window, the bar's helpers) do not close
// with a drop.
function own(window) {
    return keyOf(window && window.class).indexOf("vitrail") >= 0
}

// A window disappeared: puff its last rect a little and fade. `box` is already
// local to the monitor that will draw it; the burst particles are computed from
// the same rect by burst.js.
function closing(box, now, screen, puff) {
    var source = rect(box)
    var at = number(now, 0)
    var grow = number(puff, 1)
    if (!(grow > 0))
        grow = 1
    var width = source.width * grow
    var height = source.height * grow
    return {
        id: "close",
        app: ({}),
        origin: source,
        target: {
            x: Math.round(source.x - (width - source.width) / 2),
            y: Math.round(source.y - (height - source.height) / 2),
            width: Math.round(width),
            height: Math.round(height)
        },
        phase: "closing",
        started: at,
        deadline: at,
        screen: text(screen)
    }
}

// The close drop has finished shrinking and fading.
function closingDone(request, now, duration) {
    if (!request || request.phase !== "closing")
        return true
    return number(now, 0) >= number(request.started, 0) + number(duration, 0)
}

// Closes are immutable requests in a FIFO. The shell starts the next one only
// after the current burst (and any launch ahead of it) has left the overlay.
function enqueueClose(queue, request) {
    var out = (queue || []).slice()
    if (request)
        out.push(request)
    return out
}

function nextClose(queue) {
    var out = (queue || []).slice()
    return { request: out.length > 0 ? out.shift() : null, queue: out }
}

function expired(request, now) {
    return !!request && request.phase === "hold" && number(now, 0) >= request.deadline
}

function copy(source, changes) {
    var out = {}
    for (var key in source)
        out[key] = source[key]
    for (var change in (changes || ({})))
        out[change] = changes[change]
    return out
}

// The window settled: move to its final space while still opaque. The shell
// holds it for a beat before calling fade().
function arrive(request, target, now) {
    if (!request)
        return null
    return copy(request, { target: rect(target), phase: "placing", placedAt: number(now, 0) })
}

// The final space has been held: now the drop fades away from it.
function fade(request, now) {
    if (!request)
        return null
    return copy(request, { phase: "fading", fadedAt: number(now, 0) })
}

// No window in time: give up and fade from the space already held.
function timeout(request, now) {
    if (!request)
        return null
    return copy(request, { phase: "fading", fadedAt: number(now, 0) })
}

function active(request) {
    return request !== undefined && request !== null && request.phase !== "done"
}

function finish(request) {
    return null
}
