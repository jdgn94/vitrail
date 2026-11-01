import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "network.js" as Network

// The connection panel: what the bar's chip opens.
//
//   connection details (address, gateway, DNS), the Wi-Fi radio, the networks
//   themselves (the existing panel), Bluetooth with its devices, and the power
//   profile.
Item {
    id: root

    property var strings: ({})
    property bool wifiOn: false
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property var bluetoothDevices: []
    property string powerProfile: "balanced"

    signal refreshRequested()
    signal wifiRadioToggled()
    signal bluetoothToggled()
    signal bluetoothScanRequested()
    signal bluetoothDeviceToggled(string mac)
    signal powerProfileRequested(string profile)

    readonly property string details: {
        var parts = []
        if (root.address !== "")
            parts.push(root.address)
        if (root.gateway !== "")
            parts.push(root.t("connection.gateway") + " " + root.gateway)
        if (root.dns !== "")
            parts.push("DNS " + root.dns)
        return parts.join(" · ")
    }

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    ColumnLayout {
        id: body

        width: parent.width
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "title"
                text: root.t("connection.title")
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "refresh"
                onClicked: root.refreshRequested()
            }
        }

        // The radio, and what the link is.
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: root.wifiOn ? "wifi" : "wifi_off"
                size: "sm"
                tone: root.wifiOn ? "primary" : "secondary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.t("connection.wifi")
            }

            VitrailButton {
                variant: "text"
                tone: root.wifiOn ? "primary" : "secondary"
                size: "sm"
                icon: root.wifiOn ? "toggle_on" : "toggle_off"
                onClicked: root.wifiRadioToggled()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.details !== ""
            variant: "label"
            opacity: 0.75
            elide: Text.ElideRight
            text: root.details
        }

        // The networks, with their own list and connect buttons.
        NetworkPanel {
            Layout.fillWidth: true
            strings: root.strings
        }

        // Bluetooth.
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: root.bluetoothOn ? "bluetooth" : "bluetooth_disabled"
                size: "sm"
                tone: root.bluetoothOn ? "primary" : "secondary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.t("connection.bluetooth")
            }

            VitrailButton {
                visible: root.bluetoothOn
                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "search"
                onClicked: root.bluetoothScanRequested()
            }

            VitrailButton {
                visible: root.bluetoothPresent
                variant: "text"
                tone: root.bluetoothOn ? "primary" : "secondary"
                size: "sm"
                icon: root.bluetoothOn ? "toggle_on" : "toggle_off"
                onClicked: root.bluetoothToggled()
            }
        }

        Repeater {
            model: root.bluetoothOn ? root.bluetoothDevices : []

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    elide: Text.ElideRight
                    text: modelData.name
                }

                VitrailButton {
                    variant: "text"
                    tone: modelData.connected ? "primary" : "secondary"
                    size: "sm"
                    icon: modelData.connected ? "link_off" : "link"
                    onClicked: root.bluetoothDeviceToggled(modelData.mac)
                }
            }
        }

        // The power profile.
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "bolt"
                size: "sm"
                tone: "secondary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.t("connection.power")
            }
        }

        VitrailSegmented {
            Layout.fillWidth: true
            current: root.powerProfile
            options: [
                { key: "power-saver", label: root.t("connection.power.saver") },
                { key: "balanced", label: root.t("connection.power.balanced") },
                { key: "performance", label: root.t("connection.power.performance") }
            ]
            onSelected: function (key) { root.powerProfileRequested(key) }
        }
    }
}
