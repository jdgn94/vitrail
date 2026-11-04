.pragma library

// The settings index: every category in shell/main.qml and every tab of its
// page, as { category, tab, key, label, terms }. `key` names the translated
// label (the settings window shows `t(key)`, so a result reads in the user's
// language); `label` is the English text used for matching; `terms` holds the
// other words a person might type for that page. `tab` is "" on a category
// that has no subcategories.
//
// A page's own list of tabs lives in shell/pages/<Page>.qml; adding a tab
// there and here keeps the search honest (tst_search.qml checks every entry
// the other way round, not the page source, so update this list with it).

var index = [
    // Look
    { category: "appearance", tab: "", key: "nav.appearance", label: "Appearance",
      terms: ["look", "category"] },
    { category: "appearance", tab: "theme", key: "section.theme", label: "Theme",
      terms: ["mode", "dark", "light", "auto"] },
    { category: "appearance", tab: "surface", key: "section.surface", label: "Surface",
      terms: ["glass", "solid", "opacity", "blur"] },

    { category: "fonts", tab: "", key: "section.fonts", label: "Fonts & icons",
      terms: ["fonts", "icons", "type", "typography"] },
    { category: "fonts", tab: "text", key: "fonts.tab.text", label: "Text",
      terms: ["font", "family", "size", "typography"] },
    { category: "fonts", tab: "icons", key: "fonts.tab.icons", label: "Icons",
      terms: ["icon", "pack", "symbols"] },
    { category: "fonts", tab: "cursor", key: "fonts.tab.cursor", label: "Cursor",
      terms: ["pointer", "mouse"] },

    { category: "wallpaper", tab: "", key: "section.wallpaper", label: "Wallpaper",
      terms: ["background", "image", "picture"] },

    { category: "colors", tab: "", key: "section.colors", label: "Colors",
      terms: ["palette", "scheme", "contrast", "color"] },

    { category: "design", tab: "", key: "section.design", label: "Design",
      terms: ["shape", "surface", "share"] },
    { category: "design", tab: "shape", key: "design.tab.shapeType", label: "Shape and type",
      terms: ["shape", "corners", "radius", "type"] },
    { category: "design", tab: "surface", key: "section.surface", label: "Surface",
      terms: ["glass", "solid"] },
    { category: "design", tab: "share", key: "design.section.share", label: "Share",
      terms: ["export", "config", "share"] },

    // Desktop
    { category: "bar", tab: "", key: "section.bar", label: "Bar",
      terms: ["panel", "toolbar"] },
    { category: "bar", tab: "layout", key: "bar.section.layout", label: "Position and style",
      terms: ["bar", "position", "edge", "style"] },
    { category: "bar", tab: "frame", key: "bar.tab.framePanels", label: "Frame and panels",
      terms: ["frame", "panel", "islands", "floating"] },
    { category: "bar", tab: "notifications", key: "bar.section.notifications", label: "Notifications",
      terms: ["notification", "dnd", "tray"] },
    { category: "bar", tab: "osd", key: "bar.section.osd", label: "On-screen display",
      terms: ["osd", "volume", "brightness"] },
    { category: "bar", tab: "capture", key: "bar.section.capture", label: "Capture",
      terms: ["screenshot", "recording", "capture"] },

    { category: "windows", tab: "", key: "section.windows", label: "Windows",
      terms: ["window", "tiling"] },
    { category: "windows", tab: "border", key: "windows.tabBorder", label: "Border",
      terms: ["border", "width", "window"] },
    { category: "windows", tab: "opacity", key: "windows.tabOpacity", label: "Opacity",
      terms: ["opacity", "transparent"] },
    { category: "windows", tab: "layout", key: "windows.tabLayout", label: "Layout",
      terms: ["layout", "columns", "grid"] },

    { category: "monitors", tab: "", key: "section.monitors", label: "Monitors",
      terms: ["monitor", "display", "screen", "position", "scale"] },

    { category: "terminal", tab: "", key: "section.terminal", label: "Terminal",
      terms: ["shell", "kitty"] },
    { category: "terminal", tab: "tabs", key: "terminal.section.tabs", label: "Tabs",
      terms: ["terminal", "shell", "opacity"] },
    { category: "terminal", tab: "look", key: "terminal.section.look", label: "Text and colors",
      terms: ["terminal", "font", "padding", "color"] },

    { category: "launcher", tab: "", key: "section.launcher", label: "Launcher",
      terms: ["search", "apps"] },
    { category: "launcher", tab: "general", key: "launcher.section.general", label: "General",
      terms: ["launcher", "apps", "history", "clipboard"] },
    { category: "launcher", tab: "web", key: "launcher.section.web", label: "Web search",
      terms: ["launcher", "web", "search", "bangs"] },

    // System
    { category: "input", tab: "", key: "section.input", label: "Input",
      terms: ["keyboard", "mouse"] },
    { category: "input", tab: "keyboard", key: "input.keyboard", label: "Keyboard",
      terms: ["repeat", "layout", "numlock"] },
    { category: "input", tab: "mouse", key: "input.mouse", label: "Mouse",
      terms: ["pointer", "acceleration", "scroll"] },

    { category: "sound", tab: "", key: "section.sound", label: "Sound",
      terms: ["audio", "volume"] },
    { category: "sound", tab: "output", key: "sound.tab.output", label: "Output",
      terms: ["sound", "audio", "volume", "speaker"] },
    { category: "sound", tab: "input", key: "sound.tab.input", label: "Input",
      terms: ["microphone", "mic"] },

    { category: "language", tab: "", key: "section.language", label: "Language",
      terms: ["locale", "translation"] },

    { category: "datetime", tab: "", key: "section.datetime", label: "Date & time",
      terms: ["date", "time", "timezone"] },
    { category: "datetime", tab: "zone", key: "datetime.zone", label: "Time zone",
      terms: ["timezone", "clock", "zone"] },
    { category: "datetime", tab: "clock", key: "datetime.clock", label: "Clock",
      terms: ["clock", "time", "24h", "format"] },
    { category: "datetime", tab: "weather", key: "weather.title", label: "Weather",
      terms: ["weather", "city", "units", "temperature", "forecast"] },

    { category: "connection", tab: "", key: "section.connection", label: "Connection",
      terms: ["network", "wifi", "vpn", "bluetooth"] },
    { category: "connection", tab: "internet", key: "connection.tab.internet", label: "Internet",
      terms: ["network", "ethernet", "wifi"] },
    { category: "connection", tab: "vpn", key: "network.vpn", label: "VPN",
      terms: ["tunnel", "network"] },
    { category: "connection", tab: "bluetooth", key: "connection.bluetooth", label: "Bluetooth",
      terms: ["devices", "network"] },

    { category: "plugins", tab: "", key: "section.plugins", label: "Plugins",
      terms: ["extension", "addon"] },
    { category: "plugins", tab: "media", key: "plugins.section.media", label: "Media player",
      terms: ["media", "music", "player"] },
    { category: "plugins", tab: "installed", key: "plugins.section.installed", label: "Installed",
      terms: ["plugin", "extension"] }
]

var LIMIT = 12

// Lower case and strip the diacritics, so "Cúrsor" and "cursor" are the same
// word. String.normalize covers the composed forms; the map is the fallback
// for an engine without it.
var ACCENTS = {
    "á": "a", "à": "a", "ä": "a", "â": "a", "ã": "a", "å": "a",
    "é": "e", "è": "e", "ë": "e", "ê": "e",
    "í": "i", "ì": "i", "ï": "i", "î": "i",
    "ó": "o", "ò": "o", "ö": "o", "ô": "o", "õ": "o",
    "ú": "u", "ù": "u", "ü": "u", "û": "u",
    "ç": "c", "ñ": "n", "ý": "y", "ÿ": "y"
}

function fold(text) {
    var value = String(text === undefined || text === null ? "" : text).toLowerCase()
    if (value.normalize)
        return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    return value.replace(/[^\x00-\x7f]/g, function (letter) {
        return ACCENTS[letter] || letter
    })
}

function words(text) {
    return fold(text).split(/\s+/).filter(function (word) {
        return word !== ""
    })
}

// 0 exact label, 1 label prefix, 2 a word of the label, 3 inside the label,
// 4 one of the extra terms. -1: this word is not here.
function rankWord(word, label, terms) {
    if (label === word)
        return 0
    if (label.indexOf(word) === 0)
        return 1
    var parts = label.split(/\s+/)
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].indexOf(word) === 0)
            return 2
    }
    if (label.indexOf(word) >= 0)
        return 3
    for (var j = 0; j < terms.length; j++) {
        if (terms[j].indexOf(word) >= 0)
            return 4
    }
    return -1
}

// The entries a query reaches, best first: the words are folded, every word
// must appear somewhere in the entry and the list stops at LIMIT.
function matches(query) {
    var needles = words(query)
    if (needles.length === 0)
        return []
    var found = []
    for (var i = 0; i < index.length; i++) {
        var entry = index[i]
        var label = fold(entry.label)
        var terms = words(entry.label + " " + entry.terms.join(" "))
        var score = 0
        var matched = true
        for (var w = 0; w < needles.length; w++) {
            var rank = rankWord(needles[w], label, terms)
            if (rank < 0) {
                matched = false
                break
            }
            score += rank
        }
        if (matched)
            found.push({ entry: entry, score: score, order: i })
    }
    found.sort(function (a, b) {
        return a.score === b.score ? a.order - b.order : a.score - b.score
    })
    return found.slice(0, LIMIT).map(function (hit) {
        return {
            category: hit.entry.category,
            tab: hit.entry.tab,
            label: hit.entry.label,
            key: hit.entry.key
        }
    })
}
