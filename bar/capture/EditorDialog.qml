import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// A small modal over the editor's card: the card dims, a glass surface holds a
// title, a message or any content, and Cancel / the accept button. Escape or a
// click outside is Cancel, Enter is accept (while `acceptable`). It takes the
// keyboard while open and every click, so nothing under it moves.
FocusScope {
    id: root

    property bool open: false
    property string title: ""
    property string message: ""
    property string accept: ""
    property string cancel: ""
    property bool acceptable: true
    default property alias content: body.data

    signal accepted()
    signal rejected()

    readonly property var editor: VitrailTokens.capture.editor

    visible: root.opacity > 0
    opacity: root.open ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }

    onOpenChanged: {
        if (root.open)
            root.forceActiveFocus()
        else
            root.focus = false
    }

    Keys.onEscapePressed: root.rejected()
    Keys.onReturnPressed: if (root.acceptable) root.accepted()
    Keys.onEnterPressed: if (root.acceptable) root.accepted()

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius
        color: Qt.alpha(VitrailTokens.color("surface"), root.editor.scrim)

        MouseArea {
            anchors.fill: parent
            onClicked: root.rejected()
        }
    }

    VitrailSurface {
        anchors.centerIn: parent
        width: root.editor.dialog.width
        height: column.implicitHeight + 2 * VitrailTokens.gap("lg")
        radius: VitrailTokens.radius

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: VitrailTokens.gap("lg")
            spacing: VitrailTokens.gap("md")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.title
                elide: Text.ElideRight
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.message !== ""
                variant: "content"
                wrapMode: Text.WordWrap
                text: root.message
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                Item {
                    Layout.fillWidth: true
                }

                VitrailButton {
                    variant: "outlined"
                    tone: "secondary"
                    size: "sm"
                    text: root.cancel
                    onClicked: root.rejected()
                }

                VitrailButton {
                    variant: "flat"
                    size: "sm"
                    enabled: root.acceptable
                    text: root.accept
                    onClicked: root.accepted()
                }
            }
        }
    }
}
