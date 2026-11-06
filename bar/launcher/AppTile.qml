import QtQuick
import Quickshell
import "../kit"
import "../kit/base"

// One app in the grid: its icon over its name. The selection ring follows the
// keyboard, the pointer lights the tile up; a pin marks a favourite.
Item {
    id: tile

    property string name: ""
    property string detail: ""
    // Theme icon name.
    property string icon: ""
    property bool selected: false
    property bool pinned: false
    // From the launcher variant: icon edge, name text variant and lines.
    property real iconSize: VitrailTokens.launcher.popout.tileIcon
    property string labelVariant: "label"
    property int lines: 1

    // What the pointer reads (see references/tooltips.md).
    property string tooltip: tile.name
    property string tooltipDetail: tile.detail
    readonly property bool hovered: hover.hovered

    signal clicked()
    signal contextRequested()

    readonly property real textHeight: Math.ceil(label.font.pixelSize * 1.4) * tile.lines
    // Every tile holds its full lines, so a row of tiles stays level.
    implicitHeight: art.height + tile.textHeight + 3 * VitrailTokens.gap("sm")

    Rectangle {
        anchors.fill: parent
        anchors.margins: VitrailTokens.gap("xs") / 2
        radius: VitrailTokens.radius / 2
        color: tile.selected ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
        opacity: tile.selected ? 0.16 : (tile.hovered ? 0.06 : 0)

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover
    }

    Image {
        id: art

        anchors.top: parent.top
        anchors.topMargin: VitrailTokens.gap("sm")
        anchors.horizontalCenter: parent.horizontalCenter
        width: tile.iconSize
        height: width
        sourceSize: Qt.size(width, height)
        source: tile.icon === "" ? "" : Quickshell.iconPath(tile.icon, true)
        visible: status === Image.Ready
        asynchronous: true
        scale: pointer.pressedButtons ? 0.94 : 1

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }
    }

    // An app whose icon the theme does not have.
    VitrailIcon {
        anchors.centerIn: art
        visible: !art.visible
        pixelSize: art.width * 0.8
        icon: "apps"
        color: VitrailTokens.color("muted")
    }

    VitrailIcon {
        visible: tile.pinned
        anchors.top: art.top
        anchors.left: art.right
        anchors.leftMargin: -VitrailTokens.gap("sm")
        icon: "push_pin"
        color: VitrailTokens.color("primary")
    }

    VitrailText {
        id: label

        anchors.top: art.bottom
        anchors.topMargin: VitrailTokens.gap("sm")
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: VitrailTokens.gap("xs")
        anchors.rightMargin: VitrailTokens.gap("xs")
        horizontalAlignment: Text.AlignHCenter
        variant: tile.labelVariant
        color: VitrailTokens.color("foreground")
        opacity: 1
        elide: Text.ElideRight
        wrapMode: tile.lines > 1 ? Text.Wrap : Text.NoWrap
        maximumLineCount: tile.lines
        height: tile.textHeight
        verticalAlignment: Text.AlignTop
        text: tile.name
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                tile.contextRequested()
            else
                tile.clicked()
        }
    }
}
