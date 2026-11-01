import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../kit"
import "../kit/base"

// The tray apps as a grid of icons, for the popup style: one row while they
// are few, wrapping after `tray.columns`. A click activates the app, a right
// click opens its menu.
GridLayout {
    id: root

    property var strings: ({})

    readonly property int visibleCount: SystemTray.items.values.filter(function (item) {
        return item.status !== Status.Passive
    }).length

    signal activated(var item)
    signal menuRequested(var item, var entry)
    // The pointer entered or left an icon (for its tooltip).
    signal tipHovered(var item, Item cell, bool on)

    columns: Math.max(1, Math.min(root.visibleCount, VitrailTokens.tray.columns))
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    // Keyboard: the arrows move through the grid, skipping the hidden cells.
    function move(from, delta) {
        for (var i = from + delta; i >= 0 && i < cells.count; i += delta) {
            var item = cells.itemAt(i)
            if (item && item.visible) {
                item.forceActiveFocus()
                return
            }
        }
    }

    Repeater {
        id: cells

        model: SystemTray.items

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            // A hidden cell reserves no space in the grid.
            visible: cell.modelData.status !== Status.Passive
            implicitWidth: VitrailTokens.size("title") + VitrailTokens.gap("sm")
            implicitHeight: implicitWidth

            // A click or Enter: the menu for an app that only has one.
            function activate() {
                if (cell.modelData.onlyMenu)
                    root.menuRequested(cell.modelData, cell)
                else
                    root.activated(cell.modelData)
            }

            // Keyboard: Tab reaches each icon, the arrows move through the
            // grid, Enter or Space activates it and the menu key (or
            // Shift+F10) opens its menu.
            activeFocusOnTab: cell.visible
            Keys.onReturnPressed: cell.activate()
            Keys.onSpacePressed: cell.activate()
            Keys.onMenuPressed: root.menuRequested(cell.modelData, cell)
            Keys.onLeftPressed: root.move(cell.index, -1)
            Keys.onRightPressed: root.move(cell.index, 1)
            Keys.onUpPressed: root.move(cell.index, -root.columns)
            Keys.onDownPressed: root.move(cell.index, root.columns)
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) {
                    root.menuRequested(cell.modelData, cell)
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: VitrailTokens.color("primary")
                opacity: hover.hovered ? 0.08 : 0

                Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
            }

            // The app's own colours give way to the colour scheme.
            IconImage {
                id: glyph

                anchors.centerIn: parent
                implicitSize: VitrailTokens.size("title")
                source: cell.modelData.icon
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: glyph
                source: glyph
                colorization: 1
                colorizationColor: hover.hovered ? VitrailTokens.color("primary")
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
                visible: cell.modelData.status === Status.NeedsAttention
                color: VitrailTokens.color("error")
            }

            HoverHandler {
                id: hover

                onHoveredChanged: root.tipHovered(cell.modelData, cell, hovered)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    if (mouse.button === Qt.RightButton)
                        root.menuRequested(cell.modelData, cell)
                    else
                        cell.activate()
                }
            }

            // Where the keyboard is.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.width: cell.activeFocus ? 2 : 0
                border.color: VitrailTokens.color("primary")
                visible: cell.activeFocus
            }
        }
    }
}
