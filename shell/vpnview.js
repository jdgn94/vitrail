.pragma library

// Pure helpers of the VPN tab (shell/pages/ConnectionPage.qml).

// The same shapes vitrail/network.py accepts: a host of letters, digits and
// dashes with at least one dot, and a last label with a letter.
var LABEL = "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
var HOST = new RegExp("^(" + LABEL + "\\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$")
var URL = new RegExp("^(https?)://([^/:?#@\\s]+)(:[0-9]{1,5})?([/?#]\\S*)?$", "i")
// Second-level labels under a two-letter country code (example.co.uk).
var SECOND_LEVEL = ["co", "com", "org", "net", "gov", "ac", "edu"]

// What the URL field accepts: `https://host` (the scheme as typed, https for a
// bare host; path, port and query dropped). "" when it is not an http(s) URL
// or a host.
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

// The domain a host belongs to, as vitrail/network.py computes it: its last
// two labels, three under a two-letter country code with a common second
// level. A heuristic: there is no public-suffix list here.
function registrable(host) {
    var labels = host.split(".")
    if (labels.length >= 3 && labels[labels.length - 1].length === 2
            && SECOND_LEVEL.indexOf(labels[labels.length - 2]) >= 0)
        return labels.slice(-3).join(".")
    return labels.slice(-2).join(".")
}

// vitrail-vpn's flat domain list ([{ domain, ips }], ips a count) grouped by
// registrable domain: [{ root, count, ips, domains: [{ domain, ips }] }],
// groups and names sorted. Nothing is stored: the list is the only truth.
function groupDomains(list) {
    var groups = {}
    list.forEach(function (entry) {
        var root = registrable(entry.domain)
        if (!groups[root])
            groups[root] = { root: root, count: 0, ips: 0, domains: [] }
        groups[root].count += 1
        groups[root].ips += entry.ips
        groups[root].domains.push({ domain: entry.domain, ips: entry.ips })
    })
    return Object.keys(groups).sort().map(function (root) {
        groups[root].domains.sort(function (a, b) { return a.domain < b.domain ? -1 : a.domain > b.domain ? 1 : 0 })
        return groups[root]
    })
}

// The path of a `file://` URL (what a file dialog returns), percent-decoded;
// a plain path is returned as it is, anything else is "".
function filePath(url) {
    url = String(url).trim()
    if (url.indexOf("file://") === 0) {
        try {
            return decodeURIComponent(url.replace(/^file:\/\/(localhost)?/, ""))
        } catch (error) {
            return ""
        }
    }
    return url.charAt(0) === "/" ? url : ""
}

function baseName(path) {
    return path.split("/").pop()
}

// 32 hex digits that name one password file; the file lives in a private
// folder, the name only keeps requests apart.
function nonce() {
    var out = ""
    for (var i = 0; i < 32; i++)
        out += Math.floor(Math.random() * 16).toString(16)
    return out
}

// A request for vitrail.network that carries an object.
function request(verb, payload) {
    return verb + ":" + JSON.stringify(payload)
}

// The text of an import: only what was given. `move` asks the helper to delete
// the picked file once its private copy is verified.
function importRequest(file, name, credential, move) {
    var payload = { file: file }
    if (name.trim() !== "")
        payload.name = name.trim()
    if (credential !== "")
        payload.credential = credential
    if (move)
        payload.move = true
    return request("vpn-import", payload)
}

function hasExtension(path) {
    return /\.(ovpn|conf)$/i.test(path)
}

// What a credential edit changes besides the password: `{ name, rename?, user? }`
// for the credential `current` ({ name, username }); null when nothing did.
function updatePayload(current, name, username) {
    var payload = { name: current.name }
    if (name.trim() !== "" && name.trim() !== current.name)
        payload.rename = name.trim()
    if (username.trim() !== "" && username.trim() !== current.username)
        payload.user = username.trim()
    return Object.keys(payload).length > 1 ? payload : null
}
