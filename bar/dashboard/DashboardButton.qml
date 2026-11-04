import QtQuick
import "../kit"
import "../kit/base"

// The dashboard's bar element: one glyph, highlighted while its popup is
// open, and a tooltip naming the three things it shows.
Item {
    id: root

    property bool opened: false
    property var strings: ({})

    signal clicked()

    readonly property alias hovered: hover.hovered

    property string tooltip: root.t("dashboard.title")
    property string tooltipDetail: root.t("dashboard.tooltip")

    implicitWidth: icon.implicitWidth + VitrailTokens.gap("sm")
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

    VitrailText {
        id: icon

        anchors.centerIn: parent
        variant: "icon"
        text: "space_dashboard"
        color: root.opened ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
        opacity: root.opened ? 1 : 0.75
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
