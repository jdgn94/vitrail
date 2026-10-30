import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "actions.js" as Session

// The session actions as a bar popout: icon and label rows with a pill
// hover, the destructive one in the error tone, like the tray menus.
ColumnLayout {
    id: root

    property var strings: ({})
    property bool canHibernate: false

    signal chosen(string key)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    readonly property int rowWidth: 220

    spacing: 2

    Repeater {
        model: Session.available(root.canHibernate)

        delegate: Item {
            id: row

            required property var modelData

            readonly property color ink: VitrailTokens.color(row.modelData.tone === "error" ? "error" : "foreground")

            Layout.preferredWidth: root.rowWidth
            implicitHeight: line.implicitHeight + 2 * VitrailTokens.gap("xs")

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: row.ink
                opacity: hover.hovered ? 0.1 : 0

                Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
            }

            RowLayout {
                id: line

                anchors.verticalCenter: parent.verticalCenter
                x: VitrailTokens.gap("sm")
                width: parent.width - 2 * VitrailTokens.gap("sm")
                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    variant: "icon"
                    font.pixelSize: VitrailTokens.size("body") + 2
                    text: row.modelData.icon
                    color: row.ink
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    elide: Text.ElideRight
                    text: root.t(row.modelData.label)
                    color: row.ink
                }
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.chosen(row.modelData.key)
            }
        }
    }
}
