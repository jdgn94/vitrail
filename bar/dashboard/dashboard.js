// The dashboard's numbers and states: pure, so they are tested without a
// window or a process (tests/qml/tst_dashboard.qml).

// The dashboard's widgets, in the built-in order. `dashboardWidgets` keeps the
// keys the popup shows, in their order; a missing, empty or unreadable value
// means every widget here, so an upgrade never leaves the popup bare.
var DASHBOARD_WIDGETS = [
    { key: "calendar", icon: "calendar_month" },
    { key: "weather", icon: "partly_cloudy_day" },
    { key: "performance", icon: "monitoring" },
    { key: "focus", icon: "timer" },
    { key: "media", icon: "music_note" }
]

function allWidgets() {
    return DASHBOARD_WIDGETS.map(function (widget) { return widget.key })
}

function widgetSpec(key) {
    for (var i = 0; i < DASHBOARD_WIDGETS.length; i++) {
        if (DASHBOARD_WIDGETS[i].key === key)
            return DASHBOARD_WIDGETS[i]
    }
    return null
}

function widgetIcon(key) {
    var spec = widgetSpec(key)
    return spec === null ? "widgets" : spec.icon
}

// The keys the preference shows: known ones only, duplicates dropped and the
// order kept. Anything that leaves no key shows every widget.
function shownWidgets(text) {
    var all = allWidgets()
    var keys = []
    var value = null
    try {
        value = JSON.parse(String(text === undefined || text === null ? "" : text))
    } catch (error) {
        value = null
    }
    if (Array.isArray(value)) {
        for (var i = 0; i < value.length; i++) {
            var key = String(value[i])
            if (all.indexOf(key) >= 0 && keys.indexOf(key) < 0)
                keys.push(key)
        }
    }
    return keys.length > 0 ? keys : all
}

function shownCount(text) {
    return shownWidgets(text).length
}

// The section's rows: the shown widgets in their order, then the hidden ones
// in the built-in order (they have no order of their own until shown again).
function widgetRows(text) {
    var shown = shownWidgets(text)
    var rows = []
    var i
    for (i = 0; i < shown.length; i++) {
        rows.push({ key: shown[i], shown: true,
                    canUp: i > 0, canDown: i < shown.length - 1 })
    }
    var all = allWidgets()
    for (i = 0; i < all.length; i++) {
        if (shown.indexOf(all[i]) < 0)
            rows.push({ key: all[i], shown: false, canUp: false, canDown: false })
    }
    return rows
}

// The preference with one widget shown (added at the end) or hidden.
function withWidget(text, key, shown) {
    var keys = shownWidgets(text)
    var at = keys.indexOf(key)
    if (shown && at < 0)
        keys.push(key)
    else if (!shown && at >= 0)
        keys.splice(at, 1)
    return JSON.stringify(keys)
}

// The preference with one shown widget moved by `step` places (-1 up, 1 down).
function moveWidget(text, key, step) {
    var keys = shownWidgets(text)
    var at = keys.indexOf(key)
    var to = at + step
    if (at < 0 || to < 0 || to >= keys.length)
        return text
    keys[at] = keys[to]
    keys[to] = key
    return JSON.stringify(keys)
}

// The JSON one of the services printed, or an empty state. A broken answer
// (offline, a partial write) never takes the panel down.
function parse(text) {
    var value = null
    try {
        value = JSON.parse(String(text || ""))
    } catch (error) {
        return ({})
    }
    return value !== null && typeof value === "object" ? value : ({})
}

// 42.6 -> "43%"; missing or unreadable values are absent, never 0.
function percent(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number))
        return "--"
    return Math.round(Math.max(0, Math.min(100, number))) + "%"
}

// Bytes in the unit a person reads: 1536 -> "1.5 KB".
function bytes(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number) || number < 0)
        return "--"
    var units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var index = 0
    while (number >= 1024 && index < units.length - 1) {
        number /= 1024
        index += 1
    }
    return (index === 0 ? String(Math.round(number)) : number.toFixed(1)) + " " + units[index]
}

// A temperature with the service's own unit: 18.4, "°C" -> "18 °C".
function temperature(value, unit) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    if (!isFinite(number))
        return "--"
    return Math.round(number) + " " + (unit || "°")
}

// A day's high and low, without repeating the unit: "21° / 10°".
function degrees(value) {
    if (value === null || value === undefined || value === "")
        return "--"
    var number = Number(value)
    return isFinite(number) ? Math.round(number) + "°" : "--"
}

// The words for a WMO code in the user's language (weather.code.<n>); the
// service's English falls back for a code the table does not name.
function condition(strings, code, fallback) {
    var table = strings || ({})
    var text = table["weather.code." + Number(code)]
    return text === undefined || text === "" ? (fallback || "") : text
}

// An ISO day ("2026-11-04") as the locale's short weekday ("Wed").
function weekday(iso, language) {
    var date = new Date(String(iso || "") + "T12:00:00")
    if (isNaN(date.getTime()))
        return String(iso || "")
    return date.toLocaleDateString(Qt.locale(language || "en"), "ddd")
}

// "used / total · percent" for memory and disk.
function usage(part) {
    if (!part || typeof part !== "object")
        return "--"
    return bytes(part.used) + " / " + bytes(part.total) + " · " + percent(part.percent)
}

// What has gone through the network since boot.
function network(part) {
    if (!part || typeof part !== "object")
        return "--"
    return "↓ " + bytes(part.rx) + "  ↑ " + bytes(part.tx)
}
