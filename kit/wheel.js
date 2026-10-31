// Mouse wheel and touchpad scrolling turned into slider steps: pure, tested in
// tests/qml/tst_slider.qml.
.pragma library

// Notches turned by one wheel event. A touchpad reports pixels (preferred when
// present); a wheel reports angle units, 120 to a notch.
function notches(angle, pixels, notch, perNotch) {
    return pixels !== 0 ? pixels / perNotch : angle / notch
}

// The value after `turned` notches of `perNotch` units each: whole multiples
// of `step`, clamped to from..to. `acc` is the part not applied yet; it is
// dropped when the end is reached, so turning back starts at once.
function advance(acc, turned, perNotch, step, value, from, to) {
    var total = acc + turned * perNotch
    var whole = step > 0 ? (total >= 0 ? Math.floor(total / step) : Math.ceil(total / step)) * step : total
    var next = Math.max(from, Math.min(to, value + whole))
    return { acc: next !== value + whole ? 0 : total - whole, value: next }
}
