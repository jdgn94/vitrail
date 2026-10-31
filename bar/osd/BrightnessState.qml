import Quickshell
import Quickshell.Io
import QtQuick
import "../kit"
import "brightness.js" as Light

// The brightness of every monitor Vitrail can dim. `vitrail brightness list`
// finds them (ddcutil for external monitors, brightnessctl for a laptop panel;
// detection is cached) and reads their levels, off the UI thread. Writing is
// debounced and done by one process per monitor, so a drag never waits for the
// slow DDC bus and two monitors move together.
Scope {
    id: root

    // loading, ok, or why not: access, missing, none (see brightness.js).
    property string status: "loading"
    // [{ name, kind, bus, device, percent, max }], in Hyprland's order.
    property var devices: []
    property var pending: ({})
    property double read: 0

    readonly property bool enabled: root.status === "ok" && root.devices.length > 0
    readonly property int level: Light.level(root.devices)

    // Reading takes a second; ask again only when the answer is stale.
    function refresh(force) {
        if (!lister.running && (force || Date.now() - root.read > VitrailTokens.osd.stale))
            lister.running = true
    }

    // The main slider and the keys move every display to one level.
    function setAll(percent) {
        root.devices.forEach(function (device) { root.set(device.name, percent) })
    }

    function set(name, percent) {
        var value = Light.clamp(percent)
        root.devices = root.devices.map(function (device) {
            return device.name === name ? Object.assign({}, device, { percent: value }) : device
        })
        root.pending[name] = value
        debounce.restart()
    }

    function accept(text) {
        var list = Light.parse(text)
        root.status = list.status
        // The same monitors keep the writers that are about to run.
        root.devices = list.devices
        root.read = Date.now()
    }

    Component.onCompleted: root.refresh(true)

    // A monitor plugged or unplugged changes what can be dimmed.
    Connections {
        target: Quickshell

        function onScreensChanged() { root.refresh(true) }
    }

    Process {
        id: lister

        command: ["python3", "-m", "vitrail.cli", "brightness", "list"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.accept(this.text)
        }
    }

    Timer {
        id: debounce

        interval: VitrailTokens.osd.write
        onTriggered: {
            for (var i = 0; i < writers.count; i++)
                writers.objectAt(i).write()
        }
    }

    Instantiator {
        id: writers

        model: root.devices.length

        delegate: Process {
            id: writer

            required property int index

            readonly property var device: root.devices[writer.index]
            // A newer value arrived while the last one was being written.
            property bool again: false

            function write() {
                var name = writer.device ? writer.device.name : ""
                if (!(name in root.pending))
                    return
                if (writer.running) {
                    writer.again = true
                    return
                }
                writer.command = Light.command(writer.device, root.pending[name])
                delete root.pending[name]
                writer.running = true
            }

            onExited: {
                if (writer.again) {
                    writer.again = false
                    writer.write()
                }
            }
        }
    }
}
