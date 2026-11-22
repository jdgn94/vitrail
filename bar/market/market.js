// The market element's plain logic: the price with its currency, the day's
// change (sign, arrow and tone), the age of the data, the symbol list and the
// CoinGecko command. No QML type is touched here, so tests/qml/tst_market.qml
// feeds it plain objects.

.pragma library

// The currencies the popup offers, matching vitrail.market.CURRENCIES. The
// module accepts any CoinGecko code; these are the ones the element names, in
// the order the chooser lists them.
var CURRENCIES = ["eur", "usd"]
var CURRENCY_SYMBOLS = { eur: "€", usd: "$" }
var CURRENCY_DEFAULT = "eur"

// The poll intervals (minutes). The floor is vitrail.market's cache window:
// asking more often than that can only return the cache, so the element never
// makes CoinGecko pay for a poll it already answered.
var INTERVALS = [5, 15, 30, 60, 120, 360, 720]
var INTERVAL_MIN = 5
var INTERVAL_MAX = 720
var INTERVAL_DEFAULT = 15
var MINUTE = 60000

var SYMBOL_DEFAULT = ["bitcoin"]

function currencyOf(value) {
    var code = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return CURRENCIES.indexOf(code) >= 0 ? code : CURRENCY_DEFAULT
}

function currencyOptions() {
    return CURRENCIES.map(function (code) { return { key: code, label: code.toUpperCase() } })
}

// 78420.1 in eur -> "€78,420.10"; a sub-cent coin keeps enough digits to be
// useful, and a missing price is a dash rather than a zero.
function formatPrice(value, currency) {
    var number = Number(value)
    if (value === null || value === undefined || !isFinite(number))
        return "—"
    var decimals = number === 0 ? 2 : Math.abs(number) >= 1 ? 2 : Math.abs(number) >= 0.01 ? 4 : 6
    var fixed = Math.abs(number).toFixed(decimals)
    var parts = fixed.split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    var sign = number < 0 ? "-" : ""
    return sign + (CURRENCY_SYMBOLS[currencyOf(currency)] || currencyOf(currency).toUpperCase() + " ")
                + parts.join(".")
}

// The day's change as the popup and the tooltip write it.
function changeText(value) {
    var number = Number(value)
    if (value === null || value === undefined || !isFinite(number))
        return "—"
    var sign = number > 0 ? "+" : number < 0 ? "-" : ""
    return sign + Math.abs(number).toFixed(2) + "%"
}

function trend(value) {
    var number = Number(value)
    if (!isFinite(number) || number === 0)
        return "flat"
    return number > 0 ? "up" : "down"
}

function arrow(value) {
    var direction = trend(value)
    return direction === "up" ? "arrow_upward"
         : direction === "down" ? "arrow_downward" : "remove"
}

// A BarElementBase tone family (primary / error / secondary).
function tone(value) {
    var direction = trend(value)
    return direction === "up" ? "primary" : direction === "down" ? "error" : "secondary"
}

// A palette role for a sparkline or a change label (the kit has no
// "secondary" role; a flat change is muted).
function colorToken(value) {
    var direction = trend(value)
    return direction === "up" ? "primary" : direction === "down" ? "error" : "muted"
}

function priceList(snapshot) {
    return snapshot && Array.isArray(snapshot.prices) ? snapshot.prices : []
}

function errorOf(snapshot) {
    return snapshot && snapshot.error !== undefined && snapshot.error !== null
           ? String(snapshot.error) : ""
}

function priceOf(snapshot, id) {
    var list = priceList(snapshot)
    for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === id)
            return list[i]
    }
    return null
}

// The configured symbols, in the user's order: one JSON array of CoinGecko
// ids. An unset or unreadable preference keeps bitcoin; an explicit empty
// array means the element has no chosen symbol.
function symbolsOf(text) {
    if (text === undefined || text === null || text === "")
        return SYMBOL_DEFAULT.slice()
    var list = null
    try {
        list = JSON.parse(String(text))
    } catch (error) {
        return SYMBOL_DEFAULT.slice()
    }
    if (!Array.isArray(list))
        return SYMBOL_DEFAULT.slice()
    var out = []
    for (var i = 0; i < list.length; i++) {
        var id = normalizeSymbol(list[i])
        if (id !== "" && out.indexOf(id) < 0)
            out.push(id)
    }
    return out
}

// A CoinGecko id: lower case letters, digits and hyphens ("avalanche-2").
function normalizeSymbol(value) {
    var id = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return /^[a-z0-9][a-z0-9-]*$/.test(id) ? id : ""
}

function withSymbol(text, id, on) {
    var list = symbolsOf(text)
    var symbol = normalizeSymbol(id)
    var at = list.indexOf(symbol)
    if (on && symbol !== "" && at < 0)
        list.push(symbol)
    else if (!on && at >= 0)
        list.splice(at, 1)
    return JSON.stringify(list)
}

// The price the bar shows: the first chosen symbol that has one, or the first
// price the snapshot carries when the first id is unknown.
function priceFor(snapshot, text) {
    var list = priceList(snapshot)
    if (list.length === 0)
        return null
    var ids = symbolsOf(text)
    for (var i = 0; i < ids.length; i++) {
        var found = priceOf(snapshot, ids[i])
        if (found)
            return found
    }
    return list[0]
}

// One entry per chosen symbol, in the user's order; a symbol the answer does
// not carry is still a row (a wrong id must be visible, not silent).
function rows(snapshot, text) {
    var ids = symbolsOf(text)
    var out = []
    for (var i = 0; i < ids.length; i++)
        out.push({ id: ids[i], price: priceOf(snapshot, ids[i]) })
    return out
}

function symbolOf(price) {
    return price && price.symbol ? String(price.symbol).toUpperCase() : ""
}

function rowTitle(row) {
    return row.price && row.price.name ? String(row.price.name) : row.id
}

// "BTC +1.37%", the tooltip's first line.
function summary(price) {
    if (!price)
        return ""
    return (symbolOf(price) || String(price.name || "")) + " " + changeText(price.change24hPercent)
}

// The other prices, as "ETH -1.49% · SOL +0.20%".
function restSummary(snapshot, text) {
    var chosen = priceFor(snapshot, text)
    var list = priceList(snapshot)
    var parts = []
    for (var i = 0; i < list.length; i++) {
        if (!chosen || list[i].id !== chosen.id)
            parts.push(summary(list[i]))
    }
    return parts.join(" · ")
}

function intervalMinutes(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return INTERVAL_DEFAULT
    return Math.max(INTERVAL_MIN, Math.min(INTERVAL_MAX, number))
}

function intervalMs(value) {
    return intervalMinutes(value) * MINUTE
}

// What BarSnapshot runs: vitrail.market state <id>... --currency <code>.
function commandArguments(text, currency) {
    return symbolsOf(text).concat(["--currency", currencyOf(currency)])
}

// "updated 3 min ago", and "cached · updated 3 min ago" when the network is
// gone and the last answer came from the cache. A missing timestamp is quiet.
function updatedText(fetchedAt, cached, now, strings) {
    if (fetchedAt === null || fetchedAt === undefined || !isFinite(Number(fetchedAt)))
        return ""
    var words = strings || ({})
    var seconds = Math.max(0, Math.floor((Number(now) - Number(fetchedAt) * 1000) / 1000))
    var age
    if (seconds < 60)
        age = words["bar.market.justNow"] || "just now"
    else if (seconds < 3600)
        age = (words["bar.market.minutes"] || "%1 min ago").replace("%1", Math.floor(seconds / 60))
    else if (seconds < 86400)
        age = (words["bar.market.hours"] || "%1 h ago").replace("%1", Math.floor(seconds / 3600))
    else
        age = (words["bar.market.days"] || "%1 d ago").replace("%1", Math.floor(seconds / 86400))
    var updated = (words["bar.market.updated"] || "updated %1").replace("%1", age)
    return cached === true ? (words["bar.market.cached"] || "cached") + " · " + updated : updated
}
