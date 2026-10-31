// What the user typed: its mode (prefix or bang), web engines and bangs,
// URL and math detection. Pure, no QML types.
.pragma library

// Modes after the mixed one, in the order Tab cycles through them.
var MODES = ["web", "calc", "run", "files", "windows", "actions", "clipboard"]
var PREFIXES = { web: "?", calc: "=", run: ">", files: "/", windows: "@", actions: ":", clipboard: ";" }

// Search engines for the `?` mode. %s is the encoded query.
var ENGINES = {
    duckduckgo: { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    google: { name: "Google", url: "https://www.google.com/search?q=%s" },
    brave: { name: "Brave", url: "https://search.brave.com/search?q=%s" },
    startpage: { name: "Startpage", url: "https://www.startpage.com/do/search?q=%s" }
}
var DEFAULT_ENGINE = "duckduckgo"

var BUILTIN_BANGS = [
    { key: "g", name: "Google", url: "https://www.google.com/search?q=%s" },
    { key: "ddg", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    { key: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query=%s" },
    { key: "gh", name: "GitHub", url: "https://github.com/search?q=%s" },
    { key: "aur", name: "AUR", url: "https://aur.archlinux.org/packages?K=%s" },
    { key: "aw", name: "ArchWiki", url: "https://wiki.archlinux.org/index.php?search=%s" },
    { key: "w", name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Special:Search?search=%s" }
]

// Sites that make "word.tld" a link and not a file name. Not "py", "sh", "rs":
// those are source files.
var TLDS = ["com", "net", "org", "io", "dev", "app", "co", "edu", "gov", "info", "me", "ai", "xyz", "tv", "gg",
            "es", "de", "fr", "it", "pt", "uk", "nl", "eu", "mx", "ar", "cl", "us", "ca", "au", "br"]

function engineUrl(key) {
    return (ENGINES[key] || ENGINES[DEFAULT_ENGINE]).url
}

function engineName(key) {
    return (ENGINES[key] || ENGINES[DEFAULT_ENGINE]).name
}

function searchUrl(template, text) {
    return template.replace("%s", encodeURIComponent(text))
}

// --- user bangs ------------------------------------------------------------
// Stored in launcher.ini as `key*name*url` entries joined by `|`. Each field
// is percent-encoded, so no separator, comma or semicolon can appear in it.

function encodeField(text) {
    return encodeURIComponent(text).replace(/\*/g, "%2A")
}

function serializeBangs(list) {
    return list.map(function (bang) {
        return [bang.key, bang.name, bang.url].map(encodeField).join("*")
    }).join("|")
}

function parseBangs(text) {
    var out = []
    String(text || "").split("|").forEach(function (entry) {
        var fields = entry.split("*")
        if (fields.length !== 3)
            return
        try {
            var bang = { key: decodeURIComponent(fields[0]), name: decodeURIComponent(fields[1]),
                         url: decodeURIComponent(fields[2]) }
            if (bang.key && bang.name && bang.url.indexOf("%s") >= 0)
                out.push(bang)
        } catch (error) {
        }
    })
    return out
}

// Built-in bangs, with the user's own added; a user key replaces a built-in one.
function bangs(stored) {
    var user = parseBangs(stored)
    var taken = {}
    user.forEach(function (bang) { taken[bang.key] = true })
    return BUILTIN_BANGS.filter(function (bang) { return !taken[bang.key] }).concat(user)
}

// --- parsing ---------------------------------------------------------------

function modeOfPrefix(char) {
    for (var mode in PREFIXES) {
        if (PREFIXES[mode] === char)
            return mode
    }
    return ""
}

// -> { mode, text, bang }. opts: { enabled: [modes], bangs: [bang] }.
function parse(raw, opts) {
    var text = String(raw || "")
    var enabled = (opts && opts.enabled) || MODES
    var list = (opts && opts.bangs) || BUILTIN_BANGS
    var mode = modeOfPrefix(text.charAt(0))
    if (mode && enabled.indexOf(mode) >= 0)
        return { mode: mode, text: text.slice(1).trim(), bang: null }
    var found = /^!(\S+)(?:\s+(.*))?$/.exec(text)
    if (found) {
        for (var i = 0; i < list.length; i++) {
            if (list[i].key === found[1])
                return { mode: "web", text: (found[2] || "").trim(), bang: list[i] }
        }
    }
    return { mode: "all", text: text, bang: null }
}

// The text with its mode replaced by another's prefix ("all" has none).
function withMode(raw, mode) {
    var text = String(raw || "")
    var rest = modeOfPrefix(text.charAt(0)) ? text.slice(1) : text
    return (PREFIXES[mode] || "") + rest
}

// Tab: the next (or, with -1, the previous) enabled mode, mixed one included.
function cycle(raw, enabled, delta) {
    var order = ["all"].concat(MODES.filter(function (mode) { return enabled.indexOf(mode) >= 0 }))
    var current = parse(raw, { enabled: enabled }).mode
    var at = Math.max(0, order.indexOf(current))
    var next = order[((at + delta) % order.length + order.length) % order.length]
    return withMode(raw, next)
}

// --- URL and math ----------------------------------------------------------

// "https://…" for anything that opens as a link, or "".
function urlOf(raw) {
    var text = String(raw || "").trim()
    if (!text || /\s/.test(text))
        return ""
    if (/^https?:\/\/\S+$/i.test(text))
        return text
    if (/^(localhost|(\d{1,3}\.){3}\d{1,3})(:\d+)?(\/\S*)?$/.test(text))
        return "http://" + text
    var host = /^((?:[a-z0-9-]+\.)+)([a-z]{2,})(?::\d+)?(?:[\/?#]\S*)?$/i.exec(text)
    if (host && (/^www\./i.test(text) || TLDS.indexOf(host[2].toLowerCase()) >= 0))
        return "https://" + text
    return ""
}

// Something qalc could evaluate: starts like a number and has an operator or
// a "to" / "in" conversion. "7zip" and "1password" are names.
function looksLikeMath(raw) {
    var text = String(raw || "").trim()
    if (!/^[\d(.\-+]/.test(text) || !/\d/.test(text))
        return false
    return /[+*\/^%()]|\d\s*-\s*[\d(]|\s(to|in)\s/.test(text)
}
