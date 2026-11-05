// What the bell says and what it shows: pure rules, tested in
// tests/qml/tst_notification_tooltip.qml.
.pragma library

// Why notifications are not sounding. `kind` grows as new causes are modelled
// (a scheduled silence, a focus mode); `describe` only has to learn one branch.
//   none   nothing silences them
//   dnd    Do Not Disturb is on, with no end
//   until  silenced until `until`, `minutes` still to go
//
// A timed silence that ran out is already over, even if the flag has not been
// cleared yet: the tooltip must not claim a silence that the clock ended.
function reason(prefs, now) {
    var data = prefs || {}
    var at = typeof now === "number" ? now : Date.now()
    var until = Number(data.notificationMuteUntil || 0)
    if (!isFinite(until) || until < 0)
        until = 0
    if (until > 0 && until <= at)
        return { muted: false, kind: "none", until: 0, minutes: 0 }
    if (until > at)
        return { muted: true, kind: "until", until: until,
                 minutes: Math.max(1, Math.ceil((until - at) / 60000)) }
    if (data.notificationDnd === true || data.notificationDnd === "true")
        return { muted: true, kind: "dnd", until: 0, minutes: 0 }
    return { muted: false, kind: "none", until: 0, minutes: 0 }
}

// The bell's two lines: the title, and the sentence that explains its state.
// An empty `strings` keeps the keys, so a missing translation never blanks it.
function describe(prefs, now, strings, count) {
    var table = strings || {}
    var state = reason(prefs, now)
    var total = Number(count) || 0
    var detail
    if (state.kind === "until")
        detail = fill(word(table, "tooltip.notificationsSilentUntil"),
                      [clock(state.until), state.minutes])
    else if (state.kind === "dnd")
        detail = word(table, "tooltip.notificationsMuted")
    else if (total > 0)
        detail = fill(word(table, "tooltip.notificationsCount"), [total])
    else
        detail = word(table, "tooltip.notificationsHint")
    return { muted: state.muted, kind: state.kind, until: state.until,
             minutes: state.minutes, title: word(table, "tooltip.notifications"),
             text: detail }
}

// The badge's label: the count up to `cap` (9), then "9+"; empty at zero, so
// the badge simply hides itself.
function badge(count, cap) {
    var number = Math.floor(Number(count))
    if (!isFinite(number) || number <= 0)
        return ""
    var most = Math.floor(Number(cap))
    if (!isFinite(most) || most < 1)
        most = 9
    return number > most ? most + "+" : String(number)
}

// A timestamp as the wall clock the bar shows: HH:MM, local.
function clock(milliseconds) {
    var at = new Date(milliseconds)
    var two = function (number) { return (number < 10 ? "0" : "") + number }
    return two(at.getHours()) + ":" + two(at.getMinutes())
}

function word(table, key) {
    var value = table[key]
    return typeof value === "string" && value !== "" ? value : key
}

// "%1" and "%2" from `values`, in order; a placeholder with no value stays.
function fill(template, values) {
    return String(template).replace(/%(\d+)/g, function (match, index) {
        var value = values[Number(index) - 1]
        return value === undefined ? match : String(value)
    })
}
