// The notes bar element's plain logic: how many notes there are, the capped
// list its popup draws, each note's first line and its age. The store itself
// stays in notes.js (one preference, one format). Pure, tested in
// tests/qml/tst_notesbar.qml.
.pragma library
.import "notes.js" as Notes

// The popup keeps five notes unless `notesPopupMax` says otherwise; the store
// still caps at Notes.LIMIT, so the popup can never list more than it keeps.
var DEFAULT_CAP = 5

function cap(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        number = DEFAULT_CAP
    return Math.max(1, Math.min(Notes.LIMIT, number))
}

function count(text) {
    return Notes.entries(text).length
}

// The capped newest-first list, as `{ text, at }` entries.
function shown(text, value) {
    return Notes.entries(text).slice(0, cap(value))
}

// The list's first line: what a row is titled with.
function title(text) {
    var line = String(text || "").split("\n")[0].trim()
    return line
}

// "just now", "3 min ago", "2 h ago", "4 d ago"; a note written before ages
// were kept has no age and stays quiet.
function ageText(at, now, strings) {
    var moment = Number(at)
    if (!isFinite(moment) || moment <= 0)
        return ""
    var words = strings || ({})
    var seconds = Math.max(0, Math.floor((Number(now) - moment) / 1000))
    if (seconds < 60)
        return words["bar.notes.age.now"] || "just now"
    if (seconds < 3600)
        return (words["bar.notes.age.minutes"] || "%1 min ago").replace("%1", Math.floor(seconds / 60))
    if (seconds < 86400)
        return (words["bar.notes.age.hours"] || "%1 h ago").replace("%1", Math.floor(seconds / 3600))
    return (words["bar.notes.age.days"] || "%1 d ago").replace("%1", Math.floor(seconds / 86400))
}
