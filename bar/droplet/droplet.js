// The launch droplet: the state machine behind the splash that grows from an
// icon into the space a launching window will take.
//
// Pure, no QML types: the shell owns the request, this file decides when it
// starts, what space it holds, when the new window replaces that space and
// when it gives up. Geometry is screen-local; `local()` converts Hyprland's
// global window rect for the monitor that asked.
.pragma library

var TIMEOUT = 4000

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

// The space the drop holds when the window is not known yet: a centred block
// whose shares of the screen come from the tokens.
function fallback(width, height, shareWidth, shareHeight) {
    var w = Math.round(Math.max(0, number(width, 0)) * number(shareWidth, 0.5))
    var h = Math.round(Math.max(0, number(height, 0)) * number(shareHeight, 0.55))
    return {
        x: Math.round((number(width, 0) - w) / 2),
        y: Math.round((number(height, 0) - h) / 2),
        width: w,
        height: h
    }
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
        var ipc = top.lastIpcObject || ({})
        var at = ipc.at
        var size = ipc.size
        if (!at || !size || at.length < 2 || size.length < 2)
            continue
        var box = { x: Number(at[0]), y: Number(at[1]),
                    width: Number(size[0]), height: Number(size[1]) }
        if (!isFinite(box.x) || !isFinite(box.y) || !(box.width > 0) || !(box.height > 0))
            continue
        if (!onScreen(box, screen))
            continue
        var klass = text(ipc["class"] || top["class"])
        var found = { address: address, class: klass, title: text(top.title || ipc.title),
                      rect: box }
        if (matchesClass(klass, request.id))
            return found
        if (!other)
            other = found
    }
    return other
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

// The window mapped: the drop takes its space and begins to fade.
function arrive(request, target, now) {
    if (!request)
        return null
    return copy(request, { target: rect(target), phase: "fading", fadedAt: number(now, 0) })
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
