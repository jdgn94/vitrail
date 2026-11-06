import Quickshell
import Quickshell.Wayland
import QtQuick
import "../kit"
import "dock.js" as Dock

// The dock of one monitor: its edge band, the hot zone that reveals an
// auto-hidden dock, and the card itself (Dock.qml). Only the card and the hot
// zone take input; attached and visible, the band reserves its space, while a
// floating or auto-hidden dock reserves nothing.
PanelWindow {
    id: root

    property bool enabled: false
    // The bar's own fullscreen or editor state made the dock step aside.
    property bool hidden: false
    property string edge: "bottom"
    property bool autohide: false
    property bool attached: true
    property string magnify: "planet"
    property int magnifyRange: VitrailTokens.dock.magnify.range
    property real magnifyScale: VitrailTokens.dock.magnify.scale
    property var pinned: []
    property var windows: []
    property var strings: ({})
    property real opacityLevel: VitrailTokens.opacity
    property var iconProvider: null
    // The pointer has reached the hot zone: the card is out.
    property bool revealed: false

    readonly property var look: VitrailStyle.resolve("dock", root.attached ? "attached" : "floating")
    readonly property var metrics: VitrailTokens.dock
    readonly property bool vertical: Dock.vertical(root.edge)
    readonly property real margin: Dock.margin(root.attached, VitrailTokens.gap(root.look.margin || "md"))
    // Floating and magnified, the window keeps room for the growth around the
    // card so the icon is never cut by the layer's edge.
    readonly property real growth: root.magnify === "none" ? 0
                                 : root.metrics.icon * (root.magnifyScale - 1)
    readonly property real band: (root.vertical ? dock.implicitWidth : dock.implicitHeight)
                                 + 2 * root.margin + root.growth
    // The card plus its margin is what the compositor reserves; the room that
    // hover magnification needs stays free.
    readonly property real reserved: (root.vertical ? dock.implicitWidth : dock.implicitHeight)
                                     + 2 * root.margin
    readonly property bool active: root.enabled && !root.hidden && dock.count > 0
    readonly property bool shown: dock.shown

    signal launchRequested(var app, var rect)
    signal focusRequested(var app)
    signal reordered(string text)
    signal hovered(var item, bool on)

    visible: root.active
    anchors {
        top: root.edge === "top" || root.vertical
        bottom: root.edge === "bottom" || root.vertical
        left: root.vertical ? root.edge === "left" : true
        right: root.vertical ? root.edge === "right" : true
    }
    implicitWidth: root.vertical ? root.band : root.screen.width
    implicitHeight: root.vertical ? root.screen.height : root.band
    color: "transparent"
    // Only a dock that stays out and is attached to the edge reserves the
    // pixels it covers; floating and auto-hidden docks leave the windows alone.
    exclusionMode: root.active && root.attached && !root.autohide ? ExclusionMode.Normal
                                                                   : ExclusionMode.Ignore
    exclusiveZone: root.reserved
    // The bar's namespace: the compositor's glass rule blurs the dock with the
    // rest of the shell instead of leaving an unblurred rectangle.
    WlrLayershell.namespace: "vitrail-bar"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: !root.active ? null
              : root.shown || !root.autohide ? bandMask
                                             : hotZone
    }

    onAutohideChanged: if (!root.autohide)
                           root.revealed = false

    Timer {
        id: hideTimer

        interval: VitrailTokens.dock.hide
        onTriggered: if (!bandHover.hovered && !dock.dragging)
                         root.revealed = false
    }

    function reveal() {
        hideTimer.stop()
        root.revealed = true
    }

    Item {
        id: bandMask

        anchors.fill: parent
    }

    // The invisible strip on the very edge: with the dock hidden it is the
    // only part of the window that takes the pointer.
    Item {
        id: hotZone

        readonly property real thickness: VitrailTokens.dock.hot

        x: root.edge === "right" ? root.width - width : 0
        y: root.edge === "bottom" ? root.height - height : 0
        width: root.vertical ? thickness : parent.width
        height: root.vertical ? parent.height : thickness

        HoverHandler {
            id: hotHover

            enabled: root.autohide && !root.shown

            onHoveredChanged: if (hovered)
                                  root.reveal()
        }
    }

    HoverHandler {
        id: bandHover

        enabled: root.autohide

        onHoveredChanged: {
            if (hovered) {
                hideTimer.stop()
                root.revealed = true
            } else if (!dock.dragging) {
                hideTimer.restart()
            }
        }
    }

    Dock {
        id: dock

        readonly property var place: Dock.place(root.edge, root.width, root.height, dock.width, dock.height,
                                                root.margin, dock.progress)

        x: dock.place.x
        y: dock.place.y
        width: implicitWidth
        height: implicitHeight
        pinned: root.pinned
        windows: root.windows
        edge: root.edge
        attached: root.attached
        autohide: root.autohide
        revealed: root.revealed
        magnify: root.magnify
        magnifyRange: root.magnifyRange
        magnifyScale: root.magnifyScale
        strings: root.strings
        opacityLevel: root.opacityLevel
        iconProvider: root.iconProvider
        tooltipOriginX: root.edge === "right" ? root.screen.width - root.band : 0
        tooltipOriginY: root.edge === "bottom" ? root.screen.height - root.band : 0
        onDraggingChanged: {
            if (dock.dragging) {
                root.reveal()
            } else if (!bandHover.hovered) {
                hideTimer.restart()
            }
        }
        onLaunchRequested: function (app, rect) {
            // The tile's scene rect is local to the dock's band; the drop
            // lives on the full-screen layer, so add where the band sits.
            root.launchRequested(app, rect ? Qt.rect(rect.x + dock.tooltipOriginX,
                                                    rect.y + dock.tooltipOriginY,
                                                    rect.width, rect.height) : null)
        }
        onFocusRequested: function (app) { root.focusRequested(app) }
        onReordered: function (text) { root.reordered(text) }
        onHovered: function (item, on) { root.hovered(item, on) }
    }
}
