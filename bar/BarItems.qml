import QtQuick
import QtQuick.Layouts
import "kit"
import "media"
import "network"
import "session"
import "tray"

// The bar's end group: background apps (tray), the network and VPN buttons and
// the power button.
// Every element that has a popout reports its own kind and item, so the
// popout opens on, and glides to, that exact element.
GridLayout {
    id: root

    property bool vertical: false
    property string openKind: ""
    property bool open: false
    property var strings: ({})
    // The buttons of the popouts that open without a click (IPC).
    readonly property Item networkButton: network
    readonly property Item vpnButton: vpn
    readonly property Item powerButton: power

    // The power button's left click opens the session menu; its right click
    // is the "power" popout.
    signal sessionRequested()
    signal clicked(string kind, Item item)
    // The pointer entered or left an element: its tooltip.
    signal tipHovered(Item item, bool on)

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    TrayItems {
        vertical: root.vertical
        openKind: root.open ? root.openKind : ""
        strings: root.strings
        onMenuRequested: function (kind, item) { root.clicked(kind, item) }
        onTipHovered: function (item, on) { root.tipHovered(item, on) }
    }

    NetworkButton {
        id: network

        strings: root.strings
        opened: root.open && root.openKind === "network"
        onClicked: root.clicked("network", network)
        onHoveredChanged: root.tipHovered(network, hovered)
    }

    VpnButton {
        id: vpn

        strings: root.strings
        opened: root.open && root.openKind === "vpn"
        onClicked: root.clicked("vpn", vpn)
        onHoveredChanged: root.tipHovered(vpn, hovered)
    }

    PowerButton {
        id: power

        strings: root.strings
        opened: root.open && root.openKind === "power"
        onClicked: root.sessionRequested()
        onMenuRequested: root.clicked("power", power)
        onHoveredChanged: root.tipHovered(power, hovered)
    }
}
