import QtQuick
import QtQuick.Effects
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
    // The bar's edge (left, top, right or bottom): the popup style points the
    // chevron away from it.
    property string barEdge: "left"
    property string openKind: ""
    property bool collapsed: true
    // inline: the icons fold out beside the chevron; popup: a list opens.
    property string style: "inline"
    property var strings: ({})

    signal menuRequested(string kind, Item item)
    signal hovered(string kind, Item item)
    // The pointer entered or left an element (for its tooltip).
    signal tipHovered(Item item, bool on)

    readonly property int visibleCount: SystemTray.items.values.filter(function (item) {
        return item.status !== Status.Passive
    }).length
    readonly property bool attention: SystemTray.items.values.some(function (item) {
        return item.status === Status.NeedsAttention
    })

    // The icons are out (inline) or the list is open (popup).
    readonly property bool expanded: root.style === "popup" ? root.openKind === "tray" : !root.collapsed
    // Where the chevron points, folded: where the icons come from (they
    // precede it in the flow) or, for the popup, where it opens (away from
    // the bar's edge). Degrees of the right-pointing glyph; expanding turns it
    // half a revolution.
    readonly property int heading: root.style === "popup"
        ? ({ top: 90, bottom: 270, left: 0, right: 180 })[root.barEdge]
        : (root.vertical ? 270 : 180)

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The icons, folded into nothing along the bar.
    Item {
        clip: true
        visible: root.style === "inline"
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
                    readonly property bool opened: root.openKind === entry.kind
                    readonly property alias pressed: area.pressed

                    // What the pointer reads: what the app says about itself.
                    property string tooltip: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                    property string tooltipDetail: entry.modelData.tooltipDescription

                    visible: entry.modelData.status !== Status.Passive
                    implicitWidth: VitrailTokens.size("title") + VitrailTokens.gap("sm")
                    implicitHeight: implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: VitrailTokens.radius / 2
                        color: VitrailTokens.color("primary")
                        opacity: entry.opened ? 0.16 : (hover.hovered ? 0.08 : 0)

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                    }

                    // The app's own colours give way to the colour scheme.
                    IconImage {
                        id: glyph

                        anchors.centerIn: parent
                        implicitSize: VitrailTokens.size("title")
                        source: entry.modelData.icon
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: glyph
                        source: glyph
                        colorization: 1
                        colorizationColor: entry.opened || hover.hovered ? VitrailTokens.color("primary")
                                                                          : VitrailTokens.color("foreground")

                        Behavior on colorizationColor { ColorAnimation { duration: VitrailTokens.duration("fast") } }
                    }

                    // An app asking for attention gets a dot.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: VitrailTokens.tray.dot
                        height: VitrailTokens.tray.dot
                        radius: VitrailTokens.tray.dot / 2
                        visible: entry.modelData.status === Status.NeedsAttention
                        color: VitrailTokens.color("error")
                    }

                    HoverHandler {
                        id: hover

                        onHoveredChanged: {
                            root.tipHovered(entry, hovered)
                            if (hovered)
                                root.hovered(entry.kind, entry)
                        }
                    }

                    MouseArea {
                        id: area

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
    // folding moves only the icons, the chevron stays put and turns.
    VitrailButton {
        id: chevron

        // What the pointer reads: what a click does, and how many apps.
        property string tooltip: root.t(root.expanded ? "tooltip.trayHide" : "tooltip.trayShow").replace("%1", root.visibleCount)

        visible: SystemTray.items.values.length > 0
        variant: "plain"
        tone: "secondary"
        size: "sm"
        icon: "chevron_right"
        rotation: root.heading + (root.expanded ? 180 : 0)
        Behavior on rotation { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        Layout.alignment: Qt.AlignCenter
        onClicked: {
            if (root.style === "popup")
                root.menuRequested("tray", chevron)
            else
                root.collapsed = !root.collapsed
        }
        onHoveredChanged: root.tipHovered(chevron, chevron.hovered)

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: VitrailTokens.tray.dot
            height: VitrailTokens.tray.dot
            radius: VitrailTokens.tray.dot / 2
            visible: root.collapsed && root.attention
            color: VitrailTokens.color("error")
        }
    }

}
