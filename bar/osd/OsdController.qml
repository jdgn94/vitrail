import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "../kit"
import "audio.js" as Audio
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
    // One group per app with an open playback (or capture) stream.
    readonly property var outputApps: root.appsOf(true)
    readonly property var inputApps: root.appsOf(false)
    readonly property alias light: light

    // The steps the panel and the keys move by, and what the cards show.
    property real step: VitrailTokens.osd.step
    property real brightnessStep: VitrailTokens.osd.step
    property real appStep: VitrailTokens.osd.step
    property bool showOutputApps: true
    property bool showInputApps: true
    property bool focusApps: true

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

    // The playback (or capture) streams: applications, not devices.
    function streamsOf(output) {
        return Pipewire.nodes.values.filter(function (node) {
            return node.audio && node.isStream && node.isSink === output
        })
    }

    function entryOf(node) {
        var props = node.properties || ({})
        return { node: node, key: Audio.appKey(props, node.name),
                 name: Audio.appName(props, node.name), icon: Audio.iconName(props),
                 binary: String(props["application.process.binary"] || "").toLowerCase() }
    }

    function appsOf(output) {
        var streams = root.streamsOf(output)
        var entries = []
        for (var i = 0; i < streams.length; i++)
            entries.push(root.entryOf(streams[i]))
        return Audio.groups(entries)
    }

    function iconSource(group) {
        if (!group)
            return ""
        var name = group.icon || group.binary || ""
        return name === "" ? "" : Quickshell.iconPath(name, true)
    }

    // Every stream of the app moves together; the sink (general) volume is
    // never touched, so the app's percentage stays the same when it changes.
    function setAppVolume(group, fraction) {
        if (!group || !group.nodes || group.nodes.length === 0)
            return
        root.mine()
        var value = root.limit(fraction)
        for (var i = 0; i < group.nodes.length; i++) {
            if (group.nodes[i].audio)
                group.nodes[i].audio.volume = value
        }
    }

    // Any stream still audible: mute them all. All muted: bring them back.
    function toggleAppMute(group) {
        if (!group || !group.nodes || group.nodes.length === 0)
            return
        root.mine()
        var anyUnmuted = false
        for (var i = 0; i < group.nodes.length; i++) {
            if (group.nodes[i].audio && !group.nodes[i].audio.muted)
                anyUnmuted = true
        }
        for (var j = 0; j < group.nodes.length; j++) {
            if (group.nodes[j].audio)
                group.nodes[j].audio.muted = anyUnmuted
        }
    }

    // The app's window: its class against the stream's binary and name.
    function focusApp(group) {
        if (!root.focusApps || !group)
            return
        var clients = Hyprland.toplevels.values
        for (var i = 0; i < clients.length; i++) {
            var ipc = clients[i].lastIpcObject || ({})
            if (Audio.classMatches(group.binary, group.name, ipc["class"] || "")) {
                Hyprland.dispatch("focuswindow address:0x" + String(clients[i].address).replace(/^0x/, ""))
                return
            }
        }
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
        var amount = root.step / 100
        var direction = action === "up" ? 1 : -1
        if (kind === "volume") {
            if (action === "mute")
                root.toggleMute()
            else
                root.setVolume(root.volume + direction * amount)
        } else if (kind === "mic") {
            root.toggleMicMute()
        } else if (kind === "brightness") {
            root.setBrightness(Light.step(light.level, direction, root.brightnessStep))
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
