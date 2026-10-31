// Desktop entries as launcher items: visibility, main category, tabs.
.pragma library

// The tabs, in order. `match` lists the freedesktop main categories that
// belong to each, `label` is an i18n key. The first tab that matches wins, so
// Settings (usually also System) comes before System.
var CATEGORIES = [
    { key: "settings", match: ["Settings"] },
    { key: "game", match: ["Game"] },
    { key: "development", match: ["Development"] },
    { key: "graphics", match: ["Graphics"] },
    { key: "multimedia", match: ["AudioVideo", "Audio", "Video"] },
    { key: "office", match: ["Office"] },
    { key: "education", match: ["Education"] },
    { key: "science", match: ["Science"] },
    { key: "internet", match: ["Network"] },
    { key: "system", match: ["System"] },
    { key: "utility", match: ["Utility"] },
    { key: "other", match: [] }
]
// The tab order: Multimedia, Development, … (alphabetical by what the user
// reads is not stable across languages), "other" last.
var TAB_ORDER = ["multimedia", "development", "education", "game", "graphics", "internet", "office", "science",
                 "settings", "system", "utility", "other"]

function categoryOf(categories) {
    var have = categories || []
    for (var i = 0; i < CATEGORIES.length; i++) {
        for (var j = 0; j < CATEGORIES[i].match.length; j++) {
            if (have.indexOf(CATEGORIES[i].match[j]) >= 0)
                return CATEGORIES[i].key
        }
    }
    return "other"
}

// The program in an Exec line: after `env` and VAR=value words, no path.
function execName(line) {
    var words = String(line || "").match(/"[^"]*"|\S+/g) || []
    for (var i = 0; i < words.length; i++) {
        var word = words[i].replace(/^"|"$/g, "")
        if (word === "env" || /^\w+=/.test(word))
            continue
        return word.slice(word.lastIndexOf("/") + 1)
    }
    return ""
}

// A plain item from a DesktopEntry (or anything with the same fields). `entry`
// stays on the item: it is what runs.
function toItem(entry) {
    var exec = execName(entry.execString)
    var keywords = (entry.keywords || []).join(" ")
    var fields = [{ text: entry.name, weight: 1 }]
    if (entry.genericName)
        fields.push({ text: entry.genericName, weight: 0.8 })
    if (keywords)
        fields.push({ text: keywords, weight: 0.7 })
    if (exec)
        fields.push({ text: exec, weight: 0.6 })
    if (entry.comment)
        fields.push({ text: entry.comment, weight: 0.4 })
    return {
        id: entry.id, group: "apps", name: entry.name, genericName: entry.genericName || "",
        comment: entry.comment || "", icon: entry.icon || "", exec: exec,
        category: categoryOf(entry.categories), actions: entry.actions || [], entry: entry, fields: fields
    }
}

// The visible, sorted items of every entry that is not hidden.
function items(entries, hidden) {
    var out = []
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        if (!entry.noDisplay && hidden.indexOf(entry.id) < 0)
            out.push(toItem(entry))
    }
    out.sort(function (a, b) {
        return a.name.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
               < b.name.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase() ? -1 : 1
    })
    return out
}

// { key, label } for "all" and each category with apps in it.
function tabs(list) {
    var present = {}
    list.forEach(function (item) { present[item.category] = true })
    var out = [{ key: "all", label: "launcher.cat.all" }]
    TAB_ORDER.forEach(function (key) {
        if (present[key])
            out.push({ key: key, label: "launcher.cat." + key })
    })
    return out
}

function inCategory(list, key) {
    return key === "all" ? list : list.filter(function (item) { return item.category === key })
}
