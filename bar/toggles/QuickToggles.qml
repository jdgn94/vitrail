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
    // sm / md / lg: the pills grow with the panel widget's size.
    property string size: "md"
    // The widget's own typography; the pills are icon-only today, but the
    // buttons take it like every other control.
    property string fontFamily: ""
    property string fontWeight: ""
    property bool italic: false

    signal toggled(string key)

    spacing: VitrailTokens.gap("xs")

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        fontFamily: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        size: root.size
        tone: root.wifiOn ? "primary" : "secondary"
        icon: root.wifiOn ? "wifi" : "wifi_off"
        onClicked: root.toggled("wifi")
    }

    VitrailButton {
        Layout.fillWidth: true
        visible: root.bluetoothPresent
        variant: "text"
        fontFamily: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        size: root.size
        tone: root.bluetoothOn ? "primary" : "secondary"
        icon: root.bluetoothOn ? "bluetooth" : "bluetooth_disabled"
        onClicked: root.toggled("bluetooth")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        fontFamily: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        size: root.size
        tone: root.micMuted ? "error" : "secondary"
        icon: root.micMuted ? "mic_off" : "mic"
        onClicked: root.toggled("mic")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        fontFamily: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        size: root.size
        tone: root.airplaneOn ? "primary" : "secondary"
        icon: root.airplaneOn ? "airplanemode_active" : "airplanemode_inactive"
        onClicked: root.toggled("airplane")
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        fontFamily: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        size: root.size
        tone: root.dnd ? "primary" : "secondary"
        icon: root.dnd ? "do_not_disturb_on" : "notifications"
        onClicked: root.toggled("dnd")
    }
}
