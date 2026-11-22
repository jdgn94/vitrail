// The brightness element's plain logic: the button's face and its wheel step,
// one popup row per monitor (with the reason a monitor cannot be read), and
// the night light's schedule document. The brightness arithmetic itself is the
// OSD's (`bar/osd/brightness.js`), so a wheel notch moves a display exactly as
// the media key does. No QML type is touched here, so tests/qml/tst_brightness.qml
// feeds it plain objects.
.pragma library
.import "../osd/brightness.js" as Light
.import "../osd/icons.js" as Icons

// The wheel step is a preference; keep it a whole percent between 1 and 20
// and fall back to 5 for anything else.
var STEP_MIN = 1
var STEP_MAX = 20
var STEP_DEFAULT = 5

// The night light's public range and its fallback. These mirror
// vitrail/nightlight.py, which owns the rule; the slider only draws them.
var TEMPERATURE_MIN = 1000
var TEMPERATURE_MAX = 10000
var TEMPERATURE_STEP = 100
var TEMPERATURE_DEFAULT = 4000
var DEFAULT_START = "20:00"
var DEFAULT_END = "07:00"
var MODES = ["off", "fixed", "sun"]

// The internal connectors, as vitrail/brightness.py names them.
var INTERNAL = ["eDP", "LVDS", "DSI"]

function step(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return STEP_DEFAULT
    return Math.max(STEP_MIN, Math.min(STEP_MAX, number))
}

function temperature(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return TEMPERATURE_DEFAULT
    return Math.max(TEMPERATURE_MIN, Math.min(TEMPERATURE_MAX, number))
}

// A snapshot the element can draw: `status` and `devices` as
// `vitrail brightness list` prints them; anything else is unavailable.
function ready(snapshot) {
    return !!snapshot && Array.isArray(snapshot.devices) && !snapshot.error
}

function devices(snapshot) {
    return ready(snapshot) ? snapshot.devices : []
}

function device(snapshot, name) {
    var list = devices(snapshot)
    for (var i = 0; i < list.length; i++) {
        if (String(list[i].name) === String(name))
            return list[i]
    }
    return null
}

// The monitor the wheel moves: the primary output, else the first one Vitrail
// can dim.
function primary(snapshot, name) {
    return device(snapshot, name) || devices(snapshot)[0] || null
}

function icon(target) {
    return Icons.brightness(target ? target.percent / 100 : 0)
}

// One wheel event on the button: the signed percent the primary monitor moves
// by (`delta` is Qt's angleDelta.y), or null when there is nothing to move.
function wheelTarget(snapshot, name, delta, stepValue) {
    var target = primary(snapshot, name)
    var amount = Number(delta)
    if (!target || !isFinite(amount) || amount === 0)
        return null
    // Qt reports 120 per notch; a smooth wheel's smaller delta still moves one
    // step, and a fast spin moves one step per notch.
    var notches = Math.max(1, Math.round(Math.abs(amount) / 120))
    var direction = amount > 0 ? 1 : -1
    return { name: target.name, percent: Light.step(target.percent, direction, step(stepValue) * notches) }
}

function internal(name) {
    for (var i = 0; i < INTERNAL.length; i++) {
        if (String(name || "").indexOf(INTERNAL[i]) === 0)
            return true
    }
    return false
}

// Why a monitor is not in the snapshot, as an i18n key. The status comes from
// vitrail/brightness.py; `ok` with no device means that one display did not
// answer (a DDC/CI monitor, or an internal panel with no backlight).
function reasonFor(snapshot, name) {
    var status = snapshot ? String(snapshot.status || "") : ""
    if (status === "access")
        return "osd.brightnessAccess"
    if (status === "missing")
        return "osd.brightnessMissing"
    if (status === "loading")
        return "osd.brightnessLoading"
    if (status === "none")
        return "osd.brightnessNone"
    if (snapshot && snapshot.error)
        return "bar.brightness.unreadable"
    return internal(name) ? "bar.brightness.reason.backlight" : "bar.brightness.reason.ddc"
}

// One row per monitor Hyprland reports. A readable monitor carries its
// percentage; an unreadable one carries the reason instead, so the popup never
// draws a slider that cannot move.
function rowFor(snapshot, name) {
    var target = device(snapshot, name)
    if (target)
        return { name: String(name), readable: true, percent: target.percent }
    return { name: String(name), readable: false, reason: reasonFor(snapshot, name) }
}

function rows(snapshot, screens) {
    var names = Array.isArray(screens) ? screens : []
    if (names.length === 0) {
        return devices(snapshot).map(function (target) {
            return { name: String(target.name), readable: true, percent: target.percent }
        })
    }
    return names.map(function (name) { return rowFor(snapshot, name) })
}

// The schedule preference: one JSON document with the mode and the fixed hours
// (the fallback for sun mode when the weather has no sun times).
function scheduleOf(text) {
    var value = null
    try {
        value = typeof text === "string" ? JSON.parse(text) : text
    } catch (error) {
        value = null
    }
    var source = value && typeof value === "object" && !Array.isArray(value) ? value : {}
    var mode = MODES.indexOf(source.mode) >= 0 ? source.mode : "off"
    return {
        mode: mode,
        start: clock(source.start) || DEFAULT_START,
        end: clock(source.end) || DEFAULT_END
    }
}

// `HH:MM` in a day, or null. Kept here so the settings fields reject a typo
// before it becomes a preference.
function clock(value) {
    var text = String(value === undefined || value === null ? "" : value).trim()
    var match = /^(\d{1,2}):(\d{2})$/.exec(text)
    if (!match)
        return null
    var hour = Number(match[1])
    var minute = Number(match[2])
    if (hour > 23 || minute > 59)
        return null
    return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
}

function withMode(text, mode) {
    var schedule = scheduleOf(text)
    schedule.mode = MODES.indexOf(mode) >= 0 ? mode : "off"
    return JSON.stringify(schedule)
}

// `which` is "start" or "end"; an invalid clock leaves the preference alone
// and returns its text, so the caller can keep the field's error state.
function withTime(text, which, value) {
    var schedule = scheduleOf(text)
    var when = clock(value)
    if (when === null || (which !== "start" && which !== "end"))
        return JSON.stringify(schedule)
    schedule[which] = when
    return JSON.stringify(schedule)
}

// The next change the module computed (`state.next`), in the popup's words.
function nextText(next, strings) {
    if (!next || !next.at)
        return ""
    var key = next.active ? "bar.brightness.next.on" : "bar.brightness.next.off"
    var words = (strings || ({}))[key]
    return (words === undefined ? key : words).replace("%1", next.at)
}

// Sunset/sunrise when the weather snapshot carried them; "" otherwise.
function sunText(schedule, strings) {
    if (!schedule || !schedule.sunrise || !schedule.sunset)
        return ""
    var words = (strings || ({}))["bar.brightness.sunTimes"]
    return (words === undefined ? "bar.brightness.sunTimes" : words)
        .replace("%1", schedule.sunset)
        .replace("%2", schedule.sunrise)
}
