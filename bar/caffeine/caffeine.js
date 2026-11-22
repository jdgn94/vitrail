// The caffeine element's plain logic: the state the cup shows, the end of a
// timed inhibitor, the durations of the popup and what the IdleInhibitor
// reports. The inhibitor itself lives in bar/shell.qml; no state is written to
// disk (caffeine is session state). No QML type is touched here, so
// tests/qml/tst_caffeine.qml feeds it plain values.
.pragma library

var MINUTE = 60000
var DEFAULT_MINUTES = 30
// The durations of the popup; 0 means "until turned off".
var DURATIONS = [15, 30, 60, 0]

// The remembered duration (`caffeineMinutes`), or the built-in one.
function minutesOf(value) {
    if (value === undefined || value === null || value === "")
        return DEFAULT_MINUTES
    var number = Math.round(Number(value))
    if (!isFinite(number) || DURATIONS.indexOf(number) < 0)
        return DEFAULT_MINUTES
    return number
}

// When an inhibitor started now with this duration ends; 0 keeps no end.
function untilFor(minutes, now) {
    var value = minutesOf(minutes)
    return value > 0 ? now + value * MINUTE : 0
}

function untilValue(value) {
    var number = Number(value)
    return isFinite(number) && number > 0 ? number : 0
}

// What the cup and the popup say. An end that has passed already counts as
// off, even before the shell's timer has stopped the inhibitor.
function state(on, until, now) {
    var at = typeof now === "number" ? now : Date.now()
    var wanted = on === true || on === "true"
    var end = untilValue(until)
    if (!wanted)
        return { on: false, until: 0, minutes: 0, timed: false }
    if (end > 0 && end <= at)
        return { on: false, until: 0, minutes: 0, timed: false }
    if (end > at)
        return { on: true, until: end, minutes: Math.max(1, Math.ceil((end - at) / MINUTE)), timed: true }
    return { on: true, until: 0, minutes: 0, timed: false }
}

// Minutes as a short duration: "25 min", "1 h", "1 h 30 min".
function durationText(minutes, t) {
    var total = Math.max(1, Math.round(Number(minutes) || 0))
    if (total < 60)
        return t("bar.duration.minutes").replace("%1", total)
    var hours = Math.floor(total / 60)
    var rest = total - hours * 60
    if (rest === 0)
        return t("bar.duration.hours").replace("%1", hours)
    return t("bar.duration.hoursMinutes").replace("%1", hours).replace("%2", rest)
}

// The button's two lines: its state and the time left, then what the
// inhibitor is doing.
function summary(on, until, now, t) {
    var current = state(on, until, now)
    if (!current.on)
        return t("bar.caffeine.off")
    if (current.timed)
        return t("bar.caffeine.remaining").replace("%1", durationText(current.minutes, t))
    return t("bar.caffeine.untilOff")
}

function detail(inhibiting, t) {
    return inhibiting === true || inhibiting === "true"
           ? t("bar.caffeine.inhibitorOn")
           : t("bar.caffeine.inhibitorOff")
}

// The label of one duration in the popup.
function durationLabel(minutes, t) {
    var value = minutesOf(minutes)
    if (value === 15)
        return t("bar.caffeine.15m")
    if (value === 30)
        return t("bar.caffeine.30m")
    if (value === 60)
        return t("bar.caffeine.1h")
    return t("bar.caffeine.untilOff")
}
