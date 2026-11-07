import QtQuick
import ".."
import "../visualiser.js" as Vis

// The circle look of the audio visualiser: one rounded bar per level,
// standing around the centre and growing outward. The ring's radius, the
// number of bars and their thickness are tokens (visualiser.circle); the
// values arrive from cava (kit/visualiser.js).
Item {
    id: root

    property var values: []
    property int count: VitrailTokens.visualiser.circle.count
    property color fill: "transparent"
    property real floor: VitrailTokens.visualiser.floor
    property real opacityLevel: VitrailTokens.opacity

    readonly property var ring: VitrailTokens.visualiser.circle
    // Every bar's centre, length, thickness and rotation (visualiser.js).
    readonly property var bars: Vis.radial(root.values, root.count, root.width, root.height,
                                           root.ring, root.floor)

    opacity: root.opacityLevel

    Repeater {
        model: root.bars.length

        delegate: Rectangle {
            required property int index
            readonly property var bar: root.bars[index]

            x: bar.x - width / 2
            y: bar.y - height / 2
            width: bar.thickness
            height: bar.length
            radius: Math.min(width / 2, VitrailTokens.radius)
            rotation: bar.rotation
            color: root.fill

            Behavior on height {
                NumberAnimation {
                    duration: VitrailTokens.visualiser.smoothing
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
