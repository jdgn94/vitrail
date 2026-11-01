// Where notifications live: pure geometry-free rules, tested in
// tests/qml/tst_notifications.qml.
.pragma library

// The configured side, unless the bar owns it: notifications never open on the
// bar's edge. Legacy values ("top-right") are tolerated until the preference
// migration rewrites them to "left" / "right".
function sideFor(position, barEdge) {
    var text = String(position || "right")
    var want = text.indexOf("left") >= 0 ? "left" : "right"
    if (want === barEdge)
        return want === "left" ? "right" : "left"
    return want
}

// Toasts hang from the top of that side; the panel fills the whole height.
function stackPosition(position, barEdge) {
    return "top-" + sideFor(position, barEdge)
}

// A notification is listed but never raised as a toast while the panel is
// open, or while Do Not Disturb is on. Preferences arrive as booleans or as
// the strings the INI file holds, so both are read.
function enabled(value) {
    return value === true || value === "true"
}

function silent(panelOpen, dnd) {
    return enabled(panelOpen) || enabled(dnd)
}
