import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shared base for the login and lock screens.
//
// Both surfaces show the same material and the same card; the lock only adds
// extra widgets through the `extras` slot. Authentication is not handled here:
// the caller listens to `submitted` and decides what to do with the password.
Item {
    id: root

    property VitrailPalette palette: VitrailPalette {}
    property string username: ""
    property bool editableUsername: true
    property string title: ""
    property string userLabel: ""
    property string passwordLabel: ""
    property string actionLabel: ""
    property string wallpaper: ""

    signal submitted(string username, string password)

    default property alias extras: extrasLayout.data
    property alias header: headerLayout.data

    readonly property color surfaceColor: root.palette.surface || "#111318"
    readonly property color textColor: root.palette.foreground || "#e2e2e9"
    readonly property color mutedColor: root.palette.muted || "#c4c6d0"
    readonly property color accentColor: root.palette.primary || "#a8c7fa"
    readonly property color panelColor: root.palette.surfaceHigh || "#282a2f"

    Rectangle {
        id: background

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(root.surfaceColor, 1.25) }
            GradientStop { position: 1.0; color: Qt.darker(root.surfaceColor, 1.45) }
        }
    }

    Image {
        anchors.fill: parent
        visible: root.wallpaper !== ""
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        opacity: 0.45
    }

    // Soft vignette so the card always has contrast.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.25) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
        }
    }

    VitrailSurface {
        id: card

        anchors.centerIn: parent
        width: 380
        height: cardContent.implicitHeight + 56
        style: "glass"
        radius: 22
        tint: root.surfaceColor
        opacityLevel: 0.94

        ColumnLayout {
            id: cardContent

        x: 28
        y: 28
        width: card.width - 56
        spacing: 14

        ColumnLayout {
            id: headerLayout

            Layout.fillWidth: true
            spacing: 4
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 64
            implicitHeight: 64
            radius: 32
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)

            Text {
                anchors.centerIn: parent
                text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "V"
                color: root.accentColor
                font.pixelSize: 26
                font.family: VitrailTokens.fontFamily
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: root.title
            color: root.textColor
            font.pixelSize: 18
            font.family: VitrailTokens.fontFamily
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            visible: !root.editableUsername
            text: root.userLabel
            color: root.mutedColor
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
        }

        TextField {
            id: userField

            Layout.fillWidth: true
            visible: root.editableUsername
            text: root.username
            color: root.textColor
            placeholderText: root.userLabel
            placeholderTextColor: Qt.rgba(root.mutedColor.r, root.mutedColor.g, root.mutedColor.b, 0.6)
            font.pixelSize: 14
            font.family: VitrailTokens.fontFamily
            leftPadding: 14
            rightPadding: 14
            topPadding: 10
            bottomPadding: 10
            selectionColor: root.accentColor
            onTextEdited: root.username = text

            background: Rectangle {
                radius: 12
                color: Qt.rgba(root.panelColor.r, root.panelColor.g, root.panelColor.b, 0.75)
                border.width: 1
                border.color: userField.activeFocus
                             ? root.accentColor
                             : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.editableUsername
            text: root.username
            color: root.textColor
            font.pixelSize: 14
            font.family: VitrailTokens.fontFamily
            leftPadding: 2
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: root.passwordLabel
            color: root.mutedColor
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
        }

        TextField {
            id: passwordField

            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: root.passwordLabel
            placeholderTextColor: Qt.rgba(root.mutedColor.r, root.mutedColor.g, root.mutedColor.b, 0.6)
            color: root.textColor
            font.pixelSize: 14
            font.family: VitrailTokens.fontFamily
            leftPadding: 14
            rightPadding: 14
            topPadding: 10
            bottomPadding: 10
            selectionColor: root.accentColor
            onAccepted: root.submitted(root.username, text)

            background: Rectangle {
                radius: 12
                color: Qt.rgba(root.panelColor.r, root.panelColor.g, root.panelColor.b, 0.75)
                border.width: 1
                border.color: passwordField.activeFocus
                             ? root.accentColor
                             : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14)
            }
        }

        Rectangle {
            id: action

            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 42
            radius: 12
            color: actionArea.containsMouse
                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42)
                   : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)

            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: root.actionLabel
                color: root.textColor
                font.pixelSize: 14
                font.family: VitrailTokens.fontFamily
                font.weight: Font.Medium
            }

            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submitted(root.username, passwordField.text)
            }
        }

            ColumnLayout {
                id: extrasLayout

                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    Component.onCompleted: {
        if (root.editableUsername)
            userField.forceActiveFocus()
        else
            passwordField.forceActiveFocus()
    }
}
