import QtQuick
import QtQuick.Layouts
import Quickshell
import "../kit"
import "../kit/base"

// One line of a list: icon, title and detail, and at the end a hint (the
// Ctrl+N that runs it) or a busy indicator. The keyboard selection tints it,
// the pointer lights it up.
Item {
    id: row

    property string title: ""
    property string subtitle: ""
    // A theme icon name and, when there is none, a Material glyph.
    property string appIcon: ""
    property string glyph: "apps"
    // A picture to show instead of the icon (a wallpaper), wider than it.
    property string thumbnail: ""
    readonly property real artWidth: row.thumbnail !== "" ? Math.round(row.iconSize * 1.75) : row.iconSize
    property string hint: ""
    property bool selected: false
    property bool busy: false
    property bool pinned: false
    // A way to the app's own menu, drawn at the end.
    property bool hasMenu: false
    // From the launcher variant: icon edge.
    property real iconSize: VitrailTokens.launcher.popout.rowIcon

    // What the pointer reads (see references/tooltips.md).
    property string tooltip: row.title
    property string tooltipDetail: row.subtitle
    readonly property bool hovered: hover.hovered

    signal clicked()
    signal contextRequested()

    Layout.fillWidth: true
    implicitHeight: Math.max(line.implicitHeight, row.iconSize) + 2 * VitrailTokens.gap("sm")

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: row.selected ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
        opacity: row.selected ? 0.16 : (row.hovered ? 0.06 : 0)

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover
    }

    RowLayout {
        id: line

        anchors.verticalCenter: parent.verticalCenter
        x: VitrailTokens.gap("sm")
        width: parent.width - 2 * VitrailTokens.gap("sm")
        spacing: VitrailTokens.gap("sm")

        Item {
            // Icons differ in size; a fixed slot keeps the names aligned.
            Layout.preferredWidth: row.artWidth
            Layout.preferredHeight: row.iconSize
            clip: true

            Image {
                anchors.fill: parent
                visible: row.thumbnail !== ""
                source: row.thumbnail === "" ? "" : "file://" + row.thumbnail
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                radius: VitrailTokens.radius / 3
                color: "transparent"
                visible: row.thumbnail !== ""
                border.width: 1
                border.color: row.selected ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
                opacity: 0.25
            }

            Image {
                id: art

                anchors.fill: parent
                visible: row.thumbnail === "" && status === Image.Ready
                sourceSize: Qt.size(width, height)
                source: row.appIcon === "" ? "" : Quickshell.iconPath(row.appIcon, true)
                asynchronous: true
            }

            VitrailIcon {
                anchors.centerIn: parent
                visible: row.thumbnail === "" && !art.visible
                icon: row.glyph
                color: row.selected ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                color: VitrailTokens.color("foreground")
                opacity: 1
                elide: Text.ElideRight
                text: row.title
            }

            VitrailText {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                variant: "label"
                elide: Text.ElideRight
                text: row.subtitle
            }
        }

        VitrailIcon {
            visible: row.pinned
            icon: "push_pin"
            color: VitrailTokens.color("primary")
        }

        VitrailText {
            visible: row.hint !== "" && !row.busy
            variant: "label"
            text: row.hint
        }

        VitrailIcon {
            visible: row.hasMenu && (row.selected || row.hovered)
            icon: "chevron_right"
        }

        VitrailBusy {
            visible: row.busy
            running: row.busy
            size: VitrailTokens.size("subtitle")
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                row.contextRequested()
            else
                row.clicked()
        }
    }
}
