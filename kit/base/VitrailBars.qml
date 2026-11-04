import QtQuick
import ".."
import "../visualiser.js" as Vis

// The raw material of the audio visualiser: one rounded bar per value,
// growing from a baseline. `reflection` stands the row above a mirror that
// fades away below the baseline (the approved reflection look). Everything
// visual comes from tokens; the values arrive from cava (kit/visualiser.js).
Item {
    id: root

    property var values: []
    property int count: VitrailTokens.visualiser.bars
    property color fill: "transparent"
    property bool reflection: false
    property real floor: VitrailTokens.visualiser.floor

    // Where the bars stand: the bottom edge, or higher up when there is a
    // mirror to leave room for.
    readonly property real baselineY: root.height * (root.reflection ? VitrailTokens.visualiser.reflection.baseline : 1)
    readonly property real cell: root.count > 0 ? root.width / root.count : 0
    readonly property real barWidth: Math.max(1, root.cell * VitrailTokens.visualiser.coverage)
    readonly property real corner: Math.min(root.barWidth / 2, VitrailTokens.radius)
    readonly property var levels: Vis.values(root.values, root.count)

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            x: index * root.cell + (root.cell - root.barWidth) / 2
            width: root.barWidth
            height: Math.max(root.floor * baselineY, Vis.level(root.levels[index]) * baselineY)
            y: baselineY - height
            radius: root.corner
            color: root.fill

            Behavior on height {
                NumberAnimation {
                    duration: VitrailTokens.visualiser.smoothing
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Repeater {
        model: root.reflection ? root.count : 0

        delegate: Rectangle {
            required property int index

            readonly property real reach: Vis.level(root.levels[index])
                                           * (root.height - baselineY)
                                           * VitrailTokens.visualiser.reflection.reach

            x: index * root.cell + (root.cell - root.barWidth) / 2
            y: baselineY + VitrailTokens.visualiser.reflection.gap
            width: root.barWidth
            height: Math.max(1, reach)
            radius: root.corner
            opacity: VitrailTokens.visualiser.reflection.fade
            gradient: Gradient {
                GradientStop { position: 0; color: root.fill }
                GradientStop { position: 1; color: "transparent" }
            }

            Behavior on height {
                NumberAnimation {
                    duration: VitrailTokens.visualiser.smoothing
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
