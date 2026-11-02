.pragma library

// The VPN document the Connection page keeps in misc.ini (`vpnSettings`, one
// JSON text) and the bar and vitrail/network.py read. Every function takes a
// document and returns a changed copy, or null when there is nothing to
// change. Parts this file does not know (`options`, anything a newer Vitrail
// adds) are kept as they are.
//
//   users        [{ id, name, note }]  profiles of this shell, not OS accounts
//   active       id of the user the bar is for
//   assignments  [{ vpn, users: [id], mode: "split"|"full",
//                   hosts: [{ url, ips, domains, pending?, retry? }] }]
//   options      kept, not edited: hypraether-vpn has no switch for them
//   extra        [{ name, type: "openvpn"|"wireguard"|"other", path }]

var TYPES = ["openvpn", "wireguard", "other"]
// The same shapes vitrail/network.py accepts: a host of letters, digits and
// dashes with at least one dot, and a last label with a letter.
var LABEL = "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
var HOST = new RegExp("^(" + LABEL + "\\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$")
var URL = new RegExp("^(https?)://([^/:?#@\\s]+)(:[0-9]{1,5})?([/?#]\\S*)?$", "i")

function copy(value) {
    return JSON.parse(JSON.stringify(value))
}

function parse(text) {
    var doc
    try {
        doc = JSON.parse(text)
    } catch (error) {
        doc = null
    }
    if (!doc || typeof doc !== "object" || Array.isArray(doc))
        doc = {}
    doc.users = (Array.isArray(doc.users) ? doc.users : []).filter(function (user) {
        return user && typeof user.id === "string" && user.id !== ""
    })
    doc.active = typeof doc.active === "string" ? doc.active : ""
    doc.assignments = (Array.isArray(doc.assignments) ? doc.assignments : []).filter(function (one) {
        return one && typeof one.vpn === "string" && one.vpn !== ""
    })
    doc.extra = Array.isArray(doc.extra) ? doc.extra : []
    return doc
}

function stringify(doc) {
    return JSON.stringify(doc)
}

// --- users ------------------------------------------------------------------

function slug(name, taken) {
    var base = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "user"
    var id = base
    for (var n = 2; taken.indexOf(id) >= 0; n++)
        id = base + "-" + n
    return id
}

function addUser(doc, name) {
    name = name.trim()
    if (name === "")
        return null
    var next = copy(doc)
    var id = slug(name, next.users.map(function (user) { return user.id }))
    next.users.push({ id: id, name: name, note: "" })
    if (next.active === "")
        next.active = id
    return next
}

function renameUser(doc, id, name) {
    name = name.trim()
    var next = copy(doc)
    var user = next.users.filter(function (one) { return one.id === id })[0]
    if (!user || name === "" || user.name === name)
        return null
    user.name = name
    return next
}

function removeUser(doc, id) {
    var next = copy(doc)
    next.users = next.users.filter(function (user) { return user.id !== id })
    next.assignments.forEach(function (one) {
        one.users = (one.users || []).filter(function (user) { return user !== id })
    })
    if (next.active === id)
        next.active = next.users.length > 0 ? next.users[0].id : ""
    return next
}

function setActive(doc, id) {
    var next = copy(doc)
    if (next.users.some(function (user) { return user.id === id }))
        next.active = id
    return next
}

// --- assignments ------------------------------------------------------------

function assignmentOf(doc, vpn) {
    var found = doc.assignments.filter(function (one) { return one.vpn === vpn })[0]
    var one = found ? copy(found) : { vpn: vpn }
    one.users = Array.isArray(one.users) ? one.users : []
    one.mode = one.mode === "full" ? "full" : "split"
    one.hosts = Array.isArray(one.hosts) ? one.hosts : []
    return one
}

// A copy of the document where `change` edited the assignment of `vpn`
// (made on first use); `change` returns false for "nothing to do".
function edit(doc, vpn, change) {
    var one = assignmentOf(doc, vpn)
    if (change(one) === false)
        return null
    var next = copy(doc)
    var at = next.assignments.findIndex(function (other) { return other.vpn === vpn })
    if (at < 0)
        next.assignments.push(one)
    else
        next.assignments[at] = one
    return next
}

function toggleUser(doc, vpn, id) {
    return edit(doc, vpn, function (one) {
        var at = one.users.indexOf(id)
        if (at < 0)
            one.users.push(id)
        else
            one.users.splice(at, 1)
    })
}

function setMode(doc, vpn, mode) {
    return edit(doc, vpn, function (one) { one.mode = mode === "full" ? "full" : "split" })
}

// --- hosts ------------------------------------------------------------------

// What the rule stores for text typed in the URL field: `https://host` (the
// scheme as typed, https for a bare host; path, port and query dropped, they
// do not matter for the lookup). "" when it is not an http(s) URL or a host.
function normalizeUrl(text) {
    text = text.trim()
    var scheme = "https"
    var host = text.toLowerCase().replace(/\.$/, "")
    var parts = URL.exec(text)
    if (parts) {
        scheme = parts[1].toLowerCase()
        host = parts[2].toLowerCase().replace(/\.$/, "")
    }
    return host.length <= 253 && HOST.test(host) ? scheme + "://" + host : ""
}

function hostOf(doc, vpn, url) {
    return assignmentOf(doc, vpn).hosts.filter(function (host) { return host.url === url })[0]
}

function changeHost(doc, vpn, url, change) {
    return edit(doc, vpn, function (one) {
        var host = one.hosts.filter(function (other) { return other.url === url })[0]
        return host ? change(host, one) : false
    })
}

function addHost(doc, vpn, url) {
    return edit(doc, vpn, function (one) {
        if (one.hosts.some(function (host) { return host.url === url }))
            return false
        one.hosts.push({ url: url, ips: [], domains: [], pending: true })
    })
}

function markPending(doc, vpn, url) {
    return changeHost(doc, vpn, url, function (host) {
        host.pending = true
        host.retry = false
    })
}

function removeHost(doc, vpn, url) {
    return changeHost(doc, vpn, url, function (host, one) {
        one.hosts = one.hosts.filter(function (other) { return other !== host })
    })
}

function removeDomain(doc, vpn, url, domain) {
    return changeHost(doc, vpn, url, function (host) {
        host.domains = host.domains.filter(function (name) { return name !== domain })
    })
}

function removeIp(doc, vpn, url, address) {
    return changeHost(doc, vpn, url, function (host) {
        host.ips = host.ips.filter(function (ip) { return ip !== address })
    })
}

function pending(doc) {
    return doc.assignments.some(function (one) {
        return (one.hosts || []).some(function (host) { return host.pending === true })
    })
}

// Files the answers of vitrail.network (`resolved`, by the URL that was
// asked) into the hosts still waiting for them. An answer with nothing in it
// (offline) leaves the lists a host already had and asks for a retry.
// null when no waiting host was answered.
function merge(doc, resolved) {
    var next = copy(doc)
    var changed = false
    next.assignments.forEach(function (one) {
        (one.hosts || []).forEach(function (host) {
            var answer = resolved[host.url]
            if (host.pending !== true || !answer)
                return
            var ips = Array.isArray(answer.ips) ? answer.ips : []
            var domains = Array.isArray(answer.domains) ? answer.domains : []
            if (ips.length > 0 || domains.length > 0) {
                host.ips = ips
                host.domains = domains
            }
            host.pending = false
            host.retry = answer.retry === true
            changed = true
        })
    })
    return changed ? next : null
}

// --- extra connections ------------------------------------------------------

function addExtra(doc, name, type, path) {
    name = name.trim()
    path = path.trim()
    if (name === "" || path === "")
        return null
    var next = copy(doc)
    next.extra.push({ name: name, type: TYPES.indexOf(type) >= 0 ? type : "other", path: path })
    return next
}

function removeExtra(doc, index) {
    var next = copy(doc)
    next.extra.splice(index, 1)
    return next
}
