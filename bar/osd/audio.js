// Pure helpers for the apps of the volume and microphone cards. No QML type
// is touched here: `tests/qml/tst_osd.qml` feeds them plain objects.
.pragma library

function text(value) {
    return String(value === undefined || value === null ? "" : value).trim()
}

// What names an app: its own name, its binary, then the node's name.
function appKey(props, fallback) {
    var source = props || ({})
    var name = text(source["application.name"])
    if (name !== "")
        return name
    var binary = text(source["application.process.binary"])
    if (binary !== "")
        return binary
    return text(fallback)
}

function appName(props, fallback) {
    return appKey(props, fallback)
}

// The icon the stream recommends, when it names one.
function iconName(props) {
    return text((props || ({}))["application.icon-name"])
}

// One group per app, in the order the apps first appear. `entries` are
// { key, name, icon, binary, node }; the group keeps the nodes together.
function groups(entries) {
    var out = []
    var index = ({})
    var list = entries || []
    for (var i = 0; i < list.length; i++) {
        var entry = list[i] || ({})
        var key = text(entry.key)
        if (key === "")
            key = text(entry.name)
        if (key === "")
            key = text(entry.binary)
        if (key === "")
            continue
        if (index[key] === undefined) {
            index[key] = { key: key, name: text(entry.name) || key, icon: text(entry.icon),
                           binary: text(entry.binary), nodes: [] }
            out.push(index[key])
        }
        if (entry.node !== undefined)
            index[key].nodes.push(entry.node)
    }
    return out
}

// Does a Hyprland window class belong to this app? Exact names first; a
// binary such as "firefox" also matches "firefox-esr" and friends.
function classMatches(binary, name, ipcClass) {
    var cls = text(ipcClass).toLowerCase()
    if (cls === "")
        return false
    var bin = text(binary).toLowerCase()
    var app = text(name).toLowerCase()
    return cls === bin || cls === app
        || (bin !== "" && (cls.indexOf(bin) >= 0 || bin.indexOf(cls) >= 0))
        || (app !== "" && (cls.indexOf(app) >= 0 || app.indexOf(cls) >= 0))
}
