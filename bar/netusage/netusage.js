// The network usage element's plain logic, shared by its button, its popup and
// the settings page: which direction the bar carries, the rate and total
// formatting, and the guard around "today". The rates and the graph come from
// the resources sampler (bar/resources/ResourcesSampler.qml) — this element
// runs no process and no timer of its own. vitrail.resources gives numbers and
// codes, never words; the words are translated in QML.
.pragma library

.import "../resources/resources.js" as Resources

// What `netusageBar` may hold, in the settings page's order.
var BAR_MODES = ["both", "down", "up"]
// What `netusageUnits` may hold: the resources element's own unit table.
var UNITS = Resources.UNITS

function barMode(value) {
    return BAR_MODES.indexOf(value) >= 0 ? value : "both"
}

// Which of the two directions the button carries.
function face(mode) {
    var chosen = barMode(mode)
    return { down: chosen !== "up", up: chosen !== "down" }
}

// A speed with its arrow: "↓ 1.5 MB/s", "↑ --".
function speed(value, units, direction) {
    var arrow = direction === "up" ? "↑" : direction === "down" ? "↓" : ""
    return (arrow === "" ? "" : arrow + " ") + Resources.rate(value, units)
}

// One rate without an arrow, for the tooltip.
function rate(value, units) {
    return Resources.rate(value, units)
}

// The local day as the Python side stamps it ("2026-11-22").
function dayKey(at) {
    return Qt.formatDate(at === undefined ? new Date() : at, "yyyy-MM-dd")
}

// Bytes used since local midnight. A snapshot stamped with another day (the
// sampler has not ticked since midnight) reads zero rather than yesterday's
// total; the Python side clamps a reboot, and this clamps again so a stale or
// hand-written snapshot can never show a negative number.
function today(snapshot, day) {
    var block = snapshot && snapshot.today ? snapshot.today : null
    if (!block || block.date !== day)
        return { rx: 0, tx: 0 }
    return { rx: Math.max(0, Number(block.rx) || 0), tx: Math.max(0, Number(block.tx) || 0) }
}

// Today's received and sent totals in the chosen units.
function todayText(snapshot, day, units) {
    var used = today(snapshot, day)
    return { rx: Resources.bytes(used.rx, units, "network"), tx: Resources.bytes(used.tx, units, "network") }
}

// "Today: 4.7 GB received · 620 MB sent".
function todayLine(snapshot, day, units, t) {
    var totals = todayText(snapshot, day, units)
    return t("bar.netusage.today").replace("%1", totals.rx).replace("%2", totals.tx)
}

// Whether the sampler has network counters to draw at all.
function online(snapshot) {
    return Resources.ready(snapshot) && !!snapshot.network
}

// The current rates in bytes per second; null before the second reading.
function rates(snapshot) {
    var rate = snapshot && snapshot.rate ? snapshot.rate : null
    return {
        down: rate && rate.rx !== null && rate.rx !== undefined ? Number(rate.rx) : null,
        up: rate && rate.tx !== null && rate.tx !== undefined ? Number(rate.tx) : null
    }
}
