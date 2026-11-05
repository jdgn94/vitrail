.pragma library

// The link's latency and traffic, as the bar and the popups write them. The
// numbers come from `vitrail.network link` (one echo and the kernel counters);
// anything that was not measured reads as nothing, never as a made-up zero.

// Bytes per second in the shortest honest unit: 999 B/s, 1.2 kB/s, 80 kB/s.
// SI units, because that is how a connection is sold and what the network
// tools print.
var UNITS = ["B/s", "kB/s", "MB/s", "GB/s"]

function rate(bytes) {
    if (typeof bytes !== "number" || !isFinite(bytes) || bytes < 0)
        return ""
    var value = bytes
    var unit = 0
    while (value >= 1000 && unit < UNITS.length - 1) {
        value /= 1000
        unit++
    }
    var shown = unit === 0 ? String(Math.round(value))
              : value >= 10 ? String(Math.round(value)) : value.toFixed(1)
    return shown + " " + UNITS[unit]
}

function latency(ms) {
    return typeof ms === "number" && isFinite(ms) ? Math.round(ms) + " ms" : ""
}

// "12 ms · ↓ 1.2 MB/s ↑ 80 kB/s", the pieces that exist. Empty when nothing
// was measured, so a caller can hide its line instead of showing a dash.
function summary(stats) {
    if (!stats)
        return ""
    var parts = []
    var delay = latency(stats.latency)
    if (delay !== "")
        parts.push(delay)
    var traffic = stats.traffic || ({})
    var flow = []
    if (typeof traffic.rx === "number")
        flow.push("↓ " + rate(traffic.rx))
    if (typeof traffic.tx === "number")
        flow.push("↑ " + rate(traffic.tx))
    if (flow.length > 0)
        parts.push(flow.join(" "))
    return parts.join(" · ")
}
