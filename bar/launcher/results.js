// Results as sections with headers, and moving the selection through them.
.pragma library

// How groups are ordered by default. `label` is launcher.group.<name>.
var GROUPS = ["apps", "actions", "windows", "web", "calc", "files", "run", "clipboard"]

// Groups the results into sections in `order`, each capped by `caps[group]`.
// -> { rows: [{ header, group } | { result, index }], list: [result] }.
// `plain` leaves the headers out (a mode that lists one kind of thing).
function sections(results, order, caps, plain) {
    var rows = []
    var list = []
    order.forEach(function (group) {
        var mine = results.filter(function (result) { return result.group === group })
        if (caps && caps[group])
            mine = mine.slice(0, caps[group])
        if (mine.length === 0)
            return
        if (!plain)
            rows.push({ header: true, group: group })
        mine.forEach(function (result) {
            rows.push({ result: result, index: list.length })
            list.push(result)
        })
    })
    return { rows: rows, list: list }
}

function clamp(index, count) {
    return Math.max(0, Math.min(index, count - 1))
}

// One step through a list of `count`; it wraps.
function step(index, count, delta) {
    return count <= 0 ? 0 : ((index + delta) % count + count) % count
}

// --- the grid of the browse view ----------------------------------------------
// The tiles are sections laid out `columns` wide, each starting on a new row.
// `lengths` is the number of tiles of each section; indices run through all.

function locate(lengths, columns, index) {
    var start = 0
    for (var section = 0; section < lengths.length; section++) {
        if (index < start + lengths[section]) {
            var inside = index - start
            return { section: section, start: start, row: Math.floor(inside / columns), column: inside % columns }
        }
        start += lengths[section]
    }
    return { section: lengths.length - 1, start: start - 1, row: 0, column: 0 }
}

function rowCount(length, columns) {
    return Math.ceil(length / columns)
}

// Flat index of a tile in `section`, row and column (the column is clamped to
// what that row holds).
function tileAt(lengths, columns, section, row, column) {
    var start = 0
    for (var i = 0; i < section; i++)
        start += lengths[i]
    var inRow = Math.min(columns, lengths[section] - row * columns)
    return start + row * columns + Math.min(column, inRow - 1)
}

function total(lengths) {
    return lengths.reduce(function (sum, length) { return sum + length }, 0)
}

// The tile after moving "left" / "right" / "up" / "down" from `index`.
function gridMove(lengths, columns, index, direction) {
    var count = total(lengths)
    if (count === 0)
        return 0
    if (direction === "left")
        return Math.max(0, index - 1)
    if (direction === "right")
        return Math.min(count - 1, index + 1)
    var at = locate(lengths, columns, index)
    var section = at.section
    var row = at.row
    if (direction === "down") {
        if (row + 1 < rowCount(lengths[section], columns))
            return tileAt(lengths, columns, section, row + 1, at.column)
        for (var next = section + 1; next < lengths.length; next++) {
            if (lengths[next] > 0)
                return tileAt(lengths, columns, next, 0, at.column)
        }
        return index
    }
    if (row > 0)
        return tileAt(lengths, columns, section, row - 1, at.column)
    for (var before = section - 1; before >= 0; before--) {
        if (lengths[before] > 0)
            return tileAt(lengths, columns, before, rowCount(lengths[before], columns) - 1, at.column)
    }
    return index
}
