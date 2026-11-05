.pragma library
.import "widgets.js" as Registry

// The layout document of a shell surface: which elements it draws, in which
// order, and their density. The bar writes one JSON document in bar.ini
// (`barLayout`); the notification panel writes another (`panelLayout`). The
// settings window's Bar → Editor tab is the one UI that edits them, and the
// desktop (later) will reuse this file with a document of its own.
//
// bar:
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
// panel (flat: one list, and the size/style of each widget):
//     {
//       "order": ["media", "toggles", "capture", "notes", "session"],
//       "hidden": [],
//       "widgets": { "media": { "size": "md", "style": "" } }
//     }
//
// desktop (one placed list per monitor; x/y are 0..1 of the monitor):
//     {
//       "monitors": { "DP-1": { "widgets": [
//         { "id": "clock", "x": 0.35, "y": 0.30, "size": "lg", "style": "full" }
//       ] } }
//     }
//
// An empty or invalid document is the built-in default: today's bar or today's
// panel, and no desktop widgets. Per-monitor entries replace the global field
// they name (a monitor without one follows the global value); the editor
// writes the whole field, so a monitor never inherits half an override.

// The groups of each surface, in the order the settings page lists them. An
// empty list is a flat surface (one ordered list, no groups).
var SURFACES = {
    bar: ["start", "center", "end"],
    panel: [],
    desktop: []
}

var FLAT = { panel: true }

// The desktop is not a flat order either: every monitor places its own widgets
// at a point of the screen.
var DESKTOP = { desktop: true }

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

function has(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key)
}

function parse(text) {
    try {
        return objectOf(JSON.parse(text))
    } catch (error) {
        return null
    }
}

function isFlat(surface) {
    return FLAT[surface || "bar"] === true
}

function isDesktop(surface) {
    return DESKTOP[surface || ""] === true
}

function groups(surface) {
    return (SURFACES[surface || "bar"] || []).slice()
}

function widgets(surface) {
    return Registry.on(surface || "bar")
}

function find(id, surface) {
    return Registry.find(id, surface || "bar")
}

function defaultHidden(surface) {
    return (DEFAULT_HIDDEN[surface || "bar"] || []).slice()
}

// The built-in document: every element, in this file's order, with today's
// look (only the editor-only elements hidden).
function defaults(surface) {
    var name = surface || "bar"
    if (isDesktop(name))
        return { monitors: {} }
    if (isFlat(name))
        return { order: cleanFlatList([], name), hidden: defaultHidden(name), widgets: {} }
    var out = { order: {}, hidden: defaultHidden(name), density: "comfortable",
                hideFullscreen: true, monitors: {} }
    var names = groups(name)
    for (var i = 0; i < names.length; i++)
        out.order[names[i]] = []
    var list = widgets(name)
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

// A whole flat order: the document's placement, then every widget it forgot in
// the registry's own order. Never loses or duplicates a widget.
function cleanFlatList(list, surface) {
    var out = cleanList(list, knownIds(surface))
    var all = widgets(surface)
    for (var i = 0; i < all.length; i++) {
        if (out.indexOf(all[i].id) < 0)
            out.push(all[i].id)
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

// One widget's size and style, checked against the registry. The default size
// is the widget's "md" when it has one; no style means the widget's own
// default (for the player, the bar's `mediaStyle` preference).
function cleanSetting(entry, widget) {
    if (!widget)
        return { size: "md", style: "" }
    var value = objectOf(entry) || {}
    var sizes = widget.sizes || []
    var styles = widget.styles || []
    var size = sizes.indexOf(value.size) >= 0 ? value.size : Registry.defaultSize(widget)
    var style = typeof value.style === "string"
                && (value.style === "" || styles.indexOf(value.style) >= 0) ? value.style : ""
    return { size: size, style: style }
}

function copyWidgets(widgets) {
    var out = {}
    var values = objectOf(widgets)
    if (!values)
        return out
    for (var id in values) {
        var entry = objectOf(values[id])
        if (entry)
            out[id] = { size: entry.size, style: entry.style }
    }
    return out
}

// Only the widgets the document names, each size/style checked. Unknown ids and
// unknown sizes/styles fall back (a hand-edited document still shows).
function cleanWidgets(raw, surface) {
    var out = {}
    var values = objectOf(raw) || {}
    var list = widgets(surface)
    for (var i = 0; i < list.length; i++) {
        var widget = list[i]
        if (!has(values, widget.id))
            continue
        var entry = objectOf(values[widget.id])
        if (!entry)
            continue
        out[widget.id] = cleanSetting(entry, widget)
    }
    return out
}

// The widget's effective size/style in a document (the defaults when it is not
// named).
function setting(doc, id, surface) {
    var widget = find(id, surface)
    var widgets = objectOf(doc) ? objectOf(doc.widgets) : null
    return cleanSetting(widgets ? widgets[id] : null, widget)
}

// The settings object with one widget patched; the input is never changed.
function configure(widgets, id, values, surface) {
    var widget = find(id, surface)
    var out = copyWidgets(widgets)
    if (!widget)
        return out
    var current = cleanSetting(out[id], widget)
    var patch = objectOf(values) || {}
    if (has(patch, "size"))
        current.size = patch.size
    if (has(patch, "style"))
        current.style = patch.style
    out[id] = cleanSetting(current, widget)
    return out
}

// --- the desktop: one placed list of widgets per monitor -------------------

// A point of the monitor: 0..1 from its top-left, clamped. A missing or
// unreadable coordinate is the centre.
function coordinate(value, fallback) {
    if (value === null || value === undefined || value === "")
        return fallback
    var number = Number(value)
    if (!isFinite(number))
        return fallback
    return Math.max(0, Math.min(1, number))
}

// A widget with its id, point and validated size/style, in a stable shape.
function cleanDesktopWidget(entry) {
    var value = objectOf(entry)
    if (!value || typeof value.id !== "string")
        return null
    var widget = find(value.id, "desktop")
    if (!widget)
        return null
    var setting = cleanSetting(value, widget)
    return { id: widget.id,
             x: coordinate(value.x, 0.5),
             y: coordinate(value.y, 0.5),
             size: setting.size,
             style: setting.style }
}

// One widget per id, in document order; unknown ids and duplicates drop.
function cleanDesktopWidgets(list) {
    var out = []
    var seen = {}
    if (!Array.isArray(list))
        return out
    for (var i = 0; i < list.length; i++) {
        var widget = cleanDesktopWidget(list[i])
        if (!widget || seen[widget.id])
            continue
        seen[widget.id] = true
        out.push(widget)
    }
    return out
}

function copyDesktopWidgets(list) {
    var out = []
    if (!Array.isArray(list))
        return out
    for (var i = 0; i < list.length; i++) {
        var widget = objectOf(list[i])
        if (widget)
            out.push({ id: widget.id, x: widget.x, y: widget.y,
                       size: widget.size, style: widget.style })
    }
    return out
}

function cleanDesktopMonitors(raw) {
    var out = {}
    var monitors = objectOf(raw) || {}
    for (var name in monitors) {
        var entry = objectOf(monitors[name])
        if (!entry)
            continue
        var widgets = cleanDesktopWidgets(entry.widgets)
        if (widgets.length > 0)
            out[name] = { widgets: widgets }
    }
    return out
}

function desktopWidgets(doc, monitor) {
    var values = objectOf(doc) ? objectOf(doc.monitors) : null
    var entry = values && monitor ? objectOf(values[monitor]) : null
    return entry ? copyDesktopWidgets(entry.widgets) : []
}

// How many widgets the document places on every monitor.
function desktopCount(textOrDoc) {
    var doc = sanitize(textOrDoc, "desktop")
    var total = 0
    for (var name in doc.monitors)
        total += doc.monitors[name].widgets.length
    return total
}

// One widget added at a point, unless it is unknown or already there.
function desktopAdd(widgets, id, x, y) {
    var out = copyDesktopWidgets(widgets)
    var widget = find(id, "desktop")
    if (!widget)
        return out
    for (var i = 0; i < out.length; i++) {
        if (out[i].id === id)
            return out
    }
    var setting = cleanSetting({}, widget)
    out.push({ id: id,
               x: coordinate(x, 0.5),
               y: coordinate(y, 0.5),
               size: setting.size,
               style: setting.style })
    return out
}

function desktopRemove(widgets, id) {
    var out = []
    var list = copyDesktopWidgets(widgets)
    for (var i = 0; i < list.length; i++) {
        if (list[i].id !== id)
            out.push(list[i])
    }
    return out
}

function desktopMove(widgets, id, x, y) {
    var out = copyDesktopWidgets(widgets)
    for (var i = 0; i < out.length; i++) {
        if (out[i].id === id) {
            out[i].x = coordinate(x, out[i].x)
            out[i].y = coordinate(y, out[i].y)
            break
        }
    }
    return out
}

function desktopConfigure(widgets, id, values) {
    var out = copyDesktopWidgets(widgets)
    var widget = find(id, "desktop")
    if (!widget)
        return out
    var patch = objectOf(values) || {}
    for (var i = 0; i < out.length; i++) {
        if (out[i].id !== id)
            continue
        var current = { size: out[i].size, style: out[i].style }
        if (has(patch, "size"))
            current.size = patch.size
        if (has(patch, "style"))
            current.style = patch.style
        var setting = cleanSetting(current, widget)
        out[i].size = setting.size
        out[i].style = setting.style
        break
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
    if (isDesktop(name))
        return { monitors: cleanDesktopMonitors(raw.monitors) }
    if (isFlat(name)) {
        return {
            order: cleanFlatList(raw.order, name),
            hidden: Array.isArray(raw.hidden) ? cleanList(raw.hidden, knownIds(name)) : defaultHidden(name),
            widgets: cleanWidgets(raw.widgets, name)
        }
    }
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
// preference falls back to (another surface's default, later). A flat surface
// has no per-monitor overrides.
function effective(layout, monitor, base, surface) {
    var name = surface || "bar"
    var source = layout === undefined || layout === null || layout === "" ? base : layout
    var doc = sanitize(source, name)
    if (isDesktop(name))
        return { widgets: desktopWidgets(doc, monitor) }
    if (isFlat(name))
        return { order: doc.order.slice(), hidden: doc.hidden.slice(), widgets: copyWidgets(doc.widgets) }
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
// one passed in. A flat surface passes its list instead of the group object.
function move(order, id, delta) {
    if (Array.isArray(order)) {
        var list = order.slice()
        if (!delta)
            return list
        var at = list.indexOf(id)
        if (at < 0)
            return list
        var to = at + (delta < 0 ? -1 : 1)
        if (to < 0 || to >= list.length)
            return list
        var held = list[at]
        list[at] = list[to]
        list[to] = held
        return list
    }
    var out = copyOrder(order)
    if (!delta)
        return out
    for (var group in out) {
        var index = out[group].indexOf(id)
        if (index < 0)
            continue
        var place = index + (delta < 0 ? -1 : 1)
        if (place < 0 || place >= out[group].length)
            return out
        var swap = out[group][index]
        out[group][index] = out[group][place]
        out[group][place] = swap
        return out
    }
    return out
}

// One list entry moved to a new place, the rest shifting to make room; a new
// list, never the one passed in. Out-of-range places are clamped.
function reorder(list, from, to) {
    var out = Array.isArray(list) ? list.slice() : []
    if (from < 0 || from >= out.length)
        return out
    var target = Math.max(0, Math.min(out.length - 1, to))
    var item = out.splice(from, 1)[0]
    out.splice(target, 0, item)
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
// the global document (density and fullscreen hiding included). A flat
// surface writes its order, hidden list and per-widget settings.
function write(text, monitor, patch, surface) {
    var name = surface || "bar"
    var before = sanitize(text, name)
    var doc = sanitize(text, name)
    var values = objectOf(patch) || {}
    if (isDesktop(name)) {
        if (monitor && has(values, "widgets")) {
            var placed = copyDesktopWidgets(values.widgets)
            if (placed.length > 0)
                doc.monitors[monitor] = { widgets: cleanDesktopWidgets(placed) }
            else
                delete doc.monitors[monitor]
        }
    } else if (isFlat(name)) {
        if (has(values, "order"))
            doc.order = (values.order || []).slice()
        if (has(values, "hidden"))
            doc.hidden = (values.hidden || []).slice()
        if (has(values, "widgets"))
            doc.widgets = copyWidgets(values.widgets)
    } else if (monitor) {
        var entry = doc.monitors[monitor] || {}
        if (has(values, "order"))
            entry.order = copyOrder(values.order)
        if (has(values, "hidden"))
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
