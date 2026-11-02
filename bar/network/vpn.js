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

// The connections the active user may raise: the ones assigned to them, the
// ones assigned to nobody, and the tunnel that is up (so it can be taken
// down). `settings` is the `vpnSettings` document of the Connection page; with
// no readable document or no active user every connection is offered.
function available(connections, settings) {
    var doc
    try {
        doc = JSON.parse(settings)
    } catch (error) {
        return connections
    }
    if (!doc || !doc.active)
        return connections
    var assignments = Array.isArray(doc.assignments) ? doc.assignments : []
    return connections.filter(function (connection) {
        if (connection.active)
            return true
        var one = assignments.filter(function (other) { return other.vpn === connection.id })[0]
        return !one || !Array.isArray(one.users) || one.users.length === 0 || one.users.indexOf(doc.active) >= 0
    })
}
