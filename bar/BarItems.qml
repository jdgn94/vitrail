import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/base"
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
    property string barEdge: "left"
    property var strings: ({})
    property string trayStyle: "inline"
    // The link's latency and traffic, shared by the network and VPN chips.
    property var linkStats: ({})
    // The mode the power chip shows (power-profiles-daemon).
    property string powerProfile: "balanced"
    // A session is being recorded: the chip stops it.
    property bool recording: false
    signal recordStopped()
    // The buttons of the popouts that open without a click (IPC).
    readonly property Item networkButton: network
    readonly property Item vpnButton: vpn
    readonly property Item powerProfileButton: profile
    readonly property Item powerButton: power


    // The power button's left click opens the session menu; its right click
    // is the "power" popout.
    signal sessionRequested()
    signal clicked(string kind, Item item)
    signal hovered(string kind, Item item)
    // The pointer entered or left an element: its tooltip.
    signal tipHovered(Item item, bool on)

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    VitrailButton {
        visible: root.recording
        Layout.alignment: Qt.AlignHCenter
        variant: "plain"
        tone: "error"
        icon: "stop_circle"
        onClicked: root.recordStopped()
    }

    TrayItems {
        Layout.alignment: Qt.AlignHCenter
        vertical: root.vertical
        barEdge: root.barEdge
        style: root.trayStyle
        openKind: root.open ? root.openKind : ""
        strings: root.strings
        onMenuRequested: function (kind, item) { root.clicked(kind, item) }
        onHovered: function (kind, item) { root.hovered(kind, item) }
        onTipHovered: function (item, on) { root.tipHovered(item, on) }
    }

    // The connection buttons, together in a chip.
    Rectangle {
        id: chip

        implicitWidth: chipRow.implicitWidth
        implicitHeight: chipRow.implicitHeight + 2
        Layout.alignment: Qt.AlignHCenter
        radius: height / 2
        // A soft primary: opaque, so it does not smear over the glass.
        color: VitrailTokens.solid("primary", 0.14)

        GridLayout {
            id: chipRow

            anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 0
            columnSpacing: 0

            NetworkButton {
                id: network

                strings: root.strings
                stats: root.linkStats
                opened: root.open && root.openKind === "network"
                onClicked: root.clicked("network", network)
                onHoveredChanged: {
                    root.tipHovered(network, hovered)
                    if (hovered)
                        root.hovered("network", network)
                }
            }

            VpnButton {
                id: vpn

                strings: root.strings
                stats: root.linkStats
                opened: root.open && root.openKind === "vpn"
                onClicked: root.clicked("vpn", vpn)
                onHoveredChanged: {
                    root.tipHovered(vpn, hovered)
                    if (hovered)
                        root.hovered("vpn", vpn)
                }
            }

            PowerProfileButton {
                id: profile

                strings: root.strings
                profile: root.powerProfile
                opened: root.open && root.openKind === "powerprofile"
                onClicked: root.clicked("powerprofile", profile)
                onHoveredChanged: {
                    root.tipHovered(profile, hovered)
                    if (hovered)
                        root.hovered("powerprofile", profile)
                }
            }
        }
    }

    PowerButton {
        id: power

        Layout.alignment: Qt.AlignHCenter
        strings: root.strings
        opened: root.open && root.openKind === "power"
        onClicked: root.sessionRequested()
        onMenuRequested: root.clicked("power", power)
        onHoveredChanged: {
            root.tipHovered(power, hovered)
            if (hovered)
                root.hovered("power", power)
        }
    }
}
