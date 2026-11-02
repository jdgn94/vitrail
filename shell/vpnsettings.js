.pragma library

// The one thing Vitrail keeps of its own about the VPN, in misc.ini
// (`vpnSettings`, one JSON text): which connections the automatic choice may
// use. Everything else (connections, credentials, mode, domains, the
// autostart marker) is hypraether-vpn's. vitrail/network.py reads it to pick
// the best connection.
//
//   { "connections": { "<id>": { "auto": false } } }     absent = true
//
// Every function takes a document and returns a changed copy, or null when
// there is nothing to change.

function copy(value) {
    return JSON.parse(JSON.stringify(value))
}

// A document from its text. Tolerant: anything that is not an object, and
// every part of an older document (users, assignments, extra, active,
// options) is dropped; only connections kept out of the choice survive.
function parse(text) {
    var doc
    try {
        doc = JSON.parse(text)
    } catch (error) {
        doc = null
    }
    var found = doc && typeof doc === "object" && !Array.isArray(doc) && doc.connections
    var connections = {}
    if (found && typeof found === "object" && !Array.isArray(found)) {
        Object.keys(found).forEach(function (id) {
            if (found[id] && typeof found[id] === "object" && found[id].auto === false)
                connections[id] = { auto: false }
        })
    }
    return { connections: connections }
}

function stringify(doc) {
    return JSON.stringify(doc)
}

function isAuto(doc, id) {
    return !(doc.connections[id] && doc.connections[id].auto === false)
}

function setAuto(doc, id, auto) {
    if (isAuto(doc, id) === auto)
        return null
    var next = copy(doc)
    if (auto)
        delete next.connections[id]
    else
        next.connections[id] = { auto: false }
    return next
}

// The connections that no longer exist are dropped from the document.
function prune(doc, ids) {
    var next = copy(doc)
    var changed = false
    Object.keys(next.connections).forEach(function (id) {
        if (ids.indexOf(id) < 0) {
            delete next.connections[id]
            changed = true
        }
    })
    return changed ? next : null
}
