import QtQuick
import QtQuick.Layouts
import ".."
import "../base"
import "../frame.js" as Frame

// System bar living in the screen frame. Three slots, start / center / end,
// run left to right when the bar is horizontal and top to bottom when it is
// vertical. Fill the whole screen with it; the frame draws around the edges.
//
// It also hosts the side panel that opens from the bar edge: a full panel is
// the frame growing along that edge, an overlay panel slides out from under
// the bar as a floating island.
Item {
    id: root

    property string edge: "left"
    property string variant: ""
    property string frameVariant: ""
    // False draws only the frame, for screens that do not carry the bar.
    property bool showBar: true
    // Frame, bar and overlay panel opacity.
    property real opacityLevel: VitrailTokens.opacity

    property string panelVariant: ""
    property bool panelOpen: false
    // Whether an open full panel takes space from the windows.
    property bool panelPush: false

    // Screen rect of the open bar popup. A docked bar grows the frame
    // around it; a floating bar leaves the popup to draw its own island.
    property rect popup
    property bool popupOpen: false
    // Further cards docked into the frame, [{ edge, rect, reveal }].
    property var tabs: []
    // The popup tab grows out of the bar and back into it.
    property real popupReveal: root.popupOpen && root.showBar && root.style.docked ? 1 : 0

    Behavior on popupReveal { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }

    property alias start: startSlot.data
    property alias center: centerSlot.data
    property alias end: endSlot.data
    property alias panelContent: panelSlot.data

    readonly property var style: VitrailStyle.resolve("bar", root.variant)
    readonly property int gap: VitrailTokens.gap(root.style.gap)
    readonly property var layout: Frame.layout(
        VitrailStyle.resolve("frame", root.frameVariant), root.showBar ? root.style : null, root.edge, {
            frame: VitrailTokens.frame,
            bar: VitrailTokens.bar,
            gap: root.gap,
            radius: VitrailTokens.radius
        }, {
            variant: root.panelStyle,
            extent: root.panelOpen && root.showBar ? VitrailTokens.panel : 0,
            push: root.panelPush
        })
    readonly property var panelStyle: VitrailStyle.resolve("panel", root.panelVariant)
    readonly property bool vertical: root.layout.edge === "left" || root.layout.edge === "right"
    // Space other windows must leave free, per screen edge.
    readonly property var reserve: root.layout.reserve
    // The bar rectangle, for input masks.
    readonly property Item area: area
    // The open panel rectangle, for input masks; null while closed.
    readonly property Item panelArea: root.panelOpen && root.showBar ? panel : null
    readonly property int duration: VitrailTokens.duration(root.style.motion)

    VitrailFrame {
        id: frame

        anchors.fill: parent
        variant: root.frameVariant
        hole: root.layout.hole
        radius: root.layout.radius
        tabs: [{ edge: root.layout.edge, rect: root.popup, reveal: root.popupReveal }].concat(root.tabs)
        opacityLevel: root.opacityLevel
    }

    Item {
        id: panel

        readonly property bool attached: root.panelStyle.attached
        readonly property real start: root.layout.panel.start
        readonly property real depth: VitrailTokens.panel
        readonly property int duration: VitrailTokens.duration(root.panelStyle.motion)
        readonly property int gap: VitrailTokens.gap(root.panelStyle.gap)
        readonly property var hole: root.layout.hole
        // Overlay distance from the screen edge; closed, it hides under the bar.
        readonly property real reach: root.panelOpen ? start : start - depth - gap
        readonly property var rect: attached ? panel.attachedRect() : panel.overlayRect()

        // Grows with the frame's animated insets, so it never lags the curve.
        function attachedRect() {
            var l = frame.leftInset, t = frame.topInset, r = frame.rightInset, b = frame.bottomInset
            switch (root.layout.edge) {
            case "right": return Qt.rect(root.width - r, t, Math.max(0, r - start), root.height - t - b)
            case "top": return Qt.rect(l, start, root.width - l - r, Math.max(0, t - start))
            case "bottom": return Qt.rect(l, root.height - b, root.width - l - r, Math.max(0, b - start))
            default: return Qt.rect(start, t, Math.max(0, l - start), root.height - t - b)
            }
        }

        function overlayRect() {
            var across = root.vertical ? root.height - hole.top - hole.bottom - 2 * gap
                                       : root.width - hole.left - hole.right - 2 * gap
            switch (root.layout.edge) {
            case "right": return Qt.rect(root.width - reach - depth, hole.top + gap, depth, across)
            case "top": return Qt.rect(hole.left + gap, reach, across, depth)
            case "bottom": return Qt.rect(hole.left + gap, root.height - reach - depth, across, depth)
            default: return Qt.rect(reach, hole.top + gap, depth, across)
            }
        }

        // Attached content sits on the frame; an overlay slides from below it.
        z: attached ? 1 : -1
        visible: root.showBar
        x: rect.x
        y: rect.y
        width: rect.width
        height: rect.height
        opacity: root.panelOpen ? 1 : 0
        clip: true

        Behavior on x { enabled: !panel.attached; NumberAnimation { duration: panel.duration; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !panel.attached; NumberAnimation { duration: panel.duration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: panel.duration; easing.type: Easing.OutCubic } }

        VitrailSurface {
            anchors.fill: parent
            visible: !panel.attached
            style: VitrailTokens.surfaceMode
            radius: VitrailTokens.radius
            tint: VitrailTokens.color("surface")
            opacityLevel: root.opacityLevel
        }

        Item {
            id: panelSlot

            anchors.fill: parent
            anchors.margins: panel.gap
        }
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

        // A floating bar is its own island; a docked one is part of the frame.
        VitrailSurface {
            anchors.fill: parent
            visible: !root.style.docked
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
