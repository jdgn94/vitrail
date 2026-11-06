import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// The in-place editor's full-screen layer. It keeps the editor (a plain Item,
// tested offscreen) in a Wayland overlay on the monitor it was opened on, and
// loads the type families only while it is up.
PanelWindow {
    id: root

    required property var screen
    property bool active: false
    property string monitor: ""
    property string layoutText: ""
    property var strings: ({})
    property real screenWidth: 1920
    property real screenHeight: 1080
    property var fontFamilies: []

    signal layoutChanged(string text)
    signal finished()

    visible: root.active || editor.progress > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-session"
    WlrLayershell.layer: WlrLayer.Overlay
    // The editor is modal: Escape and its controls need the keyboard. The
    // OSD keeps its own surface above this one and never needs it.
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: root.active ? editor : null }

    DesktopEditMode {
        id: editor

        anchors.fill: parent
        active: root.active
        monitor: root.monitor
        layoutText: root.layoutText
        strings: root.strings
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        fonts: root.fontFamilies
        onLayoutChanged: function (text) { root.layoutChanged(text) }
        onFinished: root.finished()
    }

    // The installed families, read once per opening; a missing fontconfig
    // leaves the picker with "inherit" only.
    Process {
        id: fontRead

        running: root.active && root.fontFamilies.length === 0
        command: ["fc-list", ":family"]
        stdout: StdioCollector {
            onStreamFinished: root.fontFamilies = root.parseFamilies(this.text)
        }
    }

    function parseFamilies(text) {
        var seen = ({})
        var list = []
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var names = lines[i].split(",")
            for (var j = 0; j < names.length; j++) {
                var family = names[j].trim()
                if (family !== "" && seen[family] !== true) {
                    seen[family] = true
                    list.push(family)
                }
            }
        }
        list.sort(function (a, b) { return a.localeCompare(b) })
        return list
    }
}
