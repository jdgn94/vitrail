.pragma library
.import "../widgets.js" as Registry

// The in-place desktop editor's geometry. The document stores each widget's
// top-left as 0..1 of the monitor; these helpers turn a dragged card back into
// that point, and a corner drag into one of the registry's own sizes. They are
// pure functions so the QML tests can check the maths without pointer events.

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
}

// A point of the desktop canvas, with the card kept inside it: dragging a card
// past an edge parks it flush with the edge instead of half off the screen.
function moveTo(x, y, width, height, areaWidth, areaHeight) {
    var availableX = Math.max(0, areaWidth - width)
    var availableY = Math.max(0, areaHeight - height)
    var px = clamp(Number(x) || 0, 0, availableX)
    var py = clamp(Number(y) || 0, 0, availableY)
    return { x: areaWidth > 0 ? px / areaWidth : 0,
             y: areaHeight > 0 ? py / areaHeight : 0 }
}

// The registry size a dragged corner asks for. The canvas draws at `scale`
// screen pixels per real pixel, so the caller divides the card width back
// before asking.
function sizeForWidth(id, width) {
    return Registry.sizeForWidth(id, width)
}
