import QtQuick
import "../kit"
import "../kit/base"

// The power profile button in the connection chip: a leaf for the saver, the
// scales for balanced, a speedometer for performance. The mode comes from
// power-profiles-daemon through the shell; its popup holds the selector.
Item {
    id: root

    property bool opened: false
    property var strings: ({})
    // power-saver / balanced / performance.
    property string profile: "balanced"

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    readonly property var modes: ({
        "power-saver": { icon: "energy_savings_leaf", tone: "primary", name: "connection.power.saver",
                         detail: "powerprofile.saver.detail" },
        "balanced": { icon: "balance", tone: "muted", name: "connection.power.balanced",
                      detail: "powerprofile.balanced.detail" },
        "performance": { icon: "speed", tone: "info", name: "connection.power.performance",
                         detail: "powerprofile.performance.detail" }
    })
    readonly property var mode: root.modes[root.profile] || root.modes.balanced

    // What the pointer reads: the mode and what it does.
    property string tooltip: root.t("connection.power") + " · " + root.t(root.mode.name)
    property string tooltipDetail: root.t(root.mode.detail)

    implicitWidth: glyph.implicitWidth + VitrailTokens.gap("sm")
    // Square, so the round background fits the chip's pill.
    implicitHeight: implicitWidth

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: root.opened
        color: VitrailTokens.solid("primary", 0.16)
    }

    VitrailIcon {
        id: glyph

        anchors.centerIn: parent
        icon: root.mode.icon
        color: VitrailTokens.color(root.mode.tone)
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
