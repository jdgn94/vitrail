import QtQuick
import QtQuick.Shapes
import ".."

// A circular progress ring: a quiet track with an arc from the top clockwise.
// `value` is 0 at the start and 1 when the phase is over; a negative value is
// "no reading", so the track stays and nothing fills it.
Item {
    id: root

    property real value: -1
    // A family from VitrailVariants.tone; the arc takes its role.
    property string tone: "primary"
    readonly property var family: VitrailVariants.tone[root.tone] || VitrailVariants.tone.primary
    readonly property real share: root.value < 0 ? 0 : Math.min(root.value, 1)
    readonly property real thickness: VitrailTokens.gap("xs") * 0.5
    readonly property real radius: Math.max(0, Math.min(root.width, root.height) / 2 - root.thickness / 2)

    implicitWidth: VitrailTokens.size("title")
    implicitHeight: VitrailTokens.size("title")

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(VitrailTokens.color("foreground", "transparent"),
                                  VitrailTokens.graph.track)
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: VitrailTokens.color(root.family.role, "transparent")
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * root.share
            }
        }
    }
}
