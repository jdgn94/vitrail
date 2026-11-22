// The weather element's plain logic: what the button shows, the WMO code to
// condition glyph mapping, the hourly and daily slices of the popup, and the
// city/interval preferences. The formatting helpers are the dashboard's own
// (bar/dashboard/dashboard.js), so the bar and the desktop widget cannot drift.
.pragma library
.import "../dashboard/dashboard.js" as Dash

// Open-Meteo's WMO codes, in the groups the icons distinguish.
var ICONS = {
    0: "sunny",
    1: "partly_cloudy_day",
    2: "partly_cloudy_day",
    3: "cloud",
    45: "foggy",
    48: "foggy",
    51: "rainy",
    53: "rainy",
    55: "rainy",
    56: "rainy",
    57: "rainy",
    61: "rainy",
    63: "rainy",
    65: "rainy",
    66: "rainy",
    67: "rainy",
    71: "weather_snowy",
    73: "weather_snowy",
    75: "weather_snowy",
    77: "weather_snowy",
    80: "rainy",
    81: "rainy",
    82: "rainy",
    85: "weather_snowy",
    86: "weather_snowy",
    95: "thunderstorm",
    96: "thunderstorm",
    99: "thunderstorm"
}
var DEFAULT_ICON = "partly_cloudy_day"
var DAYS_SHOWN = 5
// The refresh interval (`weatherInterval`), in whole minutes.
var INTERVAL_MIN = 5
var INTERVAL_MAX = 720
var INTERVAL_DEFAULT = 15
var MINUTE = 60000

function current(snapshot) {
    var now = (snapshot || ({})).current
    return now && typeof now === "object" ? now : ({})
}

function units(snapshot) {
    var table = (snapshot || ({})).units
    return {
        temperature: table && table.temperature ? table.temperature : "°",
        humidity: table && table.humidity ? table.humidity : "%",
        wind: table && table.wind ? table.wind : ""
    }
}

// A snapshot the button can draw: a number right now, not a stale word.
function ready(snapshot) {
    var value = current(snapshot).temperature
    return typeof value === "number" && isFinite(value)
}

function iconOf(code) {
    var icon = ICONS[Number(code)]
    return icon === undefined ? DEFAULT_ICON : icon
}

// The dashboard's own mapping, shared rather than copied.
function condition(strings, code, fallback) {
    return Dash.condition(strings, code, fallback)
}

function weekday(iso, language) {
    return Dash.weekday(iso, language)
}

function hours(snapshot) {
    var list = (snapshot || ({})).hourly
    return Array.isArray(list) ? list : []
}

function days(snapshot, count) {
    var list = (snapshot || ({})).daily
    if (!Array.isArray(list))
        return []
    return list.slice(0, count || DAYS_SHOWN)
}

function today(snapshot) {
    var list = days(snapshot, 1)
    return list.length > 0 ? list[0] : ({})
}

// "2026-11-04T15:00" -> "15:00"; anything else has no hour to name.
function hourLabel(iso) {
    var text = String(iso || "")
    if (text.indexOf("T") < 0)
        return ""
    var clock = text.split("T").pop().slice(0, 5)
    return /^\d{2}:\d{2}$/.test(clock) ? clock : ""
}

function highLow(snapshot) {
    var first = today(snapshot)
    return {
        high: first.high === undefined ? null : first.high,
        low: first.low === undefined ? null : first.low
    }
}

// The wind line, or "" when the answer has no wind (the row then leaves).
function wind(snapshot) {
    var value = current(snapshot).wind
    if (value === null || value === undefined || value === "" || !isFinite(Number(value)))
        return ""
    var unit = units(snapshot).wind
    return Math.round(Number(value)) + (unit === "" ? "" : " " + unit)
}

// The configured cities, one JSON array of names. An empty or broken value
// follows the city of the snapshot, which is the module's own default.
function cities(text, currentCity) {
    var list = []
    try {
        list = JSON.parse(String(text || "[]"))
    } catch (error) {
        list = []
    }
    var out = []
    if (Array.isArray(list)) {
        for (var i = 0; i < list.length; i++) {
            var name = typeof list[i] === "string" ? list[i].trim() : ""
            if (name !== "" && out.indexOf(name) < 0)
                out.push(name)
        }
    }
    var now = String(currentCity || "").trim()
    if (out.length === 0 && now !== "")
        out.push(now)
    else if (now !== "" && out.indexOf(now) < 0)
        out.unshift(now)
    return out
}

function withCities(names) {
    var out = []
    for (var i = 0; i < (names || []).length; i++) {
        var name = typeof names[i] === "string" ? names[i].trim() : ""
        if (name !== "" && out.indexOf(name) < 0)
            out.push(name)
    }
    return JSON.stringify(out)
}

// The city switcher's options: the snapshot's city first (the live one), then
// every configured city, each once.
function cityOptions(text, currentCity) {
    return cities(text, currentCity).map(function (name) {
        return { key: name, label: name }
    })
}

function intervalMinutes(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return INTERVAL_DEFAULT
    return Math.max(INTERVAL_MIN, Math.min(INTERVAL_MAX, number))
}

// What BarSnapshot polls with.
function intervalMs(value) {
    return intervalMinutes(value) * MINUTE
}
