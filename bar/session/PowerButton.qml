import QtQuick
import "../kit"
import "../kit/base"

// The last button of the bar: the power icon. A left click opens the full
// session menu, a right click the same actions as a bar popout.
Item {
    id: root

    property bool opened: false

    signal clicked()
    signal menuRequested()

    readonly property alias hovered: hover.hovered

    implicitWidth: glyph.implicitWidth + VitrailTokens.gap("sm")
    implicitHeight: glyph.implicitHeight + VitrailTokens.gap("xs")

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: VitrailTokens.color("error")
        opacity: root.opened ? 0.16 : (root.hovered ? 0.1 : 0)

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    VitrailText {
        id: glyph

        anchors.centerIn: parent
        variant: "icon"
        text: "power_settings_new"
        color: root.opened || root.hovered ? VitrailTokens.color("error") : VitrailTokens.color("foreground")

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
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
