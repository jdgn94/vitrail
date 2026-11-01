import QtQuick

// Small on/off switch used by the settings categories.
Rectangle {
    id: root

    property bool checked: false
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")

    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: root.checked
           ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85)
           : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

    Behavior on color { ColorAnimation { duration: 160 } }

    Rectangle {
        width: 20
        height: 20
        radius: 10
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? root.accent : root.foreground

        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    // Keyboard: Tab reaches it, Enter or Space flips it, and the ring shows
    // where the keyboard is.
    activeFocusOnTab: root.enabled
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: root.accent
        visible: root.activeFocus
    }
}
