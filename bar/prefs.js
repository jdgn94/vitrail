// The bar's view of the preference files: one INI file per area, listed by
// vitrail/prefs.map, merged into one object so the rest of the bar keeps
// reading `shell.prefs.<key>`.
.pragma library

// The file names of a prefs.map ("<file> <key>" per line), in order.
function files(mapText) {
    var names = []
    var lines = mapText.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === "" || line[0] === "#")
            continue
        var name = line.split(/\s+/)[0]
        if (names.indexOf(name) < 0)
            names.push(name)
    }
    return names
}

// A value the settings window wrote through QSettings: one with commas, quotes
// or backslashes (a JSON document) is stored in double quotes with backslash
// escapes. Anything not wrapped in quotes is returned as is.
function unquote(value) {
    if (value.length < 2 || value[0] !== '"' || value[value.length - 1] !== '"')
        return value
    var named = { n: "\n", t: "\t", r: "\r", a: "\x07", b: "\b", f: "\f", v: "\v" }
    return value.slice(1, -1).replace(/\\(x[0-9A-Fa-f]+|[\s\S])/g, function (match, code) {
        if (code.length > 1)
            return String.fromCharCode(parseInt(code.slice(1), 16))
        return named[code] || code
    })
}

// The key=value pairs of one file, whatever their section.
function parse(text) {
    var out = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        var at = line.indexOf("=")
        if (at > 0 && line[0] !== "[" && line[0] !== "#" && line[0] !== ";")
            out[line.slice(0, at).trim()] = unquote(line.slice(at + 1).trim())
    }
    return out
}

// The parsed files (by name) as one object, in the order of `names`.
function merge(parts, names) {
    var out = {}
    for (var i = 0; i < names.length; i++) {
        var part = parts[names[i]] || {}
        for (var key in part)
            out[key] = part[key]
    }
    return out
}
