// The peripherals battery element's plain logic: which devices the bar and the
// popup watch, which one the bar shows, the glyph and the warning tone, and
// what a row says. vitrail.battery's snapshot supplies the devices; no QML type
// is touched here, so tests/qml/tst_battery.qml feeds it plain objects.
.pragma library

// The four icons UPower's peripheral kinds fold into (bar/devices' set).
var GLYPHS = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
              "battery_4_bar", "battery_5_bar", "battery_6_bar"]

// The kinds the user may hide, in the settings page's order. The snapshot says
// "headphones"; the setting calls the same thing a headset.
var HIDEABLE = ["mouse", "keyboard", "headphones", "gamepad"]
var ALIASES = { headset: "headphones" }

function ready(snapshot) {
    return !!snapshot && !snapshot.error && Array.isArray(snapshot.devices)
}

function kind(value) {
    var name = String(value || "").trim().toLowerCase()
    return ALIASES[name] || name
}

// The preference: one JSON array of kinds, compared without case. "headset"
// and "headphones" name the same kind, so either spelling in a hand-edited
// value hides it.
function parseHide(text) {
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
        if (typeof list[i] !== "string")
            continue
        var one = kind(list[i])
        if (one === "" || out.indexOf(one) >= 0)
            continue
        out.push(one)
    }
    return out
}

// The preference's text after `value` is hidden (or shown); the kind is stored
// in the snapshot's spelling.
function withKind(text, value, on) {
    var wanted = kind(value)
    var list = parseHide(text).filter(function (one) {
        return one !== wanted
    })
    if (on && wanted !== "")
        list.push(wanted)
    return JSON.stringify(list)
}

function hidden(device, list) {
    return !!device && (list || []).indexOf(kind(device.kind)) >= 0
}

// The devices the bar and the popup watch: the snapshot's, minus the kinds the
// user hid. A hidden device keeps the element out of the bar and off a row.
function watchedDevices(snapshot, hideText) {
    if (!ready(snapshot))
        return []
    var hide = parseHide(hideText)
    return snapshot.devices.filter(function (device) {
        return !hidden(device, hide)
    })
}

// A device's percentage as a whole number, or null when UPower has none.
function percentage(device) {
    if (!device || typeof device.percentage !== "number" || !isFinite(device.percentage))
        return null
    return Math.max(0, Math.min(100, Math.round(device.percentage)))
}

// "55%"; "--" when the device reports no percentage.
function percentText(device) {
    var value = percentage(device)
    return value === null ? "--" : value + "%"
}

// The lowest watched battery, with vitrail.battery's rule: the smallest
// discharging one wins even over a lower charging one; only when nothing
// discharges do charging, full and unknown devices compete. A percentage the
// snapshot marks null never competes.
function lowest(devices) {
    var known = (devices || []).filter(function (one) {
        return percentage(one) !== null
    })
    if (known.length === 0)
        return null
    var discharging = known.filter(function (one) {
        return one.state === "discharging"
    })
    var pool = discharging.length > 0 ? discharging : known
    var best = pool[0]
    for (var i = 1; i < pool.length; i++) {
        var one = pool[i]
        if (percentage(one) < percentage(best)
                || (percentage(one) === percentage(best)
                    && String(one.name).toLowerCase() < String(best.name).toLowerCase()))
            best = one
    }
    return best
}

// The battery glyph by level; the bolt while it fills, the full glyph near
// the top of the scale.
function glyph(device) {
    var value = percentage(device)
    if (value === null)
        return GLYPHS[0]
    if (device.state === "charging")
        return "battery_charging_full"
    if (value >= 95)
        return "battery_full"
    var step = Math.min(GLYPHS.length - 1, Math.max(0, Math.floor(value / 100 * GLYPHS.length)))
    return GLYPHS[step]
}

// The warning tone below the threshold; a charging device is filling, not in
// trouble, and a full one has nothing to warn about.
function tone(device, low) {
    if (!device)
        return "secondary"
    if (device.state === "charging")
        return "primary"
    var value = percentage(device)
    return value !== null && value < Number(low) ? "error" : "secondary"
}

// The glyph of a device kind. Anything UPower reports outside the four folds
// into the generic device glyph.
function kindGlyph(value) {
    var name = kind(value)
    if (name === "mouse" || name === "keyboard" || name === "headphones")
        return name
    if (name === "gamepad")
        return "sports_esports"
    return "devices"
}

// The tooltip's second line for several devices: every watched device but the
// one the bar names, as "WH-1000XM4 30% · Xbox Wireless Controller 80%".
function others(devices, best) {
    var out = []
    var list = devices || []
    for (var i = 0; i < list.length; i++) {
        if (list[i] === best)
            continue
        out.push(String(list[i].name) + " " + percentText(list[i]))
    }
    return out.join(" · ")
}

function translated(strings, key) {
    var value = (strings || {})[key]
    return value === undefined ? key : String(value)
}

// "Charging", "Discharging", "Full" or "Unknown state", translated.
function stateText(device, strings) {
    var state = device ? String(device.state || "") : ""
    var key = ["charging", "discharging", "full"].indexOf(state) >= 0 ? state : "unknown"
    return translated(strings, "bar.peripherals.state." + key)
}

// Whole minutes as hours and minutes, translated ("4 h 30 min").
function durationText(minutes, strings) {
    var total = Number(minutes)
    if (!isFinite(total) || total <= 0)
        return ""
    total = Math.round(total)
    var hours = Math.floor(total / 60)
    var rest = total % 60
    var pieces = []
    if (hours > 0)
        pieces.push(translated(strings, "battery.hours").replace("%1", hours))
    if (rest > 0)
        pieces.push(translated(strings, "battery.minutes").replace("%1", rest))
    return pieces.join(" ")
}

// "4 h 30 min left" while it discharges; empty when UPower does not know.
function timeLeft(device, strings) {
    if (!device || device.state !== "discharging")
        return ""
    var time = durationText(device.timeToEmpty, strings)
    return time === "" ? "" : translated(strings, "bar.peripherals.timeLeft").replace("%1", time)
}

// One row's state line: the state, and the time left when it is known.
function detailText(device, strings) {
    var parts = [stateText(device, strings)]
    var time = timeLeft(device, strings)
    if (time !== "")
        parts.push(time)
    return parts.join(" · ")
}
