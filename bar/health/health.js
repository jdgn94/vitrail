// The health element's plain logic: the problem list (the snapshot's plus the
// bar's own load failures), the worst severity, the tone it maps to, and the
// words of one problem. vitrail.health gives codes and data, never words; the
// words are translated here from the problem's id. No QML type is touched, so
// tests/qml/tst_health.qml feeds it plain objects.
.pragma library

// The id of the problem the shell adds when one of its own bar elements failed
// to load (vitrail.health.BAR_ID). The module never emits it.
var BAR_ID = "bar"
// How many problems the popup lists before it scrolls.
var ROW_LIMIT = 6
// The check names `healthChecks` holds, in the settings page's order.
var CHECKS = ["services", "disk", "hyprland", "doctor"]
// The disk threshold range (percent) and its default.
var THRESHOLD_MIN = 1
var THRESHOLD_MAX = 50
var THRESHOLD_DEFAULT = 5
// The first line of a service problem's detail is the module's English prefix.
var SERVICE_PREFIX = /^(user|system) service failed(?:: )?/
var DISK_DETAIL = /^([\d.]+)% free \((.+) of (.+)\)$/

function ready(snapshot) {
    return !!snapshot && !snapshot.error && Array.isArray(snapshot.problems)
}

// The bar's own failure as a problem. `failed` is the element ids whose
// component did not load; the detail is those ids (data, not words).
function barProblem(failed) {
    return { id: BAR_ID, severity: "error", title: BAR_ID, detail: failed.join(", "), fix: null, logs: null }
}

// The snapshot's problems, then the bar's own when some element failed.
function problems(snapshot, failed) {
    var list = ready(snapshot) ? snapshot.problems.slice() : []
    if (Array.isArray(failed) && failed.length > 0)
        list.push(barProblem(failed))
    return list
}

// "error" when any problem is one, "warning" when only warnings are left, ""
// for a clean list.
function worst(list) {
    var found = ""
    for (var i = 0; i < list.length; i++) {
        if (list[i].severity === "error")
            return "error"
        found = "warning"
    }
    return found
}

// The button's tone for a severity. The kit has no warning colour family, so
// a warning takes the `info` one and an error the `error` one.
function tone(severity) {
    return severity === "error" ? "error" : severity === "warning" ? "info" : "secondary"
}

// The glyph: a warning triangle, the calm tick when there is nothing wrong.
function icon(count) {
    return count > 0 ? "warning" : "task_alt"
}

// The button's text: the count, nothing for a single problem.
function countText(count) {
    return count > 1 ? String(count) : ""
}

// The element is active while there is something to report.
function active(count) {
    return count > 0
}

// The part of an id before the first colon: the check that found it.
function kind(id) {
    var text = String(id || "")
    var at = text.indexOf(":")
    return at < 0 ? text : text.slice(0, at)
}

// The part after it: the unit, the mount point, the config.
function subject(id) {
    var text = String(id || "")
    var at = text.indexOf(":")
    return at < 0 ? "" : text.slice(at + 1)
}

var KINDS = ["service-user", "service-system", "disk", "hyprland", "doctor", "bar"]

// The translation key of a problem's title; an id this build does not know
// still gets a translated, generic title.
function titleKey(problem) {
    var name = kind(problem.id)
    return "bar.health.title." + (KINDS.indexOf(name) >= 0 ? name : "unknown")
}

// A problem's title, in the user's language. `t` is the element's translator.
function title(problem, t) {
    return t(titleKey(problem)).replace("%1", subject(problem.id))
}

// A problem's second line. The module's English frame is replaced; what is
// data (a unit's description, a config error, the doctor's report) stays.
function detail(problem, t) {
    var text = String(problem.detail || "")
    var name = kind(problem.id)
    if (name === "service-user" || name === "service-system")
        return text.replace(SERVICE_PREFIX, "")
    if (name === "disk") {
        var found = DISK_DETAIL.exec(text)
        return found ? t("bar.health.disk.detail").replace("%1", found[1]).replace("%2", found[2])
                                                   .replace("%3", found[3])
                     : text
    }
    return text
}

// The tooltip's second line: the other problems, or "and N more".
function more(count, t) {
    return count > 1 ? t("bar.health.more").replace("%1", count - 1) : ""
}

// An argv as a real array of strings, or [] when there is none. A list read
// through a Repeater's modelData is a sequence wrapper, not a JS array
// (Array.isArray is false), so the argv is copied before anything tests it or
// hands it on (Commands.runInTerminal needs a true array).
function argv(value) {
    if (value === null || value === undefined || typeof value !== "object" || !(value.length > 0))
        return []
    var out = []
    for (var i = 0; i < value.length; i++)
        out.push(String(value[i]))
    return out
}

function hasArgv(value) {
    return argv(value).length > 0
}

// The checks `healthChecks` holds; a key never written means all of them, an
// explicit "[]" none.
function enabledChecks(text) {
    if (text === undefined || text === null)
        return CHECKS.slice()
    var list = []
    try {
        list = JSON.parse(String(text))
    } catch (error) {
        return CHECKS.slice()
    }
    if (!Array.isArray(list))
        return CHECKS.slice()
    return CHECKS.filter(function (name) { return list.indexOf(name) >= 0 })
}

// The preference's text after `name` is turned on or off.
function withCheck(text, name, on) {
    var list = enabledChecks(text).filter(function (entry) { return entry !== name })
    if (on && CHECKS.indexOf(name) >= 0)
        list.push(name)
    return JSON.stringify(CHECKS.filter(function (entry) { return list.indexOf(entry) >= 0 }))
}

// The threshold (percent) the settings page shows, clamped.
function threshold(value) {
    var number = Number(value)
    if (!isFinite(number) || value === "" || value === undefined || value === null)
        return THRESHOLD_DEFAULT
    return Math.min(Math.max(Math.round(number), THRESHOLD_MIN), THRESHOLD_MAX)
}
