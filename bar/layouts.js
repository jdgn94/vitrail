.pragma library

// The layout document of a shell surface: which elements it draws, in which
// order, and their density. The bar writes one JSON document in bar.ini
// (`barLayout`); the settings window's Bar → Editor tab is the one UI that
// edits it, and panel, desktop and lock will reuse this file with a document
// of their own (add their widgets and groups to SURFACES / WIDGETS).
//
//     {
//       "order": { "start": ["launcher", "notifications"],
//                  "center": ["media", "clock"],
//                  "end": ["tray", "network", "vpn", "profile", "power"] },
//       "hidden": [],
//       "density": "comfortable",
//       "hideFullscreen": true,
//       "monitors": { "DP-1": { "hidden": ["tray"], "order": { ... } } }
//     }
//
// An empty or invalid document is the built-in default: today's bar.
// Per-monitor entries replace the global field they name (a monitor without
// one follows the global value); the editor writes the whole field, so a
// monitor never inherits half an override.

// The groups of each surface, in the order the settings page lists them.
var SURFACES = {
    bar: ["start", "center", "end"]
}

// The elements of each surface: `group` is the group it goes back to when the
// document does not place it; `label` is the i18n key the editor shows.
var WIDGETS = [
    { id: "launcher", surface: "bar", group: "start", label: "bar.widget.launcher" },
    { id: "notifications", surface: "bar", group: "start", label: "bar.widget.notifications" },
    { id: "media", surface: "bar", group: "center", label: "bar.widget.media" },
    { id: "clock", surface: "bar", group: "center", label: "bar.widget.clock" },
    { id: "capture", surface: "bar", group: "end", label: "bar.widget.capture" },
    { id: "recording", surface: "bar", group: "end", label: "bar.widget.recording" },
    { id: "tray", surface: "bar", group: "end", label: "bar.widget.tray" },
    { id: "network", surface: "bar", group: "end", label: "bar.widget.network" },
    { id: "bluetooth", surface: "bar", group: "end", label: "bar.widget.bluetooth" },
    { id: "vpn", surface: "bar", group: "end", label: "bar.widget.vpn" },
    { id: "profile", surface: "bar", group: "end", label: "bar.widget.profile" },
    { id: "battery", surface: "bar", group: "end", label: "bar.widget.battery" },
    { id: "keyboard", surface: "bar", group: "end", label: "bar.widget.keyboard" },
    { id: "power", surface: "bar", group: "end", label: "bar.widget.power" }
]

// Elements the bar does not draw until the user asks for them: the screenshot
// button is an editor option, not a change to today's bar.
var DEFAULT_HIDDEN = { bar: ["capture"] }

// Elements that share one pill (`cluster`) while they are next to each other.
var CLUSTERS = {
    bar: { network: "connections", bluetooth: "connections", vpn: "connections", profile: "connections" }
}

var DENSITIES = ["comfortable", "compact"]

function objectOf(value) {
    return value && typeof value === "object" && !Array.isArray(value) ? value : null
}

function parse(text) {
    try {
        return objectOf(JSON.parse(text))
    } catch (error) {
        return null
    }
}

function groups(surface) {
    return (SURFACES[surface || "bar"] || []).slice()
}

function widgets(surface) {
    var name = surface || "bar"
    return WIDGETS.filter(function (widget) {
        return widget.surface === name
    })
}

function find(id, surface) {
    var list = widgets(surface)
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i]
    }
    return null
}

function defaultHidden(surface) {
    return (DEFAULT_HIDDEN[surface || "bar"] || []).slice()
}

// The built-in document: every element, in this file's order, with today's
// look (only the editor-only elements hidden).
function defaults(surface) {
    var out = { order: {}, hidden: defaultHidden(surface), density: "comfortable",
                hideFullscreen: true, monitors: {} }
    var names = groups(surface)
    for (var i = 0; i < names.length; i++)
        out.order[names[i]] = []
    var list = widgets(surface)
    for (var j = 0; j < list.length; j++) {
        if (out.order[list[j].group])
            out.order[list[j].group].push(list[j].id)
    }
    return out
}

function knownIds(surface) {
    var out = {}
    var list = widgets(surface)
    for (var i = 0; i < list.length; i++)
        out[list[i].id] = true
    return out
}

// Known ids in document order, each once.
function cleanList(list, known) {
    var out = []
    if (!Array.isArray(list))
        return out
    for (var i = 0; i < list.length; i++) {
        var id = list[i]
        if (typeof id === "string" && known[id] && out.indexOf(id) < 0)
            out.push(id)
    }
    return out
}

// A whole order: the document's placement, then every element it forgot in
// its own group. Never loses or duplicates an element.
function cleanOrder(source, surface) {
    var known = knownIds(surface)
    var taken = {}
    var names = groups(surface)
    var out = {}
    var raw = objectOf(source) || {}
    for (var i = 0; i < names.length; i++) {
        var group = names[i]
        out[group] = []
        var list = cleanList(raw[group], known)
        for (var j = 0; j < list.length; j++) {
            if (taken[list[j]])
                continue
            taken[list[j]] = true
            out[group].push(list[j])
        }
    }
    var all = widgets(surface)
    for (var k = 0; k < all.length; k++) {
        var widget = all[k]
        if (taken[widget.id])
            continue
        taken[widget.id] = true
        var home = out[widget.group] ? widget.group : names[0]
        if (out[home])
            out[home].push(widget.id)
    }
    return out
}

function copyOrder(order) {
    var out = {}
    for (var group in order)
        out[group] = order[group].slice()
    return out
}

function cleanMonitors(raw, surface) {
    var out = {}
    var monitors = objectOf(raw) || {}
    for (var name in monitors) {
        var entry = objectOf(monitors[name])
        if (!entry)
            continue
        var clean = {}
        if (Array.isArray(entry.hidden))
            clean.hidden = cleanList(entry.hidden, knownIds(surface))
        if (objectOf(entry.order))
            clean.order = cleanOrder(entry.order, surface)
        if (clean.hidden || clean.order)
            out[name] = clean
    }
    return out
}

// The document from preference text (or an already parsed object), completed
// and type-checked. Anything that is not a valid document becomes the default.
function sanitize(text, surface) {
    var name = surface || "bar"
    var raw = typeof text === "string" ? parse(text) : objectOf(text)
    if (!raw)
        raw = {}
    var out = {}
    out.order = cleanOrder(raw.order, name)
    out.hidden = Array.isArray(raw.hidden) ? cleanList(raw.hidden, knownIds(name)) : defaultHidden(name)
    out.density = raw.density === "compact" ? "compact" : "comfortable"
    out.hideFullscreen = !(raw.hideFullscreen === false || raw.hideFullscreen === "false")
    out.monitors = cleanMonitors(raw.monitors, name)
    return out
}

// What one monitor draws: the global document with that monitor's order and
// hidden list substituted when it has them. `base` is the document an empty
// preference falls back to (another surface's default, later).
function effective(layout, monitor, base, surface) {
    var name = surface || "bar"
    var source = layout === undefined || layout === null || layout === "" ? base : layout
    var doc = sanitize(source, name)
    var entry = monitor && doc.monitors[monitor] ? doc.monitors[monitor] : null
    return {
        order: copyOrder(entry && entry.order ? entry.order : doc.order),
        hidden: (entry && entry.hidden ? entry.hidden : doc.hidden).slice(),
        density: doc.density,
        hideFullscreen: doc.hideFullscreen
    }
}

// The ids of one group that are not hidden, in order.
function visible(orderGroup, hidden) {
    var list = Array.isArray(orderGroup) ? orderGroup : []
    var out = []
    for (var i = 0; i < list.length; i++) {
        if ((hidden || []).indexOf(list[i]) < 0)
            out.push(list[i])
    }
    return out
}

function clusterOf(id, surface) {
    var table = CLUSTERS[surface || "bar"] || {}
    return table[id] || null
}

// One visual entry per element, with neighbouring elements of a cluster folded
// into one: the bar draws such a run inside a single pill.
function entries(orderGroup, hidden, surface) {
    var list = visible(orderGroup, hidden)
    var out = []
    var run = null
    for (var i = 0; i < list.length; i++) {
        var id = list[i]
        var cluster = clusterOf(id, surface)
        if (cluster === null) {
            out.push({ id: id })
            run = null
        } else if (run !== null && run.cluster === cluster) {
            run.ids.push(id)
        } else {
            run = { cluster: cluster, ids: [id] }
            out.push(run)
        }
    }
    return out
}

// One element moved `delta` places inside its group; a new order, never the
// one passed in.
function move(order, id, delta) {
    var out = copyOrder(order)
    if (!delta)
        return out
    for (var group in out) {
        var at = out[group].indexOf(id)
        if (at < 0)
            continue
        var to = at + (delta < 0 ? -1 : 1)
        if (to < 0 || to >= out[group].length)
            return out
        var held = out[group][at]
        out[group][at] = out[group][to]
        out[group][to] = held
        return out
    }
    return out
}

// One element shown or hidden; a new list, never the one passed in.
function toggle(hidden, id) {
    var out = (hidden || []).slice()
    var at = out.indexOf(id)
    if (at < 0)
        out.push(id)
    else
        out.splice(at, 1)
    return out
}

// The new document text for a patch, or null when nothing changed. With a
// monitor, only that output's order and hidden list are written; without one,
// the global document (density and fullscreen hiding included).
function write(text, monitor, patch, surface) {
    var name = surface || "bar"
    var before = sanitize(text, name)
    var doc = sanitize(text, name)
    var values = objectOf(patch) || {}
    if (monitor) {
        var entry = doc.monitors[monitor] || {}
        if (Object.prototype.hasOwnProperty.call(values, "order"))
            entry.order = copyOrder(values.order)
        if (Object.prototype.hasOwnProperty.call(values, "hidden"))
            entry.hidden = (values.hidden || []).slice()
        if (entry.order || entry.hidden)
            doc.monitors[monitor] = entry
    } else {
        if (values.order)
            doc.order = copyOrder(values.order)
        if (values.hidden)
            doc.hidden = values.hidden.slice()
        if (values.density !== undefined)
            doc.density = values.density === "compact" ? "compact" : "comfortable"
        if (values.hideFullscreen !== undefined)
            doc.hideFullscreen = values.hideFullscreen !== false
    }
    var after = sanitize(doc, name)
    if (JSON.stringify(after) === JSON.stringify(before))
        return null
    return JSON.stringify(after)
}
