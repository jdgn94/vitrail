import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../kit"
import "../kit/base"

// The tray apps as a list, for the popup style: a click activates the app, a
// right click opens its menu.
ColumnLayout {
    id: root

    property var strings: ({})

    signal activated(var item)
    signal menuRequested(var item, var entry)

    spacing: VitrailTokens.gap("xs")

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: row

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: VitrailTokens.size("title") + VitrailTokens.gap("sm")
            visible: row.modelData.status !== Status.Passive

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: VitrailTokens.solid("primary", hover.hovered ? 0.14 : 0.06)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VitrailTokens.gap("sm")
                anchors.rightMargin: VitrailTokens.gap("sm")
                spacing: VitrailTokens.gap("sm")

                IconImage {
                    id: glyph

                    Layout.preferredWidth: VitrailTokens.size("title")
                    Layout.preferredHeight: width
                    source: row.modelData.icon
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    Layout.preferredWidth: VitrailTokens.size("title")
                    Layout.preferredHeight: width
                    source: glyph
                    colorization: 1
                    colorizationColor: VitrailTokens.color("foreground")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    elide: Text.ElideRight
                    text: row.modelData.title || row.modelData.id
                }
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
                        root.menuRequested(row.modelData, row)
                    else
                        root.activated(row.modelData)
                }
            }
        }
    }
}
