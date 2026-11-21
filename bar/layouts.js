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
//                  "end": ["tray", "@connections", "power"] },
//       "hidden": [],
//       "chips": { "connections": { "members": ["network", "bluetooth",
//                                               "vpn", "profile"] } },
//       "density": "comfortable",
//       "hideFullscreen": true,
//       "monitors": { "DP-1": { "hidden": ["tray"], "order": { ... } } }
//     }
//
// A group's order names elements and, with `@<chip>`, whole chips; a divider
// is `divider`, `divider-2`… `chips` is global (a monitor override only
// replaces its order and hidden list). An element moved by hand follows its
// new group, except the fixed ones (launcher, tray, power), which always stay
// in their own group.
//
// panel (flat: one list, and the size/style/typography of each widget):
//     {
//       "order": ["media", "toggles", "capture", "notes", "session"],
//       "hidden": [],
//       "widgets": { "media": { "size": "md", "style": "",
//                               "font": "Inter", "weight": "bold", "italic": true } }
//     }
//
// desktop (a shared placed list, and one list per monitor; x/y are 0..1):
//     {
//       "shared": [
//         { "id": "clock", "x": 0.35, "y": 0.30, "size": "lg", "style": "full",
//           "font": "Inter", "weight": "bold", "italic": true }
//       ],
//       "monitors": { "DP-1": { "widgets": [ ... ] } }
//     }
//
// `shared` is the desktop of every monitor while `desktopSync` is on; the
// per-monitor `monitors` entries are the unsynced documents. A document
// written before the preference existed has no `shared`: it keeps working one
// monitor at a time until the first synced edit writes one.
//
// A widget setting carries its own typography: `font` is a family name ("" or
// a missing/unknown value inherits the shell's font), `weight` is "" (inherit)
// or one of "regular", "medium", "bold" (case and padding are normalised, an
// unknown weight inherits), and `italic` is a boolean (only `true` turns it on).
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
var DEFAULT_HIDDEN = { bar: ["capture", "sample", "volume", "updates", "disks"] }

// Chips: several elements that share one pill. The document stores them in
// `chips` and places the chip itself with its token (`"@connections"`) in a
// group's order, so a chip moves between groups like any other entry. A
// document without `chips` keeps the built-in one, which is exactly the pill
// the bar had before chips were editable.
var DEFAULT_CHIPS = {
    bar: {
        connections: { members: ["network", "bluetooth", "vpn", "profile"] }
    }
}

// The order entry that stands for a chip: `@<chip id>`.
var CHIP_PREFIX = "@"

var DENSITIES = ["comfortable", "compact"]

// The weights a widget may ask for; "" inherits the variant's own.
var WEIGHTS = ["regular", "medium", "bold"]

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
// look (only the editor-only elements hidden). A chip takes the place of its
// first member; the divider is never added on its own.
function defaults(surface) {
    var name = surface || "bar"
    if (isDesktop(name))
        return { monitors: {} }
    if (isFlat(name))
        return { order: cleanFlatList([], name), hidden: defaultHidden(name), widgets: {} }
    var chips = defaultChips(name)
    return { order: cleanOrder({}, name, chips), hidden: defaultHidden(name), chips: chips,
             density: "comfortable", hideFullscreen: true, monitors: {} }
}

function knownIds(surface) {
    var out = {}
    var list = widgets(surface)
    for (var i = 0; i < list.length; i++)
        out[list[i].id] = true
    return out
}

// Known ids in document order, each once. Every divider id counts; documents
// may place as many as they like, so a hidden list can name them too.
function cleanList(list, known) {
    var out = []
    if (!Array.isArray(list))
        return out
    for (var i = 0; i < list.length; i++) {
        var id = list[i]
        if (typeof id === "string" && (known[id] || Registry.isDivider(id)) && out.indexOf(id) < 0)
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

// A whole order: the document's placement, then every element it forgot in its
// own group. Never loses or duplicates an element. The rules of the bar:
//
//   - a divider is a normal entry (one id per divider, repeatable by suffix);
//   - a chip is placed by its token; naming one of its members places the chip
//     there (an old document keeps its pill);
//   - a fixed element stays in its own group, wherever the document put it;
//   - optional elements (the divider) are never added on their own.
function cleanOrder(source, surface, chips) {
    var name = surface || "bar"
    var table = chips || defaultChips(name)
    var known = knownIds(name)
    var membership = chipMembership(table)
    var taken = {}
    var takenChips = {}
    var names = groups(name)
    var out = {}
    var raw = objectOf(source) || {}
    for (var i = 0; i < names.length; i++) {
        var group = names[i]
        out[group] = []
        var list = Array.isArray(raw[group]) ? raw[group] : []
        for (var j = 0; j < list.length; j++) {
            var entry = list[j]
            if (typeof entry !== "string")
                continue
            if (isChipToken(entry)) {
                var at = chipName(entry)
                if (table[at] && !takenChips[at]) {
                    takenChips[at] = true
                    out[group].push(entry)
                }
                continue
            }
            if (!known[entry] && !Registry.isDivider(entry))
                continue
            if (membership[entry]) {
                var chip = membership[entry]
                if (!takenChips[chip]) {
                    takenChips[chip] = true
                    out[group].push(chipToken(chip))
                }
                continue
            }
            if (taken[entry])
                continue
            var widget = find(entry, name)
            if (widget && widget.fixed && group !== widget.group)
                continue
            taken[entry] = true
            out[group].push(entry)
        }
    }
    var all = widgets(name)
    for (var k = 0; k < all.length; k++) {
        var item = all[k]
        if (item.optional)
            continue
        if (membership[item.id]) {
            var id = membership[item.id]
            if (!takenChips[id]) {
                takenChips[id] = true
                out[item.group].push(chipToken(id))
            }
            taken[item.id] = true
            continue
        }
        if (taken[item.id])
            continue
        taken[item.id] = true
        var home = out[item.group] ? item.group : names[0]
        if (out[home])
            out[home].push(item.id)
    }
    return out
}

function copyOrder(order) {
    var out = {}
    for (var group in order)
        out[group] = order[group].slice()
    return out
}

// --- chips -----------------------------------------------------------------

function isChipToken(entry) {
    return typeof entry === "string" && entry.length > 1 && entry.charAt(0) === CHIP_PREFIX
}

function chipName(token) {
    return isChipToken(token) ? token.slice(CHIP_PREFIX.length) : ""
}

function chipToken(id) {
    return CHIP_PREFIX + id
}

// One chip id per element, or none.
function chipMembership(chips) {
    var out = {}
    var table = objectOf(chips) || {}
    for (var id in table) {
        var entry = objectOf(table[id])
        if (!entry || !Array.isArray(entry.members))
            continue
        for (var i = 0; i < entry.members.length; i++)
            out[entry.members[i]] = id
    }
    return out
}

function defaultChips(surface) {
    var table = DEFAULT_CHIPS[surface || "bar"] || {}
    var out = {}
    for (var id in table)
        out[id] = { members: table[id].members.slice() }
    return out
}

function copyChips(chips) {
    var out = {}
    var table = objectOf(chips)
    if (!table)
        return out
    for (var id in table) {
        var entry = objectOf(table[id])
        if (entry && Array.isArray(entry.members))
            out[id] = { members: entry.members.slice() }
    }
    return out
}

function chipEntry(chips, id) {
    var table = objectOf(chips)
    var entry = table && has(table, id) ? objectOf(table[id]) : null
    return entry && Array.isArray(entry.members) ? entry : null
}

// The chip an element belongs to, or null.
function chipOf(chips, id) {
    var table = objectOf(chips) || {}
    for (var chip in table) {
        var entry = objectOf(table[chip])
        if (entry && Array.isArray(entry.members) && entry.members.indexOf(id) >= 0)
            return chip
    }
    return null
}

// Whether an element may join a chip: known on this surface, not fixed (it
// would leave its own group) and not structural.
function chipMember(id, surface) {
    var widget = find(id, surface)
    return !!widget && !widget.fixed && !widget.optional && !Registry.isDivider(id)
}

function cleanChipMembers(list, surface, used) {
    var out = []
    if (!Array.isArray(list))
        return out
    for (var i = 0; i < list.length; i++) {
        var id = list[i]
        if (typeof id !== "string" || used[id] || !chipMember(id, surface))
            continue
        used[id] = true
        out.push(id)
    }
    return out
}

// The document's chips, checked against the registry: an unknown or fixed
// member drops, an element belongs to one chip at most, and an invalid table
// is the built-in one. A declared empty chip survives so the editor can fill
// it; an old document without `chips` gets the built-in pill.
function cleanChips(raw, surface) {
    var source = objectOf(raw)
    if (!source)
        return defaultChips(surface)
    var out = {}
    var used = {}
    for (var id in source) {
        if (!/^[A-Za-z0-9_-]+$/.test(id))
            continue
        var entry = objectOf(source[id])
        if (!entry)
            continue
        out[id] = { members: cleanChipMembers(entry.members, surface, used) }
    }
    return out
}

// The next free chip id, so a new chip never overwrites one.
function nextChipId(chips) {
    var table = objectOf(chips) || {}
    var n = 1
    while (has(table, "chip-" + n))
        n++
    return "chip-" + n
}

// A new, empty chip at the end of a group.
function newChip(order, chips, group, surface) {
    var table = copyChips(chips)
    var id = nextChipId(table)
    var out = copyOrder(order)
    var names = groups(surface)
    var at = out[group] ? group : names[0]
    table[id] = { members: [] }
    if (out[at])
        out[at].push(chipToken(id))
    return { order: out, chips: table, id: id }
}

// Where a chip token is, or null.
function chipPlace(order, id) {
    for (var group in order) {
        var index = order[group].indexOf(chipToken(id))
        if (index >= 0)
            return { group: group, index: index }
    }
    return null
}

// One chip's members replaced: a new member leaves its old group (and its old
// chip), a removed one returns to the order beside the chip. The input is
// never changed.
function setChipMembers(order, chips, id, members, surface) {
    var table = copyChips(chips)
    var out = copyOrder(order)
    if (!table[id])
        return { order: out, chips: table }
    var wanted = cleanChipMembers(members, surface, {})
    for (var other in table) {
        if (other === id)
            continue
        var kept = []
        for (var i = 0; i < table[other].members.length; i++) {
            if (wanted.indexOf(table[other].members[i]) < 0)
                kept.push(table[other].members[i])
        }
        table[other].members = kept
    }
    var before = table[id].members
    var removed = []
    for (var j = 0; j < before.length; j++) {
        if (wanted.indexOf(before[j]) < 0)
            removed.push(before[j])
    }
    table[id].members = wanted
    for (var group in out) {
        out[group] = out[group].filter(function (entry) {
            return wanted.indexOf(entry) < 0
        })
    }
    var place = chipPlace(out, id)
    if (removed.length > 0) {
        if (place) {
            for (var k = 0; k < removed.length; k++)
                out[place.group].splice(place.index + 1 + k, 0, removed[k])
        } else {
            var names = groups(surface)
            var home = out[names[names.length - 1]] ? names[names.length - 1] : names[0]
            if (out[home])
                out[home] = out[home].concat(removed)
        }
    }
    return { order: out, chips: table }
}

// The chip removed: its members return to the order where it was.
function removeChip(order, chips, id) {
    var table = copyChips(chips)
    var out = copyOrder(order)
    if (!table[id])
        return { order: out, chips: table }
    var members = table[id].members
    var place = chipPlace(out, id)
    delete table[id]
    if (!place)
        return { order: out, chips: table }
    out[place.group].splice(place.index, 1)
    for (var i = 0; i < members.length; i++)
        out[place.group].splice(place.index + i, 0, members[i])
    return { order: out, chips: table }
}

// The next free divider id, so several dividers can share a document.
function nextDividerId(order) {
    var taken = {}
    var source = objectOf(order) || {}
    for (var group in source) {
        for (var i = 0; i < source[group].length; i++) {
            if (Registry.isDivider(source[group][i]))
                taken[source[group][i]] = true
        }
    }
    if (!taken.divider)
        return "divider"
    var n = 2
    while (taken["divider-" + n])
        n++
    return "divider-" + n
}

// A divider at a place of a group (the end by default).
function addDivider(order, group, index, surface) {
    var out = copyOrder(order)
    var names = groups(surface)
    var at = out[group] ? group : names[0]
    if (!out[at])
        return out
    var place = index === undefined ? out[at].length
                                : Math.max(0, Math.min(out[at].length, index))
    out[at].splice(place, 0, nextDividerId(out))
    return out
}

function removeDivider(order, id) {
    var out = copyOrder(order)
    for (var group in out) {
        out[group] = out[group].filter(function (entry) {
            return entry !== id
        })
    }
    return out
}

function cleanMonitors(raw, surface, chips) {
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
            clean.order = cleanOrder(entry.order, surface, chips)
        if (clean.hidden || clean.order)
            out[name] = clean
    }
    return out
}

// One widget's size, style and typography, checked against the registry. The
// default size is the widget's "md" when it has one; no style means the
// widget's own default (for the player, the bar's `mediaStyle` preference).
// An empty font, weight or italic inherits the shell's type.
function cleanSetting(entry, widget) {
    if (!widget)
        return { size: "md", style: "", font: "", weight: "", italic: false }
    var value = objectOf(entry) || {}
    var sizes = widget.sizes || []
    var styles = widget.styles || []
    var size = sizes.indexOf(value.size) >= 0 ? value.size : Registry.defaultSize(widget)
    var style = typeof value.style === "string"
                && (value.style === "" || styles.indexOf(value.style) >= 0) ? value.style : ""
    return { size: size, style: style,
             font: cleanFont(value.font),
             weight: cleanWeight(value.weight),
             italic: value.italic === true }
}

// A family name as typed; "" inherits. Only strings count, and padding around
// the name (a hand-edited document, a copy-paste) is dropped.
function cleanFont(value) {
    return typeof value === "string" ? value.trim() : ""
}

// "" inherits; regular/medium/bold are the only weights, compared without case.
function cleanWeight(value) {
    if (typeof value !== "string")
        return ""
    var name = value.trim().toLowerCase()
    return WEIGHTS.indexOf(name) >= 0 ? name : ""
}

function copyWidgets(widgets) {
    var out = {}
    var values = objectOf(widgets)
    if (!values)
        return out
    for (var id in values) {
        var entry = objectOf(values[id])
        if (entry)
            out[id] = { size: entry.size, style: entry.style,
                        font: entry.font, weight: entry.weight, italic: entry.italic }
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
    if (has(patch, "font"))
        current.font = patch.font
    if (has(patch, "weight"))
        current.weight = patch.weight
    if (has(patch, "italic"))
        current.italic = patch.italic
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
             style: setting.style,
             font: setting.font,
             weight: setting.weight,
             italic: setting.italic }
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
                       size: widget.size, style: widget.style,
                       font: widget.font, weight: widget.weight, italic: widget.italic })
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

function desktopWidgets(doc, monitor, sync) {
    var values = objectOf(doc) ? doc : null
    var shared = values && Array.isArray(values.shared) ? copyDesktopWidgets(values.shared) : null
    if (sync === true && shared !== null)
        return shared
    var monitors = values ? objectOf(values.monitors) : null
    var entry = monitors && monitor ? objectOf(monitors[monitor]) : null
    return entry ? copyDesktopWidgets(entry.widgets) : []
}

// How many widgets the document places on every monitor: the shared list when
// it has one, otherwise the sum of the per-monitor documents.
function desktopCount(textOrDoc, sync) {
    var doc = sanitize(textOrDoc, "desktop")
    if (sync === true && Array.isArray(doc.shared))
        return doc.shared.length
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
               style: setting.style,
               font: setting.font,
               weight: setting.weight,
               italic: setting.italic })
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
        var current = { size: out[i].size, style: out[i].style,
                        font: out[i].font, weight: out[i].weight, italic: out[i].italic }
        if (has(patch, "size"))
            current.size = patch.size
        if (has(patch, "style"))
            current.style = patch.style
        if (has(patch, "font"))
            current.font = patch.font
        if (has(patch, "weight"))
            current.weight = patch.weight
        if (has(patch, "italic"))
            current.italic = patch.italic
        var setting = cleanSetting(current, widget)
        out[i].size = setting.size
        out[i].style = setting.style
        out[i].font = setting.font
        out[i].weight = setting.weight
        out[i].italic = setting.italic
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
    if (isDesktop(name)) {
        var desktop = { monitors: cleanDesktopMonitors(raw.monitors) }
        if (Array.isArray(raw.shared))
            desktop.shared = cleanDesktopWidgets(raw.shared)
        return desktop
    }
    if (isFlat(name)) {
        return {
            order: cleanFlatList(raw.order, name),
            hidden: Array.isArray(raw.hidden) ? cleanList(raw.hidden, knownIds(name)) : defaultHidden(name),
            widgets: cleanWidgets(raw.widgets, name)
        }
    }
    var chips = cleanChips(raw.chips, name)
    var out = {}
    out.order = cleanOrder(raw.order, name, chips)
    out.hidden = Array.isArray(raw.hidden) ? cleanList(raw.hidden, knownIds(name)) : defaultHidden(name)
    out.chips = chips
    out.density = raw.density === "compact" ? "compact" : "comfortable"
    out.hideFullscreen = !(raw.hideFullscreen === false || raw.hideFullscreen === "false")
    out.monitors = cleanMonitors(raw.monitors, name, chips)
    return out
}

// What one monitor draws: the global document with that monitor's order and
// hidden list substituted when it has them. `base` is the document an empty
// preference falls back to (another surface's default, later). A flat surface
// has no per-monitor overrides. With `sync` on, the desktop's shared list wins;
// a document without one (written before the preference existed) still reads
// its per-monitor entry.
function effective(layout, monitor, base, surface, sync) {
    var name = surface || "bar"
    var source = layout === undefined || layout === null || layout === "" ? base : layout
    var doc = sanitize(source, name)
    if (isDesktop(name))
        return { widgets: desktopWidgets(doc, monitor, sync) }
    if (isFlat(name))
        return { order: doc.order.slice(), hidden: doc.hidden.slice(), widgets: copyWidgets(doc.widgets) }
    var entry = monitor && doc.monitors[monitor] ? doc.monitors[monitor] : null
    return {
        order: copyOrder(entry && entry.order ? entry.order : doc.order),
        hidden: (entry && entry.hidden ? entry.hidden : doc.hidden).slice(),
        chips: copyChips(doc.chips),
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

// The fixed elements: their group is part of the bar's shape, not a choice.
function isFixed(id, surface) {
    var widget = find(id, surface)
    return !!(widget && widget.fixed)
}

// `divider`, `divider-2`…: structural entries a document may repeat.
function isDivider(id) {
    return Registry.isDivider(id)
}

function homeGroup(id, surface) {
    var widget = find(id, surface)
    var names = groups(surface)
    return widget && widget.group ? widget.group : (names.length > 0 ? names[0] : "")
}

// One visual entry per order entry: a chip brings its visible members inside
// one pill, a divider marks the line it draws, and anything else is one
// element. An empty chip (every member hidden) draws nothing at all.
function entries(orderGroup, hidden, surface, chips) {
    var table = chips || defaultChips(surface)
    var list = visible(orderGroup, hidden)
    var out = []
    var hiddenIds = hidden || []
    for (var i = 0; i < list.length; i++) {
        var id = list[i]
        if (isChipToken(id)) {
            var chip = chipEntry(table, chipName(id))
            if (!chip)
                continue
            var ids = visible(chip.members, hiddenIds)
            if (ids.length > 0)
                out.push({ chip: chipName(id), ids: ids })
        } else if (Registry.isDivider(id)) {
            out.push({ id: id, divider: true })
        } else {
            out.push({ id: id })
        }
    }
    return out
}

// One order entry moved to a group and a place in it; a new order, never the
// one passed in. A fixed element may only be reordered inside its own group;
// a chip moves by its token (`"@connections"`), and an element inside a chip
// is moved by changing the chip's members, not by this helper. Out-of-range
// places are clamped. A flat surface passes its list and an index instead.
function moveTo(order, id, group, index, surface) {
    if (Array.isArray(order)) {
        var flat = order.slice()
        var from = flat.indexOf(id)
        if (from < 0)
            return flat
        var place = index === undefined ? flat.length : index
        if (from < place)
            place -= 1
        place = Math.max(0, Math.min(flat.length - 1, place))
        flat.splice(from, 1)
        flat.splice(place, 0, id)
        return flat
    }
    var out = copyOrder(order)
    if (!out[group])
        return out
    if (!isChipToken(id) && isFixed(id, surface) && group !== homeGroup(id, surface))
        return out
    var at = null
    for (var name in out) {
        var index2 = out[name].indexOf(id)
        if (index2 >= 0) {
            at = { group: name, index: index2 }
            break
        }
    }
    if (!at)
        return out
    var target = index === undefined ? out[group].length : index
    out[at.group].splice(at.index, 1)
    if (at.group === group && at.index < target)
        target -= 1
    target = Math.max(0, Math.min(out[group].length, target))
    out[group].splice(target, 0, id)
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
// surface writes its order, hidden list and per-widget settings. A synced
// desktop writes the one shared list, whichever monitor asked.
function write(text, monitor, patch, surface, sync) {
    var name = surface || "bar"
    var before = sanitize(text, name)
    var doc = sanitize(text, name)
    var values = objectOf(patch) || {}
    if (isDesktop(name)) {
        if (has(values, "widgets")) {
            var placed = cleanDesktopWidgets(copyDesktopWidgets(values.widgets))
            if (sync === true) {
                doc.shared = placed
            } else if (monitor) {
                if (placed.length > 0)
                    doc.monitors[monitor] = { widgets: placed }
                else
                    delete doc.monitors[monitor]
            }
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
        // Chips belong to the whole bar, not to one monitor.
        if (has(values, "chips"))
            doc.chips = copyChips(values.chips)
        if (entry.order || entry.hidden)
            doc.monitors[monitor] = entry
    } else {
        if (values.order)
            doc.order = copyOrder(values.order)
        if (values.hidden)
            doc.hidden = values.hidden.slice()
        if (has(values, "chips"))
            doc.chips = copyChips(values.chips)
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
