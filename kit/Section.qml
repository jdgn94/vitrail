import QtQuick
import QtQuick.Layouts

// Titled block of settings: a Material icon and a title, an optional badge
// that says how it applies, then its rows.
ColumnLayout {
    id: root

    property string title: ""
    property string icon: ""
    property string badge: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")

    default property alias content: holder.data

    spacing: VitrailTokens.gap("sm")

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.foreground
            font.family: VitrailTokens.iconFamily
            font.pixelSize: 22
        }

        Text {
            text: root.title
            color: root.foreground
            font.pixelSize: 18
            font.weight: Font.Medium
            font.family: VitrailTokens.fontFamily
        }

        Rectangle {
            visible: root.badge !== ""
            implicitWidth: badgeLabel.implicitWidth + 14
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

            Text {
                id: badgeLabel

                anchors.centerIn: parent
                text: root.badge
                color: root.accent
                font.pixelSize: 10
                font.family: VitrailTokens.fontFamily
            }
        }

        Item { Layout.fillWidth: true }
    }

    ColumnLayout {
        id: holder

        Layout.fillWidth: true
        Layout.leftMargin: VitrailTokens.gap("xs")
        spacing: VitrailTokens.gap("sm")
    }
}
