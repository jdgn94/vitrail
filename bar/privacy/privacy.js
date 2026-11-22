// The privacy element's plain logic: which uses count (the watched kinds), what
// the tooltip says, the dot's colour token and the words of a kind. vitrail.privacy
// decides what a use is; this file only narrows (never widens) what it
// reported. No QML type is touched, so tests/qml/tst_privacy.qml feeds it plain
// objects.
.pragma library

// The kinds in the order the popup draws them (vitrail.privacy.KINDS).
var KINDS = ["microphone", "camera", "screen"]
// The palette roles the dot may take, first is the default. The palette has
// no warning or success family, so these are the semantic roles it does have.
var DOT_COLORS = ["error", "primary", "info"]
var DOT_DEFAULT = "error"
// How many apps the tooltip names before "and N more".
var NAMED = 2

function ready(snapshot) {
    return !!snapshot && !snapshot.error && Array.isArray(snapshot.uses)
}

// The `privacyWatch` preference: one JSON array of kinds. Unset keeps all
// three; an explicit "[]" watches nothing; anything unreadable keeps all three.
function parseWatch(text) {
    if (text === undefined || text === null || String(text) === "")
        return KINDS.slice()
    var list = null
    try {
        list = JSON.parse(String(text))
    } catch (error) {
        return KINDS.slice()
    }
    if (!Array.isArray(list))
        return KINDS.slice()
    return KINDS.filter(function (kind) { return list.indexOf(kind) >= 0 })
}

function watching(text, kind) {
    return parseWatch(text).indexOf(kind) >= 0
}

// The preference's text after `kind` is watched (or not), in the popup's order.
function withWatch(text, kind, on) {
    var list = parseWatch(text).filter(function (one) { return one !== kind })
    if (on)
        list.push(kind)
    return JSON.stringify(KINDS.filter(function (one) { return list.indexOf(one) >= 0 }))
}

// The arguments of `python3 -m vitrail.privacy state`: no argument means "all"
// to the module, so a preference that watches nothing is never passed as one.
function watchArguments(text) {
    var list = parseWatch(text)
    return list.length === 0 || list.length === KINDS.length ? [] : list
}

// The snapshot's uses of the watched kinds: a use of an unwatched kind never
// lights the dot, even from a snapshot taken before the preference changed.
function uses(snapshot, watchText) {
    if (!ready(snapshot))
        return []
    var watched = parseWatch(watchText)
    return snapshot.uses.filter(function (use) {
        return !!use && watched.indexOf(use.kind) >= 0
    })
}

function active(list) {
    return Array.isArray(list) && list.length > 0
}

// The uses of one kind.
function ofKind(list, kind) {
    return (list || []).filter(function (use) { return use.kind === kind })
}

// The kinds present in `list`, in the popup's order.
function kindsIn(list) {
    return KINDS.filter(function (kind) { return ofKind(list, kind).length > 0 })
}

// A palette role the dot may take; anything else is the default.
function dotToken(value) {
    return DOT_COLORS.indexOf(String(value)) >= 0 ? String(value) : DOT_DEFAULT
}

// What the pointer reads. `t` translates a key.
function title(list, t) {
    var names = kindsIn(list).map(function (kind) { return t("bar.privacy.kind." + kind) })
    return names.length === 0 ? t("bar.privacy.idle") : t("bar.privacy.using").replace("%1", names.join(", "))
}

// The app names, first `NAMED` of them (duplicates once, an unnamed use as the
// node's label), then "and N more".
function appName(use) {
    return String(use.app || use.label || use.node)
}

function detail(list, t) {
    var names = []
    for (var i = 0; i < (list || []).length; i++) {
        var name = appName(list[i])
        if (names.indexOf(name) < 0)
            names.push(name)
    }
    if (names.length === 0)
        return t("bar.privacy.idle.detail")
    var shown = names.slice(0, NAMED).join(", ")
    return names.length > NAMED ? t("bar.privacy.apps.more").replace("%1", shown).replace("%2", names.length - NAMED) : shown
}

function icon(kind) {
    return kind === "microphone" ? "mic" : kind === "camera" ? "videocam" : "screen_share"
}

// A node id the popup may ask to cut: a non-negative integer (the module
// checks again and reads the graph once more before it destroys anything).
function cuttable(use) {
    return !!use && KINDS.indexOf(use.kind) >= 0 && typeof use.node === "number"
           && isFinite(use.node) && use.node >= 0 && Math.floor(use.node) === use.node
}
