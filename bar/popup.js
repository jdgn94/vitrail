.pragma library

// Whether a point is still on an open popup. The popup closes only when the
// pointer has left all of it: the card, the tray app's menu card beside it,
// and the button it grew from. Coordinates are the screen's, so the caller
// maps the pointer out of whichever layer surface saw it.

// `point` (or `rect`) missing: nothing is inside.
function inside(point, rect, margin) {
    if (!point || !rect)
        return false
    var gap = margin || 0
    return point.x >= rect.x - gap && point.x <= rect.x + rect.width + gap
            && point.y >= rect.y - gap && point.y <= rect.y + rect.height + gap
}

// Any of `rects` (null entries are skipped).
function insideAny(point, rects, margin) {
    if (!point || !rects)
        return false
    for (var i = 0; i < rects.length; i++) {
        if (inside(point, rects[i], margin))
            return true
    }
    return false
}
