// Where the OSD sits and how big it is: pure geometry, tested in
// tests/qml/tst_osd.qml. The panel is glued to a screen edge, centred along
// it; a hot zone as long as the panel reveals it; a card with the devices of
// the hovered slider opens beside it toward the screen interior.
//
// metrics: { thickness, length, icon, textWide, textTall, pad, spacing, inner }
// in px: slider thickness, slider length, icon slot, the percentage's slot
// (wide: beside a horizontal slider, tall: below a vertical one), the panel
// padding, the space between cells and the one inside a cell.
.pragma library

function vertical(edge) {
    return edge === "left" || edge === "right"
}

// The edge opposite the notification stack (see Frame.stackRect), centred
// there; the bar's own edge is never taken: it falls back to the top, and to
// the bottom when the bar is on the top.
function edgeFor(position, barEdge) {
    var parts = String(position || "").split("-")
    var across = parts[1] === "left" || parts[1] === "center" ? parts[1] : "right"
    var edge = across === "left" ? "right"
             : across === "right" ? "left"
             : parts[0] === "bottom" ? "top" : "bottom"
    if (edge === barEdge)
        return barEdge === "top" ? "bottom" : "top"
    return edge
}

// The panel's bounds on one screen: its own frame on the docking side, the
// reference screen's (the primary's) along the edge, so the panel is centred
// at the same spot on every monitor.
function alignBounds(edge, own, reference) {
    return vertical(edge)
        ? { left: own.left, right: own.right, top: reference.top, bottom: reference.bottom }
        : { top: own.top, bottom: own.bottom, left: reference.left, right: reference.right }
}

// One slider with its icon and its percentage.
function cell(isVertical, m) {
    var along = m.icon + m.inner + m.length + m.inner
    return isVertical ? { width: m.thickness, height: along + m.textTall }
                      : { width: along + m.textWide, height: m.thickness }
}

function panelSize(edge, count, m) {
    var one = cell(vertical(edge), m)
    var run = function (extent) { return count * extent + (count - 1) * m.spacing + 2 * m.pad }
    return vertical(edge) ? { width: m.thickness + 2 * m.pad, height: run(one.height) }
                          : { width: run(one.width), height: m.thickness + 2 * m.pad }
}

// The panel on its edge: flush with `bounds` (the frame, per side; the bar's
// side included) plus `gap` when it floats, centred in what they leave.
function panelRect(edge, width, height, size, bounds, gap) {
    var x = edge === "left" ? bounds.left + gap
          : edge === "right" ? width - bounds.right - gap - size.width
          : bounds.left + (width - bounds.left - bounds.right - size.width) / 2
    var y = edge === "top" ? bounds.top + gap
          : edge === "bottom" ? height - bounds.bottom - gap - size.height
          : bounds.top + (height - bounds.top - bounds.bottom - size.height) / 2
    return { x: x, y: y, width: size.width, height: size.height }
}

// An invisible strip on the screen edge, as long as the panel and as thick as
// the frame border plus `extra`.
function hotZone(edge, width, height, panel, border, extra) {
    var depth = border + extra
    switch (edge) {
    case "right": return { x: width - depth, y: panel.y, width: depth, height: panel.height }
    case "top": return { x: panel.x, y: 0, width: panel.width, height: depth }
    case "bottom": return { x: panel.x, y: height - depth, width: panel.width, height: depth }
    default: return { x: 0, y: panel.y, width: depth, height: panel.height }
    }
}

// Screen rect of the index-th cell of a panel.
function cellRect(edge, panel, index, m) {
    var one = cell(vertical(edge), m)
    if (vertical(edge))
        return { x: panel.x + m.pad, y: panel.y + m.pad + index * (one.height + m.spacing),
                 width: one.width, height: one.height }
    return { x: panel.x + m.pad + index * (one.width + m.spacing), y: panel.y + m.pad,
             width: one.width, height: one.height }
}

// The card of a hovered cell: `gap` past the panel's inner face, centred on
// the cell and kept `gap` inside the frame.
function cardRect(edge, panel, cell, size, bounds, gap, width, height) {
    var inside = function (at, extent, lo, hi) {
        return Math.max(lo + gap, Math.min(at, hi - extent - gap))
    }
    var x = edge === "left" ? panel.x + panel.width + gap
          : edge === "right" ? panel.x - gap - size.width
          : inside(cell.x + cell.width / 2 - size.width / 2, size.width, bounds.left, width - bounds.right)
    var y = edge === "top" ? panel.y + panel.height + gap
          : edge === "bottom" ? panel.y - gap - size.height
          : inside(cell.y + cell.height / 2 - size.height / 2, size.height, bounds.top, height - bounds.bottom)
    return { x: x, y: y, width: size.width, height: size.height }
}
