import QtQuick
import "../kit"
import "../kit/base"

// The last button of the bar: the power icon. A left click opens the full
// session menu, a right click the same actions as a bar popout.
Item {
    id: root

    property bool opened: false
    property var strings: ({})

    signal clicked()
    signal menuRequested()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    // What the pointer reads: the button and what each click does.
    property string tooltip: root.t("tooltip.power")
    property string tooltipDetail: root.t("tooltip.powerHint")

    implicitWidth: glyph.implicitWidth + VitrailTokens.gap("sm")
    implicitHeight: glyph.implicitHeight + VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        visible: root.opened || root.hovered
        color: VitrailTokens.solid("error", root.opened ? 0.16 : 0.1)

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
    }

    VitrailText {
        id: glyph

        anchors.centerIn: parent
        variant: "icon"
        icon: "power_settings_new"
        color: root.opened || root.hovered ? VitrailTokens.color("error") : VitrailTokens.color("foreground")

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.menuRequested()
            else
                root.clicked()
        }
    }
}
