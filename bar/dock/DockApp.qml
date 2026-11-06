import QtQuick
import "../kit"
import "../kit/base"
import "dock.js" as Dock

// One app in the dock: its icon, the window indicator, and the pointer's
// magnification. A pinned app drags to a new place; an open one focuses its
// window and a closed one launches.
Item {
    id: root

    required property var app
    property int slot: 0

    property real iconSize: VitrailTokens.dock.icon
    property real cellSize: root.iconSize + 2 * VitrailTokens.gap("xs")
    property real step: root.cellSize + VitrailTokens.gap("xs")
    property int count: 1
    property string edge: "bottom"
    property string magnify: "planet"
    property int magnifyRange: VitrailTokens.dock.magnify.range
    property real magnifyScale: VitrailTokens.dock.magnify.scale
    property int hoveredIndex: -1
    property bool pinned: false
    property var strings: ({})
    // What the pointer reads (see references/tooltips.md).
    property string tooltip: root.app && root.app.name ? root.app.name : ""
    property string tooltipDetail: root.app && root.app.title
                                  ? root.app.title : root.t(root.app && root.app.open
                                                             ? "dock.tooltip.open" : "dock.tooltip.launch")
    property string tooltipEdge: root.edge
    // The tooltip host is full-screen while this layer is only the edge band:
    // the layer says where its band starts in screen coordinates.
    property real tooltipOriginX: 0
    property real tooltipOriginY: 0
    // The theme icon the caller resolved (the layer owns the Quickshell call).
    property string iconSource: ""
    readonly property bool hovered: hover.hovered
    readonly property bool vertical: Dock.vertical(root.edge)
    readonly property var effect: Dock.magnify(root.magnify, Math.abs(root.slot - root.hoveredIndex),
                                               { range: root.magnifyRange, scale: root.magnifyScale })
    property bool dragging: false
    property int dropAt: root.slot

    signal clicked()
    signal hoverChanged(bool on)
    signal dragFinished(int from, int to)
    signal dragStarted()
    signal dragEnded()

    implicitWidth: root.cellSize
    implicitHeight: root.cellSize
    activeFocusOnTab: true

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function activated() {
        if (!root.dragging)
            root.clicked()
    }

    Keys.onReturnPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    // A soft shape under the pointer; the active app keeps it lit.
    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius * 0.6
        color: VitrailTokens.color("primary", "#a8c7fa")
        opacity: root.app && root.app.active ? 0.24 : (root.hovered ? 0.14 : 0)

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    // The icon grows in place. The tile never changes size, so the row stays
    // steady while the pointer travels across it.
    Item {
        id: art

        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        scale: root.effect.scale

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

        Image {
            id: image

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(width, height)
            source: root.iconSource
            visible: status === Image.Ready
        }

        // A theme without the app's icon still shows the dock.
        VitrailIcon {
            anchors.centerIn: parent
            visible: !image.visible
            icon: "apps"
            pixelSize: root.iconSize * 0.8
            color: VitrailTokens.color("muted", "#9aa0a6")
        }
    }

    // Which apps have a window open, and which one has the focus.
    Rectangle {
        readonly property real dot: VitrailTokens.dock.indicator
        readonly property real inset: VitrailTokens.dock.indicatorInset

        width: dot
        height: dot
        radius: dot / 2
        color: VitrailTokens.color("primary", "#a8c7fa")
        opacity: root.app && root.app.open ? (root.app.active ? 1 : 0.65) : 0
        x: root.edge === "left" ? inset
           : root.edge === "right" ? root.width - inset - width
                                   : (root.width - width) / 2
        y: root.edge === "top" ? inset
           : root.edge === "bottom" ? root.height - inset - height
                                    : (root.height - height) / 2

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: root.hoverChanged(hover.hovered)
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    DragHandler {
        id: drag

        target: null
        enabled: root.pinned
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onActiveChanged: {
            root.dragging = drag.active
            if (drag.active) {
                root.dragStarted()
                return
            }
            root.z = 0
            root.opacity = 1
            root.dragEnded()
            root.dragFinished(root.slot, root.dropAt)
        }

        onTranslationChanged: {
            if (!drag.active)
                return
            var delta = root.vertical ? drag.activeTranslation.y : drag.activeTranslation.x
            root.z = 2
            root.opacity = 0.85
            root.dropAt = Dock.dropIndex(root.slot, delta, root.step, root.count)
        }
    }
}
