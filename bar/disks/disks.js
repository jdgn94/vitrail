// The disks element's plain logic: which drives the bar and the popup draw,
// what each card says, which actions a device state allows and why it does not,
// and the automount rule that never mounts the same drive twice. No QML type
// is touched here, so tests/qml/tst_disks.qml feeds it plain objects.
.pragma library

// A snapshot the element can draw: vitrail.disks prints `devices` and `total`;
// the BarSnapshot's `{ error: "unreadable" }` is an unavailable element.
function ready(snapshot) {
    return !!snapshot && !snapshot.error && Array.isArray(snapshot.devices)
}

// The ignore preference: one JSON array of labels or UUIDs, as typed.
function parseIgnore(text) {
    var list = []
    try {
        list = JSON.parse(String(text || "[]"))
    } catch (error) {
        return []
    }
    if (!Array.isArray(list))
        return []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var entry = typeof list[i] === "string" ? list[i].trim() : ""
        if (entry === "" || matches(out, entry))
            continue
        out.push(entry)
    }
    return out
}

// Case-insensitive, so a hand-edited "kingston" still names KINGSTON.
function matches(name, entry) {
    var wanted = String(entry).trim().toLowerCase()
    for (var i = 0; i < name.length; i++) {
        if (String(name[i]).toLowerCase() === wanted)
            return true
    }
    return false
}

// The preference's text after `entry` is added (or removed); the entry keeps
// the case it was typed in.
function withIgnore(text, entry, on) {
    var value = String(entry || "").trim()
    var list = parseIgnore(text)
    if (value === "")
        return JSON.stringify(list)
    var out = list.filter(function (one) {
        return one.toLowerCase() !== value.toLowerCase()
    })
    if (on)
        out.push(value)
    return JSON.stringify(out)
}

// The devices the bar and the popup show: the snapshot's, minus the ignored
// ones. An ignored drive is left alone and does not keep the element visible.
function visibleDevices(snapshot, ignoreText) {
    if (!ready(snapshot))
        return []
    var ignore = parseIgnore(ignoreText)
    return snapshot.devices.filter(function (device) {
        return !ignored(device, ignore)
    })
}

function ignored(device, ignore) {
    for (var i = 0; i < ignore.length; i++) {
        var wanted = ignore[i].toLowerCase()
        if (String(device.label || "").toLowerCase() === wanted
                || String(device.uuid || "").toLowerCase() === wanted)
            return true
    }
    return false
}

// What the button and the card call a drive: its label, then its model, then
// the node name without /dev/.
function nameOf(device) {
    if (!device)
        return ""
    if (device.label)
        return String(device.label)
    if (device.model)
        return String(device.model)
    return String(device.name || "").replace(/^\/dev\//, "")
}

// Bytes in the unit a person reads: 1536 -> "1.5 KB".
function humanSize(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number) || number < 0)
        return "--"
    var units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var index = 0
    while (number >= 1024 && index < units.length - 1) {
        number /= 1024
        index += 1
    }
    return (index === 0 ? String(Math.round(number)) : number.toFixed(1)) + " " + units[index]
}

// One drive's space: its used and total while mounted, its size otherwise.
function space(device) {
    if (!device)
        return ""
    if (!device.mounted || device.used === null || device.used === undefined)
        return humanSize(device.size)
    return humanSize(device.used) + " / " + humanSize(device.size)
}

// The tooltip's second line: one drive says its own space, several say the
// used and total of every connected one. An unmounted drive has no usage, so
// its size stands in for it.
function usage(devices) {
    var list = devices || []
    if (list.length === 0)
        return ""
    if (list.length === 1)
        return space(list[0])
    var used = 0
    var total = 0
    var mounted = false
    for (var i = 0; i < list.length; i++) {
        total += Number(list[i].size) || 0
        if (list[i].mounted && list[i].used !== null && list[i].used !== undefined) {
            used += Number(list[i].used) || 0
            mounted = true
        }
    }
    return mounted ? humanSize(used) + " / " + humanSize(total) : humanSize(total)
}

// Which of the four actions a device's state allows. Mount and Unmount are
// mutually exclusive; Eject needs it unmounted and Open needs a mount point.
function allowed(device, action) {
    if (!device)
        return false
    var mounted = !!device.mounted
    var point = String(device.mountpoint || "")
    if (action === "mount")
        return !mounted && !!device.name
    if (action === "unmount")
        return mounted && point !== ""
    if (action === "eject")
        return !mounted && !!device.name
    if (action === "open")
        return mounted && point !== ""
    return false
}

// Why the forbidden actions are disabled, as translation keys. A device is
// either mounted or not, so one state line explains both of its disabled
// buttons; a running action adds its own.
function reasons(device, busy) {
    var out = []
    if (busy)
        out.push("bar.disks.reason.busy")
    if (!device)
        return out
    if (!device.mounted)
        out.push("bar.disks.reason.unmounted")
    else if (!device.mountpoint)
        out.push("bar.disks.reason.mountpoint")
    else
        out.push("bar.disks.reason.mounted")
    return out
}

// The names a newly seen drive is mounted by, when automount is on. A drive
// already in `attempted` is never mounted again: the name is recorded before
// the action starts, so a slow mount (or a failed one) does not loop. A drive
// that is gone from the snapshot leaves the list, so plugging it back in is a
// new arrival.
function automountCandidates(attempted, snapshot, ignoreText, enabled) {
    if (enabled !== true)
        return []
    var tried = Array.isArray(attempted) ? attempted : []
    var out = []
    var devices = visibleDevices(snapshot, ignoreText)
    for (var i = 0; i < devices.length; i++) {
        var name = String(devices[i].name || "")
        if (!devices[i].mounted && name !== "" && tried.indexOf(name) < 0 && out.indexOf(name) < 0)
            out.push(name)
    }
    return out
}

// The attempted names that are still connected: the ones that disappeared are
// forgotten, so a re-plug is a new arrival.
function retainAttempted(attempted, snapshot) {
    var present = {}
    if (ready(snapshot)) {
        for (var i = 0; i < snapshot.devices.length; i++)
            present[snapshot.devices[i].name] = true
    }
    return (Array.isArray(attempted) ? attempted : []).filter(function (name) {
        return present[name] === true
    })
}
