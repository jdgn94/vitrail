// The resources element's plain logic, shared by the button, the popup and the
// network element that reads the same sampler: the face choice, the history
// ring, the unit formatting and the two-step kill. vitrail.resources gives
// numbers and codes, never words; the words are translated in QML. No QML type
// is touched, so tests/qml/tst_resources.qml feeds it plain objects.
.pragma library

// How many readings the ring keeps (about two minutes at the default interval).
var CAPACITY = 60
// The seconds between two readings: the range of `resourcesInterval`.
var INTERVAL_MIN = 1
var INTERVAL_MAX = 10
var INTERVAL_DEFAULT = 2
// What `resourcesBar` may hold, in the settings page's order.
var BAR_MODES = ["both", "cpu", "ram", "numbers"]
var UNITS = ["auto", "binary", "decimal"]
// The history's series: the sampler's snapshot feeds each one.
var SERIES = ["cpu", "memory", "temperature", "disk", "rx", "tx"]

function number(value) {
    if (value === null || value === undefined || value === "" || typeof value === "boolean")
        return null
    var found = Number(value)
    return isFinite(found) ? found : null
}

// A list as a real array. A list that crossed a QML property boundary (a
// Repeater's modelData, an initial property) is a sequence wrapper:
// Array.isArray is false and it has no concat, so it is copied before use.
function toArray(value) {
    if (value === null || value === undefined || typeof value !== "object" || typeof value.length !== "number")
        return []
    var out = []
    for (var i = 0; i < value.length; i++)
        out.push(value[i])
    return out
}

// A snapshot the sampler could read: an object with the memory block.
function ready(snapshot) {
    return !!snapshot && !snapshot.error && !!snapshot.memory
}

// The seconds the settings page shows, clamped.
function interval(value) {
    var found = number(value)
    if (found === null)
        return INTERVAL_DEFAULT
    return Math.min(Math.max(Math.round(found), INTERVAL_MIN), INTERVAL_MAX)
}

// The sampler's timer, in milliseconds.
function intervalMs(value) {
    return interval(value) * 1000
}

function barMode(value) {
    return BAR_MODES.indexOf(value) >= 0 ? value : "both"
}

function unitsMode(value) {
    return UNITS.indexOf(value) >= 0 ? value : "auto"
}

// What the button draws: `bars` (mini bars rather than numbers), and which of
// the two readings it carries.
function face(mode) {
    var chosen = barMode(mode)
    return { bars: chosen !== "numbers", cpu: chosen !== "ram", ram: chosen !== "cpu" }
}

// ---- the readings ----

// One reading of the machine as plain numbers; null is "this metric is
// missing" and is never turned into zero.
function reading(snapshot) {
    if (!ready(snapshot))
        return { cpu: null, memory: null, temperature: null, disk: null, rx: null, tx: null }
    var memory = snapshot.memory || ({})
    var disk = snapshot.disk || ({})
    var rate = snapshot.rate || ({})
    return {
        cpu: number(snapshot.cpu),
        memory: number(memory.total) > 0 ? number(memory.percent) : null,
        temperature: number(snapshot.temperature),
        // The graph shows the share that is still free.
        disk: number(disk.total) > 0 ? 100 * number(disk.free) / number(disk.total) : null,
        rx: number(rate.rx),
        tx: number(rate.tx)
    }
}

// ---- the history ring ----

function emptyHistory() {
    var history = {}
    for (var i = 0; i < SERIES.length; i++)
        history[SERIES[i]] = []
    return history
}

// A new history with the snapshot's reading appended and every series cut to
// `capacity`. A snapshot with an error adds nothing; the old history is kept.
// The input is never modified, so a binding on it fires.
function push(history, snapshot, capacity) {
    if (!ready(snapshot))
        return history
    var limit = capacity > 0 ? capacity : CAPACITY
    var now = reading(snapshot)
    var next = {}
    for (var i = 0; i < SERIES.length; i++) {
        var key = SERIES[i]
        var list = history && history[key] ? toArray(history[key]) : []
        list.push(now[key])
        next[key] = list.length > limit ? list.slice(list.length - limit) : list
    }
    return next
}

// The newest value of a series, or null.
function latest(history, key) {
    var list = history && history[key] ? toArray(history[key]) : []
    return list.length > 0 ? list[list.length - 1] : null
}

// Whether a series has at least one real reading.
function hasData(history, key) {
    var list = history && history[key] ? toArray(history[key]) : []
    for (var i = 0; i < list.length; i++) {
        if (list[i] !== null)
            return true
    }
    return false
}

// The axis of the network graph: both directions share it.
function networkCeiling(history) {
    return ceiling(toArray(history && history.rx).concat(toArray(history && history.tx)), 1024)
}

// The top of a graph's axis: a fixed 100 for percentages, and a round number
// above the biggest value for rates, so a quiet line never fills the graph.
function ceiling(values, floor) {
    var list = toArray(values)
    var biggest = 0
    for (var i = 0; i < list.length; i++) {
        if (list[i] !== null && list[i] > biggest)
            biggest = list[i]
    }
    var step = Math.max(floor || 1, 1)
    if (biggest <= step)
        return step
    var power = Math.pow(10, Math.floor(Math.log(biggest) / Math.LN10))
    var scaled = biggest / power
    var round = scaled <= 1 ? 1 : scaled <= 2 ? 2 : scaled <= 5 ? 5 : 10
    return round * power
}

// ---- units ----

var BINARY = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
var DECIMAL = ["B", "kB", "MB", "GB", "TB", "PB"]

// Whether `kind` ("memory", "disk" or "network") counts in 1024s under `units`.
// "auto" follows the habit of each: memory in 1024s, disks and networks in 1000s.
function binary(units, kind) {
    var mode = unitsMode(units)
    return mode === "binary" || (mode === "auto" && kind === "memory")
}

// Bytes as a short text: 1536, "binary" -> "1.5 KiB".
function bytes(value, units, kind) {
    var found = number(value)
    if (found === null || found < 0)
        return "--"
    var base = binary(units, kind) ? 1024 : 1000
    var names = binary(units, kind) ? BINARY : DECIMAL
    var index = 0
    while (found >= base && index < names.length - 1) {
        found /= base
        index += 1
    }
    var text = index === 0 || found >= 10 ? String(Math.round(found)) : found.toFixed(1)
    return text + " " + names[index]
}

// A network speed: "1.2 MB/s".
function rate(value, units) {
    var text = bytes(value, units, "network")
    return text === "--" ? text : text + "/s"
}

function percent(value) {
    var found = number(value)
    return found === null ? "--" : Math.round(Math.max(0, Math.min(100, found))) + "%"
}

function temperature(value) {
    var found = number(value)
    return found === null ? "--" : Math.round(found) + " °C"
}

// "12 GB free of 500 GB".
function diskFree(disk, units, t) {
    if (!disk || !(number(disk.total) > 0))
        return "--"
    return t("bar.resources.disk.free").replace("%1", bytes(disk.free, units, "disk"))
                                       .replace("%2", bytes(disk.total, units, "disk"))
}

// "4.2 GB of 16 GB".
function memoryUsed(memory, units, t) {
    if (!memory || !(number(memory.total) > 0))
        return "--"
    return t("bar.resources.memory.used").replace("%1", bytes(memory.used, units, "memory"))
                                         .replace("%2", bytes(memory.total, units, "memory"))
}

// "↓ 1.2 MB/s  ↑ 80 kB/s"
function networkLine(snapshot, units) {
    var rates = snapshot && snapshot.rate ? snapshot.rate : null
    if (!rates)
        return "--"
    return "↓ " + rate(rates.rx, units) + "  ↑ " + rate(rates.tx, units)
}

// ---- the top processes ----

// The list as plain objects (a model read through a Repeater is not an array).
function processes(snapshot) {
    var list = snapshot ? toArray(snapshot.top) : []
    return list.map(function (item) {
        return { pid: Number(item.pid), name: String(item.name), cpu: number(item.cpu),
                 memory: number(item.memory), percent: number(item.percent) }
    })
}

// The kill buttons' two steps, per process. idle: "End" sends SIGTERM and the
// row waits ("sent"). If it is still running, "Force quit" asks for a
// confirmation ("confirm"), and only that second click sends SIGKILL ("done").
// click(stage) returns the new stage and the signal to send ("term", "kill" or "").
function click(stage) {
    switch (stage) {
    case "sent": return { stage: "confirm", send: "" }
    case "confirm": return { stage: "done", send: "kill" }
    case "done": return { stage: "done", send: "" }
    default: return { stage: "sent", send: "term" }
    }
}

// Leaving the confirmation without killing: back to "sent".
function cancel(stage) {
    return stage === "confirm" ? "sent" : stage
}

// The stages that survive a new list: a process that is gone starts clean if
// its pid is ever reused.
function prune(stages, list) {
    var next = {}
    for (var i = 0; i < list.length; i++) {
        var key = String(list[i].pid)
        if (stages[key] !== undefined)
            next[key] = stages[key]
    }
    return next
}

// The label's translation key for a stage.
function killKey(stage) {
    return stage === "sent" ? "bar.resources.kill.force"
         : stage === "confirm" ? "bar.resources.kill.confirm"
         : "bar.resources.kill"
}

// The words for a refused kill; unknown codes get the generic line.
function killError(code) {
    var known = ["refused", "gone", "denied", "failed"]
    return "bar.resources.kill.error." + (known.indexOf(code) >= 0 ? code : "failed")
}
