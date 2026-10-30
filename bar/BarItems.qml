import QtQuick
import QtQuick.Layouts
import "kit"
import "network"
import "session"
import "tray"

// The bar's end group: background apps (tray), the network button and the
// power button.
// Every element that has a popout reports its own kind and item, so the
// popout opens on, and glides to, that exact element.
GridLayout {
    id: root

    property bool vertical: false
    property string openKind: ""
    property bool open: false
    // The buttons of the popouts that open without a click (IPC).
    readonly property Item networkButton: network
    readonly property Item powerButton: power

    // The power button's left click opens the session menu; its right click
    // is the "power" popout.
    signal sessionRequested()
    signal clicked(string kind, Item item)
    signal hovered(string kind, Item item)

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    TrayItems {
        vertical: root.vertical
        openKind: root.open ? root.openKind : ""
        onMenuRequested: function (kind, item) { root.clicked(kind, item) }
        onHovered: function (kind, item) { root.hovered(kind, item) }
    }

    NetworkButton {
        id: network

        vertical: root.vertical
        opened: root.open && root.openKind === "network"
        onClicked: root.clicked("network", network)
        onHoveredChanged: if (hovered) root.hovered("network", network)
    }

    PowerButton {
        id: power

        opened: root.open && root.openKind === "power"
        onClicked: root.sessionRequested()
        onMenuRequested: root.clicked("power", power)
        onHoveredChanged: if (hovered) root.hovered("power", power)
    }
}
