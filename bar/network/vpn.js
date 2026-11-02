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
