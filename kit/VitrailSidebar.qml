import QtQuick
import QtQuick.Layouts
import "base"

// Collapsible navigation rail.
//
// A collapse toggle and the items, grouped: an item whose `group`
// differs from the previous one opens a new labelled group. One pill marks
// the current item and slides to the next; its icon fills. Collapsed, only
// the icons remain.
Item {
    id: root

    // [{ key, glyph, label, group }]; `groups` maps a group key to its label.
    property var items: []
    property var groups: ({})
    property string current: ""
    property bool collapsed: false
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")

    signal selected(string key)

    readonly property int currentIndex: root.items.findIndex(function (item) {
        return item.key === root.current
    })
    readonly property Item currentRow: rows.count > 0 && root.currentIndex >= 0
                                       ? rows.itemAt(root.currentIndex) : null
    property bool settled: false

    implicitWidth: root.collapsed ? 64 : 216

    Behavior on implicitWidth { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

    Component.onCompleted: Qt.callLater(function () { root.settled = true })

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // The current-item pill, under the rows.
        Rectangle {
            x: 0
            y: root.currentRow ? column.y + root.currentRow.y + root.currentRow.entryY : 0
            width: root.width
            height: 46
            visible: root.currentRow !== null
            radius: height / 2
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

            Behavior on y { enabled: root.settled; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        }

        ColumnLayout {
            id: column

            width: root.width
            spacing: 2

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: root.collapsed ? "menu" : "menu_open"
                Layout.leftMargin: (64 - implicitWidth) / 2 - 2
                onClicked: root.collapsed = !root.collapsed
            }

            Repeater {
                id: rows

                model: root.items

                delegate: ColumnLayout {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool opensGroup: row.index > 0
                                                       && row.modelData.group !== root.items[row.index - 1].group
                    readonly property bool active: root.current === row.modelData.key
                    // The pill covers the entry itself, not its group label.
                    readonly property real entryY: entry.y

                    Layout.preferredWidth: root.width
                    spacing: 0

                    Text {
                        Layout.topMargin: VitrailTokens.gap("md")
                        Layout.bottomMargin: VitrailTokens.gap("xs")
                        Layout.leftMargin: 20
                        visible: row.opensGroup || row.index === 0
                        opacity: root.collapsed ? 0 : 0.6
                        text: (root.groups[row.modelData.group] || "").toUpperCase()
                        color: root.foreground
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        font.weight: Font.Medium
                        font.family: VitrailTokens.fontFamily

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                    }

                    Item {
                        id: entry

                        Layout.preferredWidth: root.width
                        Layout.preferredHeight: 46

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: root.foreground
                            opacity: hover.hovered && !row.active ? 0.06 : 0

                            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                        }

                        HoverHandler {
                            id: hover
                        }

                        Text {
                            x: (64 - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.glyph
                            color: row.active ? root.accent : root.foreground
                            font.family: VitrailTokens.iconFamily
                            font.variableAxes: ({ "FILL": row.active ? 1 : 0 })
                            font.pixelSize: 22

                            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
                        }

                        Text {
                            x: 64
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.width - x - 12
                            opacity: root.collapsed ? 0 : 1
                            text: row.modelData.label
                            color: row.active ? root.accent : root.foreground
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: row.active ? Font.DemiBold : Font.Normal
                            font.family: VitrailTokens.fontFamily

                            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected(row.modelData.key)
                        }
                    }
                }
            }
        }
    }
}
