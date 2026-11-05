// The battery and Bluetooth chips' numbers and words. The battery comes from
// Quickshell's UPower service (no process); Bluetooth from `vitrail.network
// bluetooth`, the same read the Connection page uses. Tested in
// tests/qml/tst_devices.qml.
.pragma library

// UPowerDeviceState, in the order the service declares it.
var STATES = ["unknown", "charging", "discharging", "empty", "full", "pending", "pending"]
var GLYPHS = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
              "battery_4_bar", "battery_5_bar", "battery_6_bar"]

function number(value) {
    return typeof value === "number" && isFinite(value)
}

// A chip only where there is a battery to read: no display device, a device
// the service says is gone, or the synthetic display device of a machine
// without one (zero charge and no battery state), shows nothing.
function batteryShown(device) {
    if (!device || device.isPresent === false || !number(device.percentage))
        return false
    if (device.percentage > 0)
        return true
    return [1, 2, 3, 4].indexOf(device.state) >= 0
}

// 84.6 -> "85%", never past the ends of the scale.
function batteryPercent(percentage) {
    if (!number(percentage))
        return ""
    return Math.max(0, Math.min(100, Math.round(percentage))) + "%"
}

function batteryState(state) {
    return STATES[state] || "unknown"
}

function batteryCharging(device) {
    var state = batteryState(device ? device.state : -1)
    return state === "charging" || state === "pending"
}

// The full battery at the top of the scale, the charging bolt while it fills.
function batteryGlyph(device) {
    if (batteryCharging(device))
        return "battery_charging_full"
    var percentage = batteryShown(device) ? device.percentage : 0
    var step = Math.min(6, Math.max(0, Math.floor(percentage / 100 * GLYPHS.length)))
    return percentage >= 95 ? "battery_full" : GLYPHS[step]
}

// Seconds until the battery is empty (or full): 0 when UPower does not know.
function batterySeconds(device) {
    if (!device)
        return 0
    var state = batteryState(device.state)
    var seconds = state === "charging" ? device.timeToFull
                : state === "discharging" ? device.timeToEmpty : 0
    return number(seconds) && seconds > 0 ? seconds : 0
}

// Whole minutes as hours and minutes; null when there is no time to show.
function timeParts(seconds) {
    if (!number(seconds) || seconds <= 0)
        return null
    var total = Math.round(seconds / 60)
    if (total <= 0)
        return null
    return { hours: Math.floor(total / 60), minutes: total % 60 }
}

// "1 h 20 min", with the strings of the current language. Empty parts are left
// out, so a whole hour reads "1 h".
function durationText(parts, strings) {
    if (!parts)
        return ""
    function text(key, value) {
        var found = (strings || {})[key]
        return found === undefined ? key : String(found).replace("%1", value)
    }
    var pieces = []
    if (parts.hours > 0)
        pieces.push(text("battery.hours", parts.hours))
    if (parts.minutes > 0)
        pieces.push(text("battery.minutes", parts.minutes))
    return pieces.join(" ")
}

// What the Bluetooth chip and its popup show. Without an adapter there is no
// chip at all; the count is of connected devices only.
function bluetoothInfo(state) {
    var data = state || {}
    var devices = Array.isArray(data.devices) ? data.devices : []
    var connected = devices.filter(function (one) {
        return !!one && one.connected === true
    })
    return {
        shown: data.available === true,
        powered: data.powered === true,
        connected: connected.length,
        badge: connected.length > 9 ? "9+" : (connected.length > 0 ? String(connected.length) : ""),
        device: connected.length > 0 ? connected[0] : null,
        paired: devices.filter(function (one) { return !!one && one.paired === true }),
        nearby: devices.filter(function (one) { return !!one && one.paired !== true })
    }
}
