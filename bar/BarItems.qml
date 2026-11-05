import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/base"
import "devices"
import "keyboard"
import "media"
import "network"
import "session"
import "tray"

// The bar's end group: background apps (tray), the Bluetooth, network and VPN
// buttons, the battery, and the power button.
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
    // What `vitrail.network bluetooth` printed, shared by the chip and the
    // Bluetooth tab of the connection popup.
    property var bluetooth: ({})
    // The two chips can be kept out of the bar (bar.ini).
    property bool showBattery: true
    property bool showBluetooth: true
    // The keyboard layout abbreviation, and the live keyboards it reads.
    property bool showKeyboard: true
    property var keyboards: []
    // A session is being recorded: the chip stops it.
    property bool recording: false
    signal recordStopped()
    // The buttons of the popouts that open without a click (IPC).
    readonly property Item networkButton: network
    readonly property Item bluetoothButton: bluetoothChip
    readonly property Item vpnButton: vpn
    readonly property Item powerProfileButton: profile
    readonly property Item powerButton: power
    readonly property Item keyboardButton: keyboard


    // The power button's left click opens the session menu; its right click
    // is the "power" popout.
    signal sessionRequested()
    // The keyboard's right click: the floating on-screen keyboard.
    signal keyboardOskRequested()
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

            BluetoothButton {
                id: bluetoothChip

                strings: root.strings
                show: root.showBluetooth
                bluetooth: root.bluetooth
                opened: root.open && root.openKind === "bluetooth"
                onClicked: root.clicked("bluetooth", bluetoothChip)
                onHoveredChanged: {
                    root.tipHovered(bluetoothChip, hovered)
                    if (hovered)
                        root.hovered("bluetooth", bluetoothChip)
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

    // The charge, on the machines that have a battery; a click opens the power
    // profile popup, like the mode chip inside the connection pill.
    BatteryButton {
        id: battery

        Layout.alignment: Qt.AlignHCenter
        strings: root.strings
        show: root.showBattery
        opened: root.open && root.openKind === "powerprofile"
        onClicked: root.clicked("powerprofile", battery)
        onHoveredChanged: {
            root.tipHovered(battery, hovered)
            if (hovered)
                root.hovered("powerprofile", battery)
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

    // The active layout abbreviation, last: right on a horizontal bar, bottom
    // on a vertical one.
    KeyboardButton {
        id: keyboard

        Layout.alignment: Qt.AlignHCenter
        visible: root.showKeyboard
        strings: root.strings
        keyboards: root.keyboards
        opened: root.open && root.openKind === "keyboard"
        onClicked: root.clicked("keyboard", keyboard)
        onRightClicked: root.keyboardOskRequested()
        onHoveredChanged: {
            root.tipHovered(keyboard, hovered)
            if (hovered)
                root.hovered("keyboard", keyboard)
        }
    }
}
