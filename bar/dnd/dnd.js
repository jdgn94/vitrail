// The Do Not Disturb element's plain logic: the state the moon shows, the end
// of a timed silence, the durations of the popup and its allowed applications.
// The state itself is the notifications layer's own: `notificationDnd`,
// `notificationMuteUntil`, `notificationUrgentApps` and
// `notificationUrgentBypass`. Nothing is stored here. No QML type is touched,
// so tests/qml/tst_dnd.qml feeds it plain values.
.pragma library

var MINUTE = 60000
var DEFAULT_MINUTES = 60
// The durations of the popup; 0 means "until tomorrow" at TOMORROW_HOUR.
var DURATIONS = [30, 60, 0]
var TOMORROW_HOUR = 8

// The remembered duration (`dndDefaultMinutes`), or the built-in one.
function minutesOf(value) {
    if (value === undefined || value === null || value === "")
        return DEFAULT_MINUTES
    var number = Math.round(Number(value))
    if (!isFinite(number) || DURATIONS.indexOf(number) < 0)
        return DEFAULT_MINUTES
    return number
}

// Tomorrow at 08:00 local, the same moment a snoozed notification comes back.
function tomorrow(now) {
    var at = new Date(now)
    at.setDate(at.getDate() + 1)
    at.setHours(TOMORROW_HOUR, 0, 0, 0)
    return at.getTime()
}

// When a silence started now with this duration ends; 0 keeps no end.
function untilFor(minutes, now) {
    var value = minutesOf(minutes)
    return value > 0 ? now + value * MINUTE : tomorrow(now)
}

function untilValue(value) {
    var number = Number(value)
    return isFinite(number) && number > 0 ? number : 0
}

// What the moon and the popup say: off, on with an end, or on until turned
// off. An end that has passed already counts as off, even before the shell's
// timer has cleared the preference.
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

// The button's two lines: its state and the time left, then the applications
// whose notifications may still come through.
function summary(on, until, now, t) {
    var current = state(on, until, now)
    if (!current.on)
        return t("bar.dnd.off")
    if (current.timed)
        return t("bar.dnd.remaining").replace("%1", durationText(current.minutes, t))
    return t("bar.dnd.on")
}

function detail(apps, bypass, t) {
    if (!(bypass === true || bypass === "true"))
        return t("bar.dnd.bypassOff")
    var names = appList(apps)
    if (names.length === 0)
        return t("bar.dnd.noApps")
    return t("bar.dnd.allowed").replace("%1", names.join(", "))
}

// The label of one duration in the popup.
function durationLabel(minutes, t) {
    var value = minutesOf(minutes)
    if (value === 30)
        return t("bar.dnd.30m")
    if (value === 60)
        return t("bar.dnd.1h")
    return t("bar.dnd.tomorrow")
}

// `notificationUrgentApps` is one comma-separated preference. A comma in an
// application's name is rarer than a pipe, as in bar/notifications.
function appList(text) {
    var words = String(text || "").split(",")
    var out = []
    for (var i = 0; i < words.length; i++) {
        var word = words[i].trim()
        if (word !== "" && out.indexOf(word) < 0)
            out.push(word)
    }
    return out
}

function appsText(names) {
    var out = []
    for (var i = 0; i < names.length; i++) {
        var name = String(names[i] || "").trim()
        if (name !== "" && out.indexOf(name) < 0)
            out.push(name)
    }
    return out.join(",")
}

function withApp(text, name) {
    var names = appList(text)
    var value = String(name || "").trim()
    if (value !== "" && names.indexOf(value) < 0)
        names.push(value)
    return appsText(names)
}

function withoutApp(text, name) {
    return appsText(appList(text).filter(function (entry) {
        return entry !== String(name || "").trim()
    }))
}
