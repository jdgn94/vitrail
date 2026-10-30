import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../kit"
import "../kit/base"

// Apps that keep running in the background (StatusNotifierItem), with a
// chevron after them that folds them away. Folded, the chevron shows a dot
// when one of them asks for attention. A left click activates the app, a middle
// click its secondary action, a right click (or any click when the app only
// has a menu) opens its menu as a bar popout named "tray:<id>".
GridLayout {
    id: root

    property bool vertical: false
    property string openKind: ""
    property bool collapsed: false

    signal menuRequested(string kind, Item item)
    signal hovered(string kind, Item item)

    readonly property bool attention: SystemTray.items.values.some(function (item) {
        return item.status === Status.NeedsAttention
    })

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    // The icons, folded into nothing along the bar.
    Item {
        clip: true
        implicitWidth: root.vertical ? icons.implicitWidth : (root.collapsed ? 0 : icons.implicitWidth)
        implicitHeight: root.vertical ? (root.collapsed ? 0 : icons.implicitHeight) : icons.implicitHeight

        Behavior on implicitWidth { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        Behavior on implicitHeight { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

        GridLayout {
            id: icons

            opacity: root.collapsed ? 0 : 1
            flow: root.flow
            rowSpacing: root.rowSpacing
            columnSpacing: root.columnSpacing

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: entry

                    required property var modelData

                    readonly property string kind: "tray:" + entry.modelData.id

                    visible: entry.modelData.status !== Status.Passive
                    implicitWidth: VitrailTokens.size("title") + VitrailTokens.gap("sm")
                    implicitHeight: implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: VitrailTokens.radius / 2
                        color: VitrailTokens.color("primary")
                        opacity: root.openKind === entry.kind ? 0.16 : (hover.hovered ? 0.08 : 0)

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: VitrailTokens.size("title")
                        source: entry.modelData.icon
                        asynchronous: true
                    }

                    // An app asking for attention gets a dot.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 6
                        height: 6
                        radius: 3
                        visible: entry.modelData.status === Status.NeedsAttention
                        color: VitrailTokens.color("error")
                    }

                    HoverHandler {
                        id: hover

                        onHoveredChanged: if (hovered) root.hovered(entry.kind, entry)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.MiddleButton)
                                entry.modelData.secondaryActivate()
                            else if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu)
                                root.menuRequested(entry.kind, entry)
                            else
                                entry.modelData.activate()
                        }
                        onWheel: function (wheel) {
                            entry.modelData.scroll(wheel.angleDelta.y / 120, false)
                        }
                    }
                }
            }
        }
    }

    // On the anchored side of the icons, between them and the network button:
    // folding moves only the icons, the chevron stays put.
    VitrailButton {
        visible: SystemTray.items.values.length > 0
        variant: "plain"
        tone: "secondary"
        size: "sm"
        // Points to where the icons come from, or go to.
        icon: root.vertical ? (root.collapsed ? "expand_less" : "expand_more")
                            : (root.collapsed ? "chevron_left" : "chevron_right")
        onClicked: root.collapsed = !root.collapsed

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 6
            height: 6
            radius: 3
            visible: root.collapsed && root.attention
            color: VitrailTokens.color("error")
        }
    }
}
