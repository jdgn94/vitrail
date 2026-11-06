import QtQuick
import "../kit"
import "dock.js" as Dock

// The dock itself: pinned apps in their stored order, then the open windows
// that are not pinned. Attached it is flush with the edge; floating it keeps a
// margin and round corners. An auto-hidden dock slides back in when `revealed`
// turns true.
Item {
    id: root

    property var pinned: []
    property var windows: []
    property string edge: "bottom"
    property bool attached: true
    property bool autohide: false
    property bool revealed: false
    property bool forceShown: false
    property string magnify: "planet"
    property int magnifyRange: VitrailTokens.dock.magnify.range
    property real magnifyScale: VitrailTokens.dock.magnify.scale
    property var strings: ({})
    property real opacityLevel: VitrailTokens.opacity
    // Maps an app icon name to a theme file; the layer supplies it.
    property var iconProvider: null
    property real tooltipOriginX: 0
    property real tooltipOriginY: 0
    property int hoveredIndex: -1
    property bool dragging: false

    readonly property var look: VitrailStyle.resolve("dock", root.attached ? "attached" : "floating")
    readonly property var metrics: VitrailTokens.dock
    readonly property bool vertical: Dock.vertical(root.edge)
    readonly property var items: Dock.model(root.pinned, root.windows)
    readonly property int count: root.items.length
    readonly property bool shown: Dock.shown(root.autohide, root.revealed, root.forceShown || root.dragging)
    property real progress: root.shown ? 1 : 0
    readonly property real pad: VitrailTokens.gap(root.metrics.pad)
    readonly property real gap: VitrailTokens.gap(root.metrics.gap)
    readonly property real cell: root.metrics.icon + 2 * VitrailTokens.gap("xs")
    readonly property real contentWidth: root.vertical || root.count === 0
                                          ? root.cell
                                          : root.count * root.cell + (root.count - 1) * root.gap
    readonly property real contentHeight: !root.vertical || root.count === 0
                                           ? root.cell
                                           : root.count * root.cell + (root.count - 1) * root.gap
    readonly property real margin: Dock.margin(root.attached, VitrailTokens.gap(root.look.margin || "md"))

    signal launchRequested(var app)
    signal focusRequested(var app)
    signal reordered(string text)
    signal hovered(var item, bool on)

    implicitWidth: root.contentWidth + 2 * root.pad
    implicitHeight: root.contentHeight + 2 * root.pad

    Behavior on progress {
        NumberAnimation { duration: VitrailTokens.duration(root.look.motion); easing.type: Easing.OutCubic }
    }

    function activate(app) {
        if (Dock.activates(app))
            root.focusRequested(app)
        else
            root.launchRequested(app)
    }

    // A drag ends on a whole cell: the caller stores the new document.
    function movePinned(from, to) {
        root.reordered(Dock.serializePinned(Dock.move(root.pinned, from, to)))
    }

    VitrailSurface {
        anchors.fill: parent
        radius: Dock.radius(root.attached, VitrailTokens.radius * (root.look.radius || 0))
        tint: VitrailTokens.color("surfaceHigh", "#282a2f")
        opacityLevel: root.opacityLevel
    }

    Grid {
        id: grid

        x: root.pad
        y: root.pad
        columns: root.vertical ? 1 : Math.max(1, root.count)
        rows: root.vertical ? Math.max(1, root.count) : 1
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            model: root.items

            delegate: DockApp {
                id: tile

                required property var modelData
                required property int index

                objectName: "dockItem." + modelData.key
                app: modelData
                slot: index
                iconSize: root.metrics.icon
                iconSource: root.iconProvider && modelData.icon ? root.iconProvider(modelData.icon) : ""
                tooltipOriginX: root.tooltipOriginX
                tooltipOriginY: root.tooltipOriginY
                cellSize: root.cell
                step: root.cell + root.gap
                count: root.count
                edge: root.edge
                magnify: root.magnify
                magnifyRange: root.magnifyRange
                magnifyScale: root.magnifyScale
                hoveredIndex: root.hoveredIndex
                pinned: modelData.kind === "pinned"
                strings: root.strings
                onClicked: root.activate(modelData)
                onHoverChanged: function (on) {
                    if (on)
                        root.hoveredIndex = tile.index
                    else if (root.hoveredIndex === tile.index)
                        root.hoveredIndex = -1
                    root.hovered(tile, on)
                }
                onDragStarted: root.dragging = true
                onDragEnded: root.dragging = false
                onDragFinished: function (from, to) { root.movePinned(from, to) }
            }
        }
    }
}
