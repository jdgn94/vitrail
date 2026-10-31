// Moves one entry of a list to a new place: the rest shift to make room.
// Pure; the input is never changed. Out-of-range places are clamped.
.pragma library

function move(list, from, to) {
    var out = list.slice()
    if (from < 0 || from >= out.length)
        return out
    var target = Math.max(0, Math.min(out.length - 1, to))
    var item = out.splice(from, 1)[0]
    out.splice(target, 0, item)
    return out
}
