// The Fonts page's lists: one row per installed family, theme or pack.
//
// A stored value the machine no longer has stays selectable, first in the
// list, so opening the page never shows an empty box and saving the page never
// silently replaces the user's choice.
.pragma library

function options(names, current, compare) {
    // No prototype: a family literally named "constructor" is still a family.
    var seen = Object.create(null)
    var rows = []
    var list = names || []
    for (var i = 0; i < list.length; i++) {
        var name = String(list[i] === undefined || list[i] === null ? "" : list[i]).trim()
        if (name === "" || seen[name])
            continue
        seen[name] = true
        rows.push({ key: name, label: name })
    }
    rows.sort(compare || function (a, b) {
        return a.key.localeCompare(b.key)
    })
    if (current && !seen[current])
        rows.unshift({ key: current, label: current })
    return rows
}
