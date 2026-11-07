import QtQuick
import ".."
import "../base"

// The audio visualiser of the background layer: cava's 64 levels as rounded
// bars. Five approved looks, chosen by `variant` (VitrailVariants.visualiser):
//
//   bars        the bars stand on the bottom edge, no container
//   reflection  the bars stand above a mirror that fades below the baseline
//   panel       the bars sit inside a rounded surface, inset from the edges
//   circle      a ring of bars around the centre, growing outward
//   waves       a few smooth lines across the strip
//
// An unknown or empty name follows the family default (`bars`). The caller
// sets `values` from `{"values": [...]}` in the runtime file and sizes the
// strip (preference `visualiserHeight`).
Item {
    id: root

    property string variant: ""
    property var values: []
    property int bars: VitrailTokens.visualiser.bars
    property color tint: VitrailTokens.color("primary", "transparent")
    property real opacityLevel: VitrailTokens.opacity

    readonly property var look: VitrailStyle.resolve("visualiser", root.variant)
    readonly property string shape: root.look.shape || "bars"

    implicitWidth: VitrailTokens.visualiser.maxWidth
    implicitHeight: VitrailTokens.ranges.visualiserHeight.value

    VitrailSurface {
        anchors.fill: parent
        visible: root.look.panel === true
        radius: VitrailTokens.radius * VitrailTokens.visualiser.panel.radius
        opacityLevel: root.opacityLevel
    }

    VitrailBars {
        anchors.fill: parent
        anchors.margins: root.look.panel === true ? VitrailTokens.gap(VitrailTokens.visualiser.panel.padding) : 0
        visible: root.shape === "bars"
        values: root.values
        count: root.bars
        fill: root.tint
        reflection: root.look.reflection === true
    }

    VitrailRadial {
        anchors.fill: parent
        visible: root.shape === "circle"
        values: root.values
        fill: root.tint
        opacityLevel: root.opacityLevel
    }

    VitrailWaves {
        anchors.fill: parent
        visible: root.shape === "waves"
        values: root.values
        fill: root.tint
        opacityLevel: root.opacityLevel
    }
}
