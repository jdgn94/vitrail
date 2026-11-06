// The dock's model: pinned apps, the windows Hyprland has open, the order a
// drag writes and the geometry and magnification the surface draws.
//
// Nothing here touches a Quickshell type: the layer maps `Hyprland.toplevels`
// to the plain windows this file takes, so the rules can be tested offscreen.
.pragma library

// The default pinned document: a JSON array of
// { id, desktop, name, icon }. Older or hand-written documents may hold bare
// desktop ids; they are read as apps that still need their name.
var EMPTY = []

function text(value) {
    return String(value === undefined || value === null ? "" : value)
}

// The key an app answers to: the desktop id or the Hyprland window class,
// lowercased and stripped of its .desktop suffix and punctuation, so
// "firefox.desktop", "Firefox" and "firefox" meet.
function keyOf(value) {
    return text(value).trim().toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
}

function parsePinned(document) {
    var parsed
    try {
        parsed = JSON.parse(text(document))
    } catch (error) {
        return []
    }
    if (!Array.isArray(parsed))
        return []
    var out = []
    for (var i = 0; i < parsed.length; i++) {
        var entry = parsed[i]
        if (typeof entry === "string" || typeof entry === "number") {
            var bare = text(entry)
            if (bare !== "")
                out.push({ id: bare, desktop: bare, name: bare, icon: "" })
        } else if (entry && typeof entry === "object") {
            var id = text(entry.id || entry.desktop)
            if (id === "")
                continue
            out.push({
                id: id,
                desktop: text(entry.desktop || id),
                name: text(entry.name || id),
                icon: text(entry.icon)
            })
        }
    }
    return out
}

function serializePinned(list) {
    var out = []
    for (var i = 0; i < (list || []).length; i++) {
        var entry = list[i]
        if (!entry)
            continue
        out.push({
            id: text(entry.id || entry.desktop),
            desktop: text(entry.desktop || entry.id),
            name: text(entry.name || entry.id || entry.desktop),
            icon: text(entry.icon)
        })
    }
    return JSON.stringify(out)
}

function sameApp(entry, id) {
    if (!entry)
        return false
    var key = keyOf(id)
    return key !== "" && (keyOf(entry.id) === key || keyOf(entry.desktop) === key
                          || keyOf(entry.icon) === key)
}

function isPinned(list, id) {
    for (var i = 0; i < (list || []).length; i++) {
        if (sameApp(list[i], id))
            return true
    }
    return false
}

// The launcher's item becomes the pinned entry: the desktop file, its name and
// its icon, in the order that was already there.
function pin(list, app) {
    var out = (list || []).slice()
    var id = text(app && (app.id || app.desktop))
    if (id === "")
        return out
    if (isPinned(out, id))
        return out
    out.push({
        id: id,
        desktop: text((app && (app.desktop || app.id)) || id),
        name: text((app && app.name) || id),
        icon: text(app && app.icon)
    })
    return out
}

function unpin(list, id) {
    return (list || []).filter(function (entry) { return !sameApp(entry, id) })
}

function togglePin(list, app) {
    var id = text(app && (app.id || app.desktop))
    return isPinned(list, id) ? unpin(list, id) : pin(list, app)
}

// The launcher's context-menu row for an app. `labels` is
// { pin, unpin, glyphPin, glyphUnpin } so the row speaks the shell's language.
function menuRow(pinnedText, item, labels) {
    var onDock = isPinned(parsePinned(pinnedText), item && item.id)
    var words = labels || ({})
    return {
        title: text(onDock ? (words.unpin || "Remove from dock") : (words.pin || "Pin to dock")),
        glyph: text(onDock ? (words.glyphUnpin || "remove") : (words.glyphPin || "dock")),
        run: { kind: "dockPin", item: item },
        dock: onDock
    }
}

// Dragging moves one entry; the result is what `dockPinned` stores.
function move(list, from, to) {
    var out = (list || []).slice()
    if (out.length === 0)
        return out
    var start = Math.max(0, Math.min(out.length - 1, Math.round(from)))
    var end = Math.max(0, Math.min(out.length - 1, Math.round(to)))
    if (start === end)
        return out
    var moved = out.splice(start, 1)[0]
    out.splice(end, 0, moved)
    return out
}

// The index a horizontal or vertical drag lands on: one whole cell is one
// place, and a drag that ends between two cells keeps the nearest.
function dropIndex(from, delta, step, count) {
    if (count <= 0)
        return 0
    if (step <= 0)
        return Math.max(0, Math.min(count - 1, Math.round(from)))
    return Math.max(0, Math.min(count - 1, Math.round(from + delta / step)))
}

// Hyprland's toplevels as the plain windows the dock groups. Each window is
// { address, title, class, active }; a class is one dock app, however many
// windows it has open.
function windowsOf(toplevels, activeAddress) {
    var out = []
    var list = toplevels || []
    for (var i = 0; i < list.length; i++) {
        var top = list[i]
        var ipc = (top && top.lastIpcObject) || ({})
        var klass = text(ipc["class"] || top["class"] || "")
        if (klass === "")
            continue
        out.push({
            address: text(top.address),
            title: text(top.title || ipc.title),
            class: klass,
            active: activeAddress !== undefined && text(top.address) === text(activeAddress)
        })
    }
    return out
}

// One entry per class: the app's window with the focus wins, so clicking the
// dock focuses what the user was last using.
function openApps(windows) {
    var groups = []
    var at = ({})
    for (var i = 0; i < (windows || []).length; i++) {
        var window = windows[i]
        var key = keyOf(window.class || window.title)
        if (key === "")
            continue
        if (at[key] === undefined) {
            at[key] = groups.length
            groups.push({
                id: text(window.class),
                name: text(window.class),
                icon: text(window.class),
                title: text(window.title),
                open: true,
                active: window.active === true,
                address: text(window.address),
                addresses: []
            })
        }
        var group = groups[at[key]]
        group.addresses.push(text(window.address))
        if (window.active === true) {
            group.active = true
            group.address = text(window.address)
            group.title = text(window.title)
        } else if (group.title === "" && window.title !== "") {
            group.title = text(window.title)
        }
    }
    return groups
}

// The pinned apps in their stored order, then the open apps that are not
// among them. A pinned app with a window is still one entry: it gains `open`,
// `active` and the window to focus.
function model(pinned, windows) {
    var apps = openApps(windows)
    var used = ({})
    var out = []
    for (var i = 0; i < (pinned || []).length; i++) {
        var entry = pinned[i]
        var matches = []
        for (var j = 0; j < apps.length; j++) {
            if (sameApp(entry, apps[j].id) || sameApp(entry, apps[j].icon)) {
                matches.push(apps[j])
                used[apps[j].id] = true
            }
        }
        var focused = null
        for (var k = 0; k < matches.length; k++) {
            if (matches[k].active) {
                focused = matches[k]
                break
            }
        }
        if (!focused && matches.length > 0)
            focused = matches[0]
        out.push({
            kind: "pinned",
            key: "pinned:" + keyOf(entry.id || entry.desktop),
            id: text(entry.id),
            desktop: text(entry.desktop || entry.id),
            name: text(entry.name || entry.id),
            icon: text(entry.icon),
            open: matches.length > 0,
            active: focused !== null && focused.active,
            address: focused !== null ? focused.address : "",
            title: focused !== null ? focused.title : "",
            windows: matches
        })
    }
    for (var m = 0; m < apps.length; m++) {
        if (used[apps[m].id] === true)
            continue
        out.push({
            kind: "open",
            key: "open:" + keyOf(apps[m].id),
            id: text(apps[m].id),
            desktop: "",
            name: text(apps[m].name || apps[m].title || apps[m].id),
            icon: text(apps[m].icon),
            open: true,
            active: apps[m].active === true,
            address: text(apps[m].address),
            title: text(apps[m].title),
            windows: [apps[m]]
        })
    }
    return out
}

// --- geometry ---------------------------------------------------------------

function vertical(edge) {
    return edge === "left" || edge === "right"
}

function shown(autohide, revealed, forced) {
    return !autohide || revealed === true || forced === true
}

// Attached crooks no corner; floating does.
function radius(attached, value) {
    return attached ? 0 : value
}

function margin(attached, value) {
    return attached ? 0 : value
}

// Where the card sits in the layer's edge band. Hidden, it rests just outside
// the band; the reveal slides it back to its margin.
function place(edge, bandWidth, bandHeight, width, height, gap, progress) {
    var p = Math.max(0, Math.min(1, progress))
    var shownX = (bandWidth - width) / 2
    var shownY = (bandHeight - height) / 2
    var hiddenX = shownX
    var hiddenY = shownY
    if (edge === "bottom") {
        shownY = bandHeight - height - gap
        hiddenY = bandHeight
    } else if (edge === "top") {
        shownY = gap
        hiddenY = -height
    } else if (edge === "left") {
        shownX = gap
        hiddenX = -width
    } else if (edge === "right") {
        shownX = bandWidth - width - gap
        hiddenX = bandWidth
    }
    return {
        x: hiddenX + (shownX - hiddenX) * p,
        y: hiddenY + (shownY - hiddenY) * p
    }
}

// The two magnifications, plus off. `scale` and `lift` were the old names:
// a stored value from before the planet/individual pair reads as planet.
function magnifyStyle(value) {
    var style = text(value).trim().toLowerCase()
    if (style === "none" || style === "individual")
        return style
    return "planet"
}

function magnifySpec(spec) {
    var values = spec || ({})
    var range = Number(values.range)
    var scale = Number(values.scale)
    return {
        range: isFinite(range) ? Math.max(1, Math.min(5, range)) : 2,
        scale: isFinite(scale) ? Math.max(1.1, Math.min(2, scale)) : 1.32
    }
}

// Planet: the icon under the pointer is the largest and its neighbours fall
// away smoothly until the range, where the falloff stops. Individual: only the
// hovered icon grows, whatever the range. The result is a scale around 1.
function magnify(style, distance, spec) {
    var kind = magnifyStyle(style)
    if (kind === "none")
        return { scale: 1 }
    if (distance === undefined || distance === null || distance < 0)
        return { scale: 1 }
    var values = magnifySpec(spec)
    if (kind === "individual")
        return { scale: distance < 1 ? values.scale : 1 }
    if (distance >= values.range)
        return { scale: 1 }
    var falloff = 0.5 * (1 + Math.cos(Math.PI * distance / values.range))
    return { scale: 1 + (values.scale - 1) * falloff }
}

// A pinned app that is open focuses its window; one that is not launches.
function activates(item) {
    return !!(item && item.open === true && text(item.address) !== "")
}
