import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "binds.js" as Binds

// The cheatsheet's host: asks vitrail/binds.py for Hyprland's binds and hands
// them to BindsOverlay, which stays free of Quickshell and is tested alone.
Item {
    id: root

    property var strings: ({})
    property var rows: []
    property bool available: false

    signal dismissed()

    implicitWidth: overlay.implicitWidth
    implicitHeight: overlay.implicitHeight

    function read(text) {
        var state = Binds.parseState(text)
        root.rows = state.rows
        root.available = state.available
    }

    BindsOverlay {
        id: overlay

        anchors.fill: parent
        strings: root.strings
        rows: root.rows
        available: root.available
        onDismissed: root.dismissed()
    }

    Process {
        id: load

        command: ["python3", "-m", "vitrail.binds", "state"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.read(this.text)
        }
    }

    Component.onCompleted: load.running = true
}
