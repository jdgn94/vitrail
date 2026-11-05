// The keyboard chip, its switcher and the language the bar's on-screen
// keyboard starts in. The bar reads `hyprctl devices -j`; everything here is
// pure so tests/qml/tst_keyboard.qml can check it without a compositor.
.pragma library

var LABELS = {
    us: "English (US)",
    gb: "English (UK)",
    es: "Español",
    latam: "Latinoamérica",
    br: "Português (BR)",
    pt: "Português (PT)",
    de: "Deutsch",
    fr: "Français",
    it: "Italiano",
    ru: "Русский"
}

var CODES = {
    us: "US",
    gb: "EN",
    es: "ES",
    latam: "LATAM",
    br: "BR",
    pt: "PT",
    de: "DE",
    fr: "FR",
    it: "IT",
    ru: "RU"
}

var LANGUAGES_OF = {
    us: "en",
    gb: "en",
    es: "es",
    latam: "es",
    de: "de",
    fr: "fr",
    it: "it",
    br: "pt",
    pt: "pt",
    ru: "en"
}

// "grp:alt_shift_toggle" -> "Alt+Shift"; the first option wins.
function humaniseSwitch(options) {
    var option = String(options || "").split(",")[0].trim()
    if (option === "")
        return ""
    option = option.replace(/^grp:/, "").replace(/_toggle$/, "")
    var names = {
        alt: "Alt", shift: "Shift", ctrl: "Ctrl", control: "Ctrl",
        super: "Super", meta: "Super", win: "Super", mod: "Super",
        caps: "Caps Lock", space: "Space"
    }
    var parts = option.split("_").map(function (part) {
        return names[part] || (part.charAt(0).toUpperCase() + part.slice(1))
    })
    return parts.join("+")
}

function label(layout) {
    return LABELS[layout] || String(layout || "").toUpperCase()
}

function code(layout) {
    return CODES[layout] || String(layout || "").toUpperCase()
}

function language(layout) {
    return LANGUAGES_OF[layout] || "en"
}

// The keyboards of `hyprctl devices -j`, the main one first; empty on a bad
// document or without a compositor.
function parse(text) {
    var document
    try {
        document = JSON.parse(String(text || ""))
    } catch (error) {
        return []
    }
    var list = (document && document.keyboards) || []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var keyboard = list[i]
        if (!keyboard || String(keyboard.layout || "") === "")
            continue
        out.push({
            name: String(keyboard.name || ""),
            layout: String(keyboard.layout || ""),
            variant: String(keyboard.variant || ""),
            options: String(keyboard.options || ""),
            activeIndex: Number(keyboard.active_layout_index) || 0,
            activeKeymap: String(keyboard.active_keymap || ""),
            main: keyboard.main === true
        })
    }
    out.sort(function (left, right) {
        return (right.main ? 1 : 0) - (left.main ? 1 : 0)
    })
    return out
}

function mainKeyboard(devices) {
    for (var i = 0; i < (devices || []).length; i++) {
        if (devices[i].main)
            return devices[i]
    }
    return (devices || []).length > 0 ? devices[0] : null
}

function split(value, fallback) {
    var parts = String(value || "").split(",")
    return parts.length > 0 ? parts : [fallback || ""]
}

function codes(device) {
    if (!device)
        return []
    return split(device.layout, "").map(function (part) {
        return part.trim()
    }).filter(function (part) {
        return part !== ""
    })
}

function variants(device) {
    if (!device)
        return []
    return split(device.variant, "").map(function (part) {
        return part.trim()
    })
}

function activeCode(devices) {
    var main = mainKeyboard(devices)
    var list = codes(main)
    return list[main ? Math.max(0, Math.min(main.activeIndex, list.length - 1)) : 0] || ""
}

// The chip is only the abbreviation of the active layout, never a glyph or the
// whole list.
function chipText(devices) {
    var active = activeCode(devices)
    return active !== "" ? code(active) : "KB"
}

function mainSwitch(devices) {
    var main = mainKeyboard(devices)
    return main ? humaniseSwitch(main.options) : ""
}

// One line per distinct keyboard configuration, the live layouts of each.
function tooltip(devices) {
    var seen = ({})
    var parts = []
    for (var i = 0; i < (devices || []).length; i++) {
        var device = devices[i]
        var key = device.layout + "|" + device.variant + "|" + device.options
        if (seen[key])
            continue
        seen[key] = true
        var names = codes(device).map(code).join(" ")
        if (names !== "")
            parts.push((device.name || "keyboard") + " · " + names)
    }
    return parts.join("; ")
}

// The switcher's rows: every layout once, with the keyboards that have it and
// the combination that changes it.
function layoutRows(devices) {
    var rows = []
    var at = ({})
    for (var i = 0; i < (devices || []).length; i++) {
        var device = devices[i]
        var list = codes(device)
        var extra = variants(device)
        var combination = humaniseSwitch(device.options)
        for (var j = 0; j < list.length; j++) {
            var layout = list[j]
            var row = at[layout]
            if (!row) {
                row = {
                    key: layout, title: label(layout), active: false,
                    devices: [], combination: combination
                }
                at[layout] = row
                rows.push(row)
            }
            if (row.devices.indexOf(device.name) < 0)
                row.devices.push(device.name)
            if (device.activeIndex === j)
                row.active = true
            if (row.combination === "")
                row.combination = combination
        }
    }
    for (var k = 0; k < rows.length; k++) {
        var names = rows[k].devices
        var more = names.length > 1 ? " +" + (names.length - 1) : ""
        rows[k].subtitle = (names.length > 0 ? names[0] + more : "")
                            + (rows[k].combination !== "" ? " · " + rows[k].combination : "")
    }
    return rows
}

// The layout and variant lists with `layout` first, so choosing it switches
// without throwing the other layouts away.
function orderFor(devices, layout) {
    var main = mainKeyboard(devices)
    var list = codes(main)
    var extra = variants(main)
    var at = list.indexOf(layout)
    if (at < 0)
        return { layout: String(layout || ""), variant: "" }
    var ordered = [list[at]]
    var orderedVariants = [extra[at] || ""]
    for (var i = 0; i < list.length; i++) {
        if (i === at)
            continue
        ordered.push(list[i])
        orderedVariants.push(extra[i] || "")
    }
    return { layout: ordered.join(","), variant: orderedVariants.join(",") }
}

function lua(text) {
    return String(text || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
}

// Hyprland 0.56's Lua config applies the layout live through `hl.config`; the
// legacy `keyword` path is refused with a non-legacy parser.
function switchCommand(layout, variant) {
    return ["hyprctl", "eval",
            'hl.config({input={kb_layout="' + lua(layout) + '", kb_variant="' + lua(variant) + '"}})']
}
