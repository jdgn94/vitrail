import QtQuick
import QtQuick.Layouts
import "base"

// One setting: a Material icon, its name and an optional hint, with the
// control (switch, segmented, button…) on the right.
RowLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string description: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color muted: VitrailTokens.color("muted", "#c4c6d0")

    default property alias control: slot.data

    Layout.fillWidth: true
    spacing: VitrailTokens.gap("sm")

    VitrailIcon {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 1
        Layout.preferredWidth: 24
        visible: root.icon !== ""
        icon: root.icon
        color: root.muted
        pixelSize: 20
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.label
            color: root.foreground
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            font.family: VitrailTokens.fontFamily
        }

        Text {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            color: root.muted
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
        }
    }

    RowLayout {
        id: slot

        Layout.alignment: Qt.AlignVCenter
        spacing: VitrailTokens.gap("xs")
    }
}
