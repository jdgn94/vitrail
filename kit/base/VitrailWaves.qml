import QtQuick
import QtQuick.Shapes
import ".."
import "../visualiser.js" as Vis

// The waves look of the audio visualiser: a few smooth lines across the
// strip, each sampling the same cava frame. Amplitude, thickness, spacing and
// the fading of the back lines are tokens (visualiser.waves); the values
// arrive from cava (kit/visualiser.js).
Item {
    id: root

    property var values: []
    property int count: VitrailTokens.visualiser.waves.count
    property color fill: "transparent"
    property real opacityLevel: VitrailTokens.opacity

    readonly property var wave: VitrailTokens.visualiser.waves
    // One array of points per line (visualiser.js).
    readonly property var lines: Vis.wave(root.values, root.count, root.width, root.height,
                                          root.wave)

    opacity: root.opacityLevel

    Repeater {
        model: root.lines.length

        delegate: Shape {
            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: Math.pow(root.wave.fade, index)

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.fill
                strokeWidth: root.wave.thickness
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.lines[index].map(function (point) {
                        return Qt.point(point.x, point.y)
                    })
                }
            }
        }
    }
}
