import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The quick toggles: Wi-Fi, Bluetooth, the microphone and Do Not Disturb, as a
// row of pills that show the system's real state (the shell reads it back).
RowLayout {
    id: root

    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool dnd: false
    property bool airplaneOn: false

    signal toggled(string key)

    spacing: VitrailTokens.gap("xs")

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        tone: root.wifiOn ? "primary" : "secondary"
        icon: root.wifiOn ? "wifi" : "wifi_off"
        onClicked: root.toggled("wifi")
    }

    VitrailButton {
        Layout.fillWidth: true
        visible: root.bluetoothPresent
        variant: "text"
        tone: root.bluetoothOn ? "primary" : "secondary"
        icon: root.bluetoothOn ? "bluetooth" : "bluetooth_disabled"
        onClicked: root.toggled("bluetooth")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        tone: root.micMuted ? "error" : "secondary"
        icon: root.micMuted ? "mic_off" : "mic"
        onClicked: root.toggled("mic")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        tone: root.airplaneOn ? "primary" : "secondary"
        icon: root.airplaneOn ? "airplanemode_active" : "airplanemode_inactive"
        onClicked: root.toggled("airplane")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        tone: root.dnd ? "primary" : "secondary"
        icon: root.dnd ? "do_not_disturb_on" : "notifications"
        onClicked: root.toggled("dnd")
    }
}
