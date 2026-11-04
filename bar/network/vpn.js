.pragma library

var providers = { proton: "ProtonVPN" }

// "us-free-12.protonvpn.udp.ovpn" reads as "us-free-12" over
// "protonvpn · udp".
function title(name) {
    return name.replace(/\.(ovpn|conf)$/, "").split(".")[0]
}

function detail(connection) {
    var parts = connection.name.replace(/\.(ovpn|conf)$/, "").split(".").slice(1)
    if (connection.region)
        parts.push(connection.region)
    return parts.join(" · ")
}

// The provider as its brand writes it.
function provider(connection) {
    var key = connection.provider || ""
    return providers[key] || key.charAt(0).toUpperCase() + key.slice(1)
}

// Which server of the provider: its name and where it is.
function service(connection) {
    var name = title(connection.name)
    return connection.region ? name + " · " + connection.region : name
}

function active(connections) {
    for (var i = 0; i < connections.length; i++) {
        if (connections[i].active)
            return connections[i]
    }
    return null
}

// --- connection quality ------------------------------------------------------
// What `vitrail.network probe` stores per connection ({ latency: ms|null,
// loss: percent|null }), read the same way by the bar popup and the settings
// tab. A connection that was not measured is "unknown", never a made-up number.

// Good: under 100 ms and nothing lost. Fair: under 250 ms and at most 10 % lost.
var GOOD_LATENCY = 100
var FAIR_LATENCY = 250
var FAIR_LOSS = 10

function level(one) {
    if (!one || typeof one.latency !== "number")
        return "unknown"
    var loss = typeof one.loss === "number" ? one.loss : 0
    if (one.latency < GOOD_LATENCY && loss === 0)
        return "good"
    return one.latency < FAIR_LATENCY && loss <= FAIR_LOSS ? "fair" : "poor"
}

// "42 ms" for a connection that was measured, "—" for one that was not.
function latency(one) {
    return one && typeof one.latency === "number" ? Math.round(one.latency) + " ms" : "—"
}

// Whether the popup should ask for a new measurement: some connection is
// listed, and nothing measured them (or asked to) within `interval` ms. `updated`
// is when network-state.json was last written, `asked` when this bar last
// asked (both ms since the epoch, 0 for never).
function needsProbe(now, updated, asked, interval, connections) {
    return connections > 0 && now - Math.max(updated, asked) >= interval
}
