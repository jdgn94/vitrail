// The wallpaper mode of the launcher: the library's pictures and the effects,
// as one filterable list. The pictures come from `find` (Commands.wallpapers);
// this module only reads its output and matches the query.
.pragma library

.import "../../kit/effects.js" as Effects
.import "search.js" as Search

var WALLPAPER = /\.(png|jpe?g|webp|bmp|svg|mp4|webm|mkv|mov|m4v|avi)$/i
var VIDEO = /\.(mp4|webm|mkv|mov|m4v|avi)$/i
var SVG = /\.svg$/i

function kindOf(path) {
    if (SVG.test(path))
        return "svg"
    if (VIDEO.test(path))
        return "video"
    return "image"
}

function nameOf(path) {
    var text = String(path || "")
    return text.slice(text.lastIndexOf("/") + 1)
}

// "path" lines -> [{ path, name, kind }], duplicates and other files aside,
// by name.
function parse(output) {
    var seen = {}
    var out = []
    String(output || "").split("\n").forEach(function (line) {
        var path = line.trim()
        if (path === "" || !WALLPAPER.test(path) || seen[path])
            return
        seen[path] = true
        out.push({ path: path, name: nameOf(path), kind: kindOf(path) })
    })
    return out.sort(function (a, b) {
        return a.name.toLowerCase() < b.name.toLowerCase() ? -1
             : a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0
    })
}

// What the text keeps: the effects (by name or by its translation) and the
// pictures (by file name). No text keeps everything.
function filter(files, text, t) {
    var query = String(text || "").trim()
    if (query === "")
        return { effects: Effects.NAMES.slice(), wallpapers: files.slice() }
    var label = function (name) {
        return t ? String(t("wallpaper.effect." + name)) : name
    }
    return {
        effects: Effects.NAMES.filter(function (name) {
            return Search.score(query, name) > 0 || Search.score(query, label(name)) > 0
        }),
        wallpapers: files.filter(function (file) {
            return Search.score(query, file.name) > 0
        })
    }
}
