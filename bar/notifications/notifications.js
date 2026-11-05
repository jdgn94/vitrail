// Where notifications live: pure geometry-free rules, tested in
// tests/qml/tst_notifications.qml.
.pragma library

// The configured side, unless the bar owns it: notifications never open on the
// bar's edge. Legacy values ("top-right") are tolerated until the preference
// migration rewrites them to "left" / "right".
function sideFor(position, barEdge) {
    var text = String(position || "right")
    var want = text.indexOf("left") >= 0 ? "left" : "right"
    if (want === barEdge)
        return want === "left" ? "right" : "left"
    return want
}

// Toasts hang from the top of that side; the panel fills the whole height.
function stackPosition(position, barEdge) {
    return "top-" + sideFor(position, barEdge)
}

// A notification is listed but never raised as a toast while the panel is
// open, or while Do Not Disturb is on. Preferences arrive as booleans or as
// the strings the INI file holds, so both are read.
function enabled(value) {
    return value === true || value === "true"
}

// An app list is one preference, comma-separated ("Telegram Desktop|Discord"
// would need escaping; a comma in an app name is rarer than a pipe).
function list(text) {
    var words = String(text || "").split(",")
    var out = []
    for (var i = 0; i < words.length; i++) {
        var word = words[i].trim()
        if (word !== "" && out.indexOf(word) < 0)
            out.push(word)
    }
    return out
}

function joined(words) {
    var out = []
    for (var i = 0; i < words.length; i++) {
        var word = String(words[i]).trim()
        if (word !== "" && out.indexOf(word) < 0)
            out.push(word)
    }
    return out.join(",")
}

// Muted: listed, never toasted, whatever Do Not Disturb says.
function muted(appName, mutedText) {
    return list(mutedText).indexOf(appName) >= 0
}

// Urgent: the app asked for it (critical), or it is in the user's list.
function urgent(notification, urgentText) {
    if (!notification)
        return false
    if (notification.urgency !== undefined && notification.urgency >= 2)
        return true
    return list(urgentText).indexOf(notification.appName || "") >= 0
}

// The category hint freedesktop defines for instant messages and the chat
// apps whose notifications name the conversation in the summary.
var CHAT_APPS = ["Telegram Desktop", "Telegram", "Discord", "Signal", "WhatsApp", "Element",
                 "Slack", "Matrix", "Fractal", "Nheko", "Cinny", "Thunderbird"]

function messaging(notification) {
    if (!notification)
        return false
    var hints = notification.hints || {}
    var category = String(hints["category"] || "")
    if (category.indexOf("im.") === 0)
        return true
    return CHAT_APPS.indexOf(notification.appName || "") >= 0
}

// The conversation a notification belongs to: its own hint when the app sends
// one, else the summary (the chat's name in the apps above), else "".
function conversation(notification) {
    if (!notification)
        return ""
    var hints = notification.hints || {}
    var hinted = hints["x-vitrail-conversation"]
    if (hinted !== undefined && hinted !== null && String(hinted) !== "")
        return String(hinted)
    return messaging(notification) ? String(notification.summary || "") : ""
}

// A notification's image when it can still be drawn after the bar restarts.
// `image://qsimage/N/1` is a handle into this process's image provider: the
// next process answers "unknown handle", and the failing Image logs on every
// frame. A file or the icon provider survives.
function persistedImage(image) {
    var text = String(image || "")
    return text.indexOf("image://qsimage/") === 0 ? "" : text
}

// A body rendered as StyledText: its bare URLs become links, without touching
// the ones the app already wrapped (`onLinkActivated` opens them).
function linkify(text) {
    if (!text)
        return ""
    var parts = String(text).split(/(<a\s[^>]*>[\s\S]*?<\/a>)/i)
    for (var i = 0; i < parts.length; i++) {
        if (i % 2 === 1)  // the app's own anchor, kept as it is
            continue
        parts[i] = parts[i].replace(/(https?:\/\/[^\s<"']+)/g, function (url) {
            return '<a href="' + url + '">' + url + "</a>"
        })
    }
    return parts.join("")
}

// When a snooze comes back: 15 min, 1 h, or tomorrow at 08:00 (local).
function wakeTime(kind, now) {
    var at = new Date(now)
    if (kind === "15m")
        return at.getTime() + 15 * 60000
    if (kind === "1h")
        return at.getTime() + 60 * 60000
    at.setDate(at.getDate() + 1)
    at.setHours(8, 0, 0, 0)
    return at.getTime()
}

// The snoozed cards, as one JSON text in a preference.
function parseSnoozes(text) {
    var found
    try {
        found = JSON.parse(text || "[]")
    } catch (error) {
        found = []
    }
    if (!Array.isArray(found))
        return []
    return found.filter(function (one) {
        return one && typeof one === "object" && typeof one.until === "number"
    })
}

function addSnooze(text, row, until) {
    var found = parseSnoozes(text)
    found.push({ until: until, summary: row.summary || "", body: row.body || "",
                 appName: row.appName || "", icon: row.icon || "" })
    return JSON.stringify(found)
}

// The ones whose time is up, and what stays asleep.
function dueSnoozes(text, now) {
    var due = []
    var rest = []
    var found = parseSnoozes(text)
    for (var i = 0; i < found.length; i++)
        (found[i].until <= now ? due : rest).push(found[i])
    return { due: due, rest: JSON.stringify(rest) }
}

// The local day of a timestamp, as the stats key.
function dayOf(milliseconds) {
    var at = new Date(milliseconds)
    var two = function (number) { return (number < 10 ? "0" : "") + number }
    return at.getFullYear() + "-" + two(at.getMonth() + 1) + "-" + two(at.getDate())
}

// Per app, how many arrived and how many the user acted on today, from the
// queue's stats ({day: {app: [seen, acted]}}): the panel's small summary, so a
// noisy app can be muted with evidence.
function statsList(stats, now) {
    var today = dayOf(now)
    var day = (stats || {})[today] || {}
    var out = []
    for (var app in day) {
        if (!Array.isArray(day[app]))
            continue
        out.push({ app: app, seen: day[app][0] || 0, acted: day[app][1] || 0 })
    }
    out.sort(function (a, b) { return b.seen - a.seen || (a.app < b.app ? -1 : 1) })
    return out
}
