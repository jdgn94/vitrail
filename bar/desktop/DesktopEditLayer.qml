import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../kit"

// The in-place editor's full-screen layer. It keeps the editor (a plain Item,
// tested offscreen) in a Wayland overlay on the monitor it was opened on, and
// loads the type families only while it is up.
PanelWindow {
    id: root

    required property var screen
    // Whether the shell asked for the editor at all, on which monitor it
    // started, and whether the desktop is one set of widgets everywhere.
    property bool requested: false
    property bool initiating: false
    property bool desktopShared: true
    // The editor shows on the monitor that opened it. The others carry it only
    // while the desktop is the document being edited there (sync off): the bar,
    // dock and panel documents are global, so one screen is enough.
    property bool active: root.requested
                          && (root.initiating
                              || (!root.desktopShared && root.tab === "desktop"))
    // Only the monitor that started the edit takes the keyboard; the others
    // show the same editor while the pointer and their buttons keep working.
    property bool focused: false
    // Not called `monitor`: that is the per-screen scope's id in bar/shell.qml,
    // and a property with that name shadows it, so `screen: monitor.modelData`
    // resolved to this string and every editor landed on the default output.
    property string monitorName: ""
    property string layoutText: ""
    // The output this layer sits on: the "on this monitor" placement selectors
    // write its override.
    property string screenMonitor: ""
    property var strings: ({})
    property real screenWidth: 1920
    property real screenHeight: 1080
    property var fontFamilies: []
    // The dock's preferences, edited in the Dock tab of the editor.
    property var dock: ({ enabled: false, edge: "bottom", autohide: false,
                          attached: true, magnify: "planet",
                          magnifyRange: VitrailTokens.dock.magnify.range,
                          magnifyScale: VitrailTokens.dock.magnify.scale,
                          pinned: "[]" })
    // The bar and panel documents and the bar's own options, all edited by
    // their tabs.
    property string barLayout: ""
    property string panelLayout: ""
    // The bar's per-monitor placements and whether the desktop is shared.
    property string positions: ""
    property bool desktopSync: true
    property var monitors: []
    property var bar: ({ edge: "left", trayStyle: "inline", batteryChip: true,
                         bluetoothChip: true, keyboard: true, dragReorder: true,
                         style: "", screens: "primary", opacityFollow: true,
                         opacity: VitrailTokens.ranges.opacity.value,
                         size: VitrailTokens.ranges.bar.value })

    signal layoutChanged(string surface, string text)
    signal prefChanged(string key, var value)
    signal finished()

    // The tab the editor shows ("bar", "desktop", "dock", "panel"); the shell
    // and the smoke fixture drive the real editor through it.
    property alias tab: editor.tab

    // A pick in the tab bar goes up to the shell, which owns the value.
    signal tabPicked(string key)

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
    WlrLayershell.keyboardFocus: root.focused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: root.active ? editor : null }

    DesktopEditMode {
        id: editor

        anchors.fill: parent
        active: root.active
        monitor: root.monitorName
        onTabSelected: root.tabPicked(key)
        layoutText: root.layoutText
        strings: root.strings
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        fonts: root.fontFamilies
        dock: root.dock
        barLayout: root.barLayout
        panelLayout: root.panelLayout
        positions: root.positions
        desktopSync: root.desktopSync
        screenMonitor: root.screenMonitor
        monitors: root.monitors
        bar: root.bar
        onLayoutChanged: function (surface, text) { root.layoutChanged(surface, text) }
        onPrefChanged: function (key, value) { root.prefChanged(key, value) }
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
