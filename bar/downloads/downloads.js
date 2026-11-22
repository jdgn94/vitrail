// The downloads element's plain logic: the aggregate percentage the button
// shows, the count and speed of its tooltip, and the rows of its popup. The
// snapshot comes from vitrail.downloads' `state` (a running download per
// entry, then the recent ones); a downloader that did not reserve its final
// size has no percentage, and none is invented — it says "measuring". No QML
// type is touched here, so tests/qml/tst_downloads.qml feeds it plain objects.
.pragma library

// How many finished downloads the popup keeps when the preference is absent,
// and the bounds the settings page offers.
var RECENT_DEFAULT = 5
var RECENT_MIN = 0
var RECENT_MAX = 20

// The snapshot carries both lists; anything else (the BarSnapshot's
// `{ error: "unreadable" }`) is an unavailable element.
function ready(snapshot) {
    return !!snapshot && Array.isArray(snapshot.active) && Array.isArray(snapshot.recent)
}

function active(snapshot) {
    return ready(snapshot) ? snapshot.active : []
}

function recent(snapshot, limit) {
    return ready(snapshot) ? snapshot.recent.slice(0, cap(limit)) : []
}

function cap(value) {
    if (value === undefined || value === null || value === "")
        return RECENT_DEFAULT
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return RECENT_DEFAULT
    return Math.max(RECENT_MIN, Math.min(RECENT_MAX, number))
}

// The percentage of one download, or -1 when its downloader never reserved a
// total. A zero total is unknown too: there is nothing to divide by.
function percentOf(item) {
    if (!item || typeof item.percent !== "number" || !isFinite(item.percent) || item.percent < 0)
        return -1
    return Math.max(0, Math.min(100, Math.round(item.percent)))
}

function known(item) {
    return percentOf(item) >= 0
}

// The button's percentage: the weighted mean of the running downloads, and
// only when every one of them knows its total. One unknown download makes the
// whole bar indeterminate, because the sum would be a guess.
function aggregate(snapshot) {
    var list = active(snapshot)
    if (list.length === 0)
        return -1
    var size = 0
    var total = 0
    for (var i = 0; i < list.length; i++) {
        if (!known(list[i]) || !(list[i].total > 0))
            return -1
        size += Number(list[i].size) || 0
        total += Number(list[i].total) || 0
    }
    if (total <= 0)
        return -1
    return Math.max(0, Math.min(100, Math.round(size * 100 / total)))
}

function totalSpeed(list) {
    var sum = 0
    for (var i = 0; i < (list || []).length; i++)
        sum += Math.max(0, Number(list[i].speed) || 0)
    return sum
}

// Bytes as a downloader prints them: 999 B, 1.0 KB, 12.4 MB (the same rule as
// vitrail/downloads.py's human_size, so the popup and the card agree).
function humanSize(bytes) {
    var units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var value = Math.max(0, Number(bytes) || 0)
    for (var i = 0; i < units.length; i++) {
        if (value < 1000 || i === units.length - 1)
            return i === 0 ? Math.round(value) + " B" : value.toFixed(1) + " " + units[i]
        value /= 1000
    }
    return "0 B"
}

// Seconds as a stopwatch: 0:07, 1:02:03.
function humanTime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var hours = Math.floor(total / 3600)
    var rest = total - hours * 3600
    var minutes = Math.floor(rest / 60)
    var secs = rest - minutes * 60
    return hours > 0 ? hours + ":" + (minutes < 10 ? "0" : "") + minutes
                            + ":" + (secs < 10 ? "0" : "") + secs
                     : minutes + ":" + (secs < 10 ? "0" : "") + secs
}

// What one running row says under its name: the size (of the total when the
// downloader reserved one), the speed, and the elapsed time.
function stats(item, t) {
    var parts = []
    if (known(item) && item.total > 0)
        parts.push(t("downloads.body.of").replace("%1", humanSize(item.size))
                                          .replace("%2", humanSize(item.total)))
    else
        parts.push(humanSize(item.size))
    if ((Number(item.speed) || 0) > 0)
        parts.push(t("downloads.speed").replace("%1", humanSize(item.speed)))
    parts.push(humanTime(item.elapsed))
    return parts.join(" · ")
}

function percentText(item) {
    var percent = percentOf(item)
    return percent < 0 ? "" : percent + "%"
}

// The words of a download that is being cancelled; "" for a running one.
function stateText(item, t) {
    return item && item.state === "cancelling" ? t("bar.downloads.cancelling") : ""
}

// The tooltip's title: the count and the total speed while something runs.
function title(snapshot, t) {
    if (!ready(snapshot))
        return t("bar.downloads.unavailable")
    var list = active(snapshot)
    if (list.length === 0)
        return t("bar.downloads.none")
    var speed = totalSpeed(list)
    if (list.length === 1)
        return speed > 0 ? t("bar.downloads.tooltip.one").replace("%1", humanSize(speed))
                         : t("bar.downloads.starting")
    return speed > 0 ? t("bar.downloads.tooltip").replace("%1", list.length)
                                                .replace("%2", humanSize(speed))
                     : t("bar.downloads.startingMany").replace("%1", list.length)
}

// The tooltip's second line: the file being written now.
function detail(snapshot) {
    var list = active(snapshot)
    return list.length > 0 ? String(list[0].name || "") : ""
}
