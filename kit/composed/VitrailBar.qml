import QtQuick
import QtQuick.Layouts
import ".."
import "../base"
import "../frame.js" as Frame

// System bar living in the screen frame. Three slots, start / center / end,
// run left to right when the bar is horizontal and top to bottom when it is
// vertical. Fill the whole screen with it; the frame draws around the edges.
//
Item {
    id: root

    property string edge: "left"
    property string variant: ""
    property string frameVariant: ""
    // "comfortable" or "compact": a compact bar keeps a smaller share of each
    // gap. The font never changes.
    property string density: "comfortable"
    // False draws only the frame, for screens that do not carry the bar.
    property bool showBar: true
    // Frame and bar opacity.
    property real opacityLevel: VitrailTokens.opacity

    // Screen rect of the bar popup. A docked bar grows the frame around it; a
    // floating bar leaves the popup to draw its own island.
    property rect popup
    // How the popup tab is opening or closing (VitrailLiquid.look); null while
    // it is not shown. It grows out of the button `popupOrigin` (a rect) and,
    // while gliding to another button, `popupLag` px along the bar behind.
    property var popupLook: null
    property var popupOrigin: null
    property real popupLag: 0
    // Further cards docked into the frame, [{ edge, rect, reveal, swell }].
    property var tabs: []

    property alias start: startSlot.data
    property alias center: centerSlot.data
    property alias end: endSlot.data

    readonly property var style: VitrailStyle.resolve("bar", root.variant)
    readonly property real densityScale: VitrailTokens.density[root.density] === undefined
                                         ? 1 : VitrailTokens.density[root.density]
    readonly property int gap: root.gapOf(root.style.gap)

    // One of the token gap steps, scaled by the density.
    function gapOf(name) {
        return Math.round(VitrailTokens.gap(name) * root.densityScale)
    }
    readonly property var layout: Frame.layout(
        VitrailStyle.resolve("frame", root.frameVariant), root.showBar ? root.style : null, root.edge, {
            frame: VitrailTokens.frame,
            bar: VitrailTokens.bar,
            gap: root.gap,
            radius: VitrailTokens.radius
        })
    readonly property bool vertical: root.layout.edge === "left" || root.layout.edge === "right"
    // Space other windows must leave free, per screen edge.
    readonly property var reserve: root.layout.reserve
    // The bar rectangle, for input masks. An islands bar takes input on its
    // islands instead (startMask, centerMask, endMask), not on the whole strip.
    readonly property Item area: area
    readonly property bool islands: !!root.style.islands
    readonly property Item startMask: startMask
    readonly property Item centerMask: centerMask
    readonly property Item endMask: endMask
    readonly property int duration: VitrailTokens.duration(root.style.motion)

    // Islands bar: the screen rect of each non-empty slot group's island,
    // null for an empty group or any other bar. See Frame.islands().
    readonly property var startIsland: root.islandOf("start", startSlot)
    readonly property var centerIsland: root.islandOf("center", centerSlot)
    readonly property var endIsland: root.islandOf("end", endSlot)
    readonly property var islandRects: [root.startIsland, root.centerIsland, root.endIsland].filter(function (rect) {
        return rect !== null
    })
    // The popup tab. On an islands bar it starts at the island's depth, so it
    // grows out of the island and not out of the thin frame.
    readonly property var popupTab: root.popupLook && root.showBar && root.style.docked && root.popup.width > 0 ? {
        edge: root.layout.edge,
        rect: Frame.liquidRect(root.popup, root.layout.edge, root.popupOrigin, root.popupLook.spread,
                               root.popupLag, root.popupLook.stretch),
        reveal: root.popupLook.reveal,
        swell: root.popupLook.swell,
        base: root.layout.dock[root.layout.edge] - root.layout.hole[root.layout.edge]
    } : null
    // Docked islands are tabs of the frame, drawn inside its own path.
    readonly property var islandTabs: root.style.docked ? root.islandRects.map(function (rect) {
        return { edge: root.layout.edge, rect: rect, reveal: 1 }
    }) : []

    function islandOf(at, slot) {
        if (!root.showBar || !root.islands || slot.implicitWidth <= 0 || slot.implicitHeight <= 0)
            return null
        var group = { at: at, rect: Qt.rect(area.x + slot.x, area.y + slot.y, slot.width, slot.height) }
        return Frame.islands([group], root.layout.edge, root.width, root.height, {
            bar: VitrailTokens.bar,
            pad: root.gap,
            inset: root.layout.bar.offset
        }, root.style.docked)[0]
    }

    VitrailFrame {
        id: frame

        anchors.fill: parent
        variant: root.frameVariant
        hole: root.layout.hole
        radius: root.layout.radius
        tabs: (root.popupTab ? [root.popupTab] : []).concat(root.islandTabs).concat(root.tabs)
        opacityLevel: root.opacityLevel
    }

    // Floating islands: one pill per slot group.
    Repeater {
        model: root.style.docked ? [] : root.islandRects

        delegate: VitrailSurface {
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            style: VitrailTokens.surfaceMode
            radius: VitrailTokens.radius
            tint: VitrailTokens.color("surface")
            opacityLevel: root.opacityLevel
        }
    }

    // Input regions of the islands; empty on any other bar.
    Item {
        id: startMask

        x: root.startIsland ? root.startIsland.x : 0
        y: root.startIsland ? root.startIsland.y : 0
        width: root.startIsland ? root.startIsland.width : 0
        height: root.startIsland ? root.startIsland.height : 0
    }

    Item {
        id: centerMask

        x: root.centerIsland ? root.centerIsland.x : 0
        y: root.centerIsland ? root.centerIsland.y : 0
        width: root.centerIsland ? root.centerIsland.width : 0
        height: root.centerIsland ? root.centerIsland.height : 0
    }

    Item {
        id: endMask

        x: root.endIsland ? root.endIsland.x : 0
        y: root.endIsland ? root.endIsland.y : 0
        width: root.endIsland ? root.endIsland.width : 0
        height: root.endIsland ? root.endIsland.height : 0
    }

    Item {
        id: area

        z: 1
        visible: root.showBar
        readonly property real offset: root.layout.bar.offset
        readonly property real margin: root.layout.bar.margin
        readonly property real thickness: VitrailTokens.bar
        readonly property real pad: root.layout.bar.padding + root.gap

        x: root.layout.edge === "right" ? root.width - offset - thickness
           : root.vertical ? offset : margin
        y: root.layout.edge === "bottom" ? root.height - offset - thickness
           : root.vertical ? margin : offset
        width: root.vertical ? thickness : root.width - 2 * margin
        height: root.vertical ? root.height - 2 * margin : thickness

        Behavior on x { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

        // A floating bar is its own island; a docked one is part of the frame;
        // an islands bar draws one per group, outside this item.
        VitrailSurface {
            anchors.fill: parent
            visible: !root.style.docked && !root.islands
            style: VitrailTokens.surfaceMode
            radius: VitrailTokens.radius
            tint: VitrailTokens.color("surface")
            opacityLevel: root.opacityLevel
        }

        GridLayout {
            id: startSlot

            x: root.vertical ? (area.width - width) / 2 : area.pad
            y: root.vertical ? area.pad : (area.height - height) / 2
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: root.gap
            columnSpacing: root.gap
        }

        GridLayout {
            id: centerSlot

            x: (area.width - width) / 2
            y: (area.height - height) / 2
            flow: startSlot.flow
            rowSpacing: root.gap
            columnSpacing: root.gap
        }

        GridLayout {
            id: endSlot

            x: root.vertical ? (area.width - width) / 2 : area.width - width - area.pad
            y: root.vertical ? area.height - height - area.pad : (area.height - height) / 2
            flow: startSlot.flow
            rowSpacing: root.gap
            columnSpacing: root.gap
        }
    }
}
