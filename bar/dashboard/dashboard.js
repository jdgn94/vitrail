// The dashboard's numbers and states: pure, so they are tested without a
// window or a process (tests/qml/tst_dashboard.qml).

// The JSON one of the services printed, or an empty state. A broken answer
// (offline, a partial write) never takes the panel down.
function parse(text) {
    var value = null
    try {
        value = JSON.parse(String(text || ""))
    } catch (error) {
        return ({})
    }
    return value !== null && typeof value === "object" ? value : ({})
}

// 42.6 -> "43%"; missing or unreadable values are absent, never 0.
function percent(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number))
        return "--"
    return Math.round(Math.max(0, Math.min(100, number))) + "%"
}

// Bytes in the unit a person reads: 1536 -> "1.5 KB".
function bytes(value) {
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

// A temperature with the service's own unit: 18.4, "°C" -> "18 °C".
function temperature(value, unit) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number))
        return "--"
    return Math.round(number) + " " + (unit || "°")
}

// A day's high and low, without repeating the unit: "21° / 10°".
function degrees(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    return isFinite(number) ? Math.round(number) + "°" : "--"
}

// "used / total · percent" for memory and disk.
function usage(part) {
    if (!part || typeof part !== "object")
        return "--"
    return bytes(part.used) + " / " + bytes(part.total) + " · " + percent(part.percent)
}

// What has gone through the network since boot.
function network(part) {
    if (!part || typeof part !== "object")
        return "--"
    return "↓ " + bytes(part.rx) + "  ↑ " + bytes(part.tx)
}
