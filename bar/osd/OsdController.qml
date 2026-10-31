import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "../kit"
import "brightness.js" as Light

// What the OSD shows and drives, once per shell: the default output and input
// (PipeWire) and the brightness of the monitors. `keyed(kind)` fires when a
// media key (the `osd` IPC) or something outside the panel (a `wpctl` bind, a
// volume key on a headset) changed a value: every monitor's OSD may then show
// that one slider.
//
//   vitrail-bar ipc call osd volume up | down | mute
//   vitrail-bar ipc call osd mic mute
//   vitrail-bar ipc call osd brightness up | down      (setBrightness <n>)
//   vitrail-bar ipc call osd peek volume | mic | brightness
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: root.devicesOf(true)
    readonly property var sources: root.devicesOf(false)
    readonly property alias light: light

    // 0..1; zero while there is no device.
    readonly property real volume: root.sink && root.sink.audio ? root.sink.audio.volume : 0
    readonly property bool muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)
    readonly property real micVolume: root.source && root.source.audio ? root.source.audio.volume : 0
    readonly property bool micMuted: !!(root.source && root.source.audio && root.source.audio.muted)
    readonly property bool hasOutput: !!(root.sink && root.sink.audio)
    readonly property bool hasInput: !!(root.source && root.source.audio)

    signal keyed(string kind)

    // Real, non-stream audio nodes that are outputs (or inputs).
    function devicesOf(output) {
        return Pipewire.nodes.values.filter(function (node) {
            return node.audio && !node.isStream && node.isSink === output
        })
    }

    function name(node) {
        return node ? (node.nickname || node.description || node.name) : ""
    }

    function limit(fraction) {
        return Math.max(0, Math.min(1, fraction))
    }

    // The panel's own changes are not news: it is already on screen.
    function mine() {
        root.quiet = true
        calm.restart()
    }

    function setVolume(fraction) {
        if (!root.hasOutput)
            return
        root.mine()
        root.sink.audio.volume = root.limit(fraction)
    }

    function setMicVolume(fraction) {
        if (!root.hasInput)
            return
        root.mine()
        root.source.audio.volume = root.limit(fraction)
    }

    function toggleMute() {
        if (!root.hasOutput)
            return
        root.mine()
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function toggleMicMute() {
        if (!root.hasInput)
            return
        root.mine()
        root.source.audio.muted = !root.source.audio.muted
    }

    function pickOutput(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function pickInput(node) {
        Pipewire.preferredDefaultAudioSource = node
    }

    function setBrightness(percent) {
        root.mine()
        light.setAll(percent)
    }

    // A key press: change the value, then show that slider.
    function press(kind, action) {
        var amount = VitrailTokens.osd.step / 100
        var direction = action === "up" ? 1 : -1
        if (kind === "volume") {
            if (action === "mute")
                root.toggleMute()
            else
                root.setVolume(root.volume + direction * amount)
        } else if (kind === "mic") {
            root.toggleMicMute()
        } else if (kind === "brightness") {
            root.setBrightness(Light.step(light.level, direction, VitrailTokens.osd.step))
        }
        root.keyed(kind)
    }

    // What changed outside the panel is announced, once PipeWire has settled.
    property bool armed: false
    property bool quiet: false

    function heard(kind) {
        if (root.armed && !root.quiet)
            root.keyed(kind)
    }

    onSinkChanged: root.settle()
    onSourceChanged: root.settle()

    function settle() {
        root.armed = false
        arm.restart()
    }

    Timer {
        id: arm

        interval: VitrailTokens.osd.extension * 2
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: calm

        interval: VitrailTokens.osd.extension * 2
        onTriggered: root.quiet = false
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() { root.heard("volume") }
        function onMutedChanged() { root.heard("volume") }
    }

    Connections {
        target: root.source ? root.source.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() { root.heard("mic") }
        function onMutedChanged() { root.heard("mic") }
    }

    BrightnessState {
        id: light
    }

    IpcHandler {
        target: "osd"

        function volume(action: string): void { root.press("volume", action) }
        function mic(action: string): void { root.press("mic", action) }
        function brightness(action: string): void { root.press("brightness", action) }
        function setBrightness(percent: int): void {
            root.setBrightness(percent)
            root.keyed("brightness")
        }

        // Shows one slider without changing anything.
        function peek(kind: string): void { root.keyed(kind) }
    }
}
