// The volume element's plain logic: what the button shows, how a wheel notch
// becomes a step, which streams the popup lists and the arguments of each
// `python3 -m vitrail.audio` action. No QML type is touched here, so
// tests/qml/tst_volume.qml feeds it plain objects.
.pragma library
.import "../osd/icons.js" as Icons

// The wheel step is a preference the user types or drags; keep it a whole
// percent between 1 and 25 and fall back to 5 for anything else.
var STEP_MIN = 1
var STEP_MAX = 25
var STEP_DEFAULT = 5
// Qt's angleDelta.y for one wheel notch.
var NOTCH = 120

function step(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return STEP_DEFAULT
    return Math.max(STEP_MIN, Math.min(STEP_MAX, number))
}

// The signed percent a wheel event moves the volume: `step` per notch (up is
// louder), at least one percent for a smooth wheel's small deltas, and 0 when
// the wheel did not move.
function wheelChange(delta, stepValue) {
    var amount = Number(delta)
    if (!isFinite(amount) || amount === 0)
        return 0
    var percent = Math.max(1, Math.round(Math.abs(amount) / NOTCH * step(stepValue)))
    return amount > 0 ? percent : -percent
}

// Whether the snapshot has a default output to show. A missing `pw-dump` or
// WirePlumber is `error` (and no sink): the button and the popup go neutral.
function ready(snapshot) {
    var data = snapshot || ({})
    return !data.error && !!data.defaultSink
}

function sink(snapshot) {
    return ready(snapshot) ? snapshot.defaultSink : null
}

function level(snapshot) {
    var device = sink(snapshot)
    return device ? device.volume : 0
}

function muted(snapshot) {
    var device = sink(snapshot)
    return !!device && !!device.muted
}

// The button's glyph: muted, none (0), low, high; the neutral state (no audio
// server) is the muted glyph too, in the button's muted tone.
function icon(snapshot) {
    var device = sink(snapshot)
    return Icons.volume(device ? device.volume / 100 : 0, !device || device.muted)
}

// The microphone's glyph in the popup.
function micIcon(snapshot) {
    var source = (snapshot || ({})).defaultSource
    return Icons.mic(!source || !!source.muted)
}

// A stream is silent when it is paused (corked): no sound reaches the output.
function silent(stream) {
    return !!stream.corked
}

// The playback streams the popup lists, one per stream and in the order the
// graph gave them; `hideSilent` drops the paused ones.
function streams(snapshot, hideSilent) {
    var list = (snapshot || ({})).streams || []
    return list.filter(function (stream) {
        return !(hideSilent && silent(stream))
    })
}

// The options of a device chooser: { key, label } for each device, the key
// being its node id as text.
function deviceOptions(devices) {
    return (devices || []).map(function (device) {
        return { key: String(device.id), label: device.description || device.name }
    })
}

// The sink a stream plays on (its id as text, "" when unknown).
function streamSink(stream) {
    return stream.sink === null || stream.sink === undefined ? "" : String(stream.sink)
}

// The sink's node name for an id: `pactl` moves a stream by name.
function sinkName(snapshot, id) {
    var list = (snapshot || ({})).sinks || []
    for (var i = 0; i < list.length; i++) {
        if (String(list[i].id) === String(id))
            return list[i].name
    }
    return ""
}

// The argument lists of `python3 -m vitrail.audio`, one process per action.
// A target is "sink" (the default output), "source" (the default input) or a
// node id.
function action(verb) {
    return [verb].concat(Array.prototype.slice.call(arguments, 1).map(String))
}

function volumeArgs(target, percent) {
    return action("volume", target, Math.max(0, Math.min(100, Math.round(percent))))
}

// A step: the sign is the direction, the number the size.
function stepArgs(target, change) {
    return action("volume", target, (change < 0 ? "-" : "+") + Math.abs(Math.round(change)))
}

function muteArgs(target) {
    return action("mute", target)
}

function defaultArgs(id) {
    return action("default", id)
}

function moveArgs(stream, sinkNodeName) {
    return action("move", stream.serial, sinkNodeName)
}
