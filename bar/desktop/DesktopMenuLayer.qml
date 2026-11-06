import Quickshell
import Quickshell.Wayland
import QtQuick
import "../kit"

// The desktop's right-click menu on its screen. The whole layer takes the
// pointer while the menu is up, so a click anywhere else closes it; the card
// itself is at the point of the right click, kept inside the monitor.
PanelWindow {
    id: root

    required property var screen
    property bool open: false
    property real anchorX: 0
    property real anchorY: 0
    property var strings: ({})

    signal editRequested()
    signal dismissed()

    readonly property real margin: VitrailTokens.gap("md")

    visible: root.open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: root.open ? catcher : null }

    MouseArea {
        id: catcher

        anchors.fill: parent
        onClicked: root.dismissed()
    }

    DesktopMenu {
        id: menu

        x: Math.max(root.margin, Math.min(root.width - menu.width - root.margin, root.anchorX))
        y: Math.max(root.margin, Math.min(root.height - menu.height - root.margin, root.anchorY))
        strings: root.strings
        z: 1
        onEditRequested: root.editRequested()
        onDismissed: root.dismissed()
    }
}
