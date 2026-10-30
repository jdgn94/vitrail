import QtQuick
import QtQuick.Shapes
import ".."
import "../frame.js" as Frame

// The liquid neck between a bar island and the floating card that is leaving
// it (frame.js neck): an hourglass in the surface's own fill, with the glass
// edge along its concave sides. Fills the layer it is drawn in; shows only
// while the neck exists.
Item {
    id: root

    property string edge: "left"
    // Screen rects of the island and of the card, and the card's corner radius.
    property var island: null
    property var card: null
    // 1 thick .. 0 snapped.
    property real bond: 0
    property real radius: VitrailTokens.radius
    property string style: VitrailTokens.surfaceMode
    property color tint: VitrailTokens.color("surface")
    property real opacityLevel: VitrailTokens.opacity

    readonly property var surface: VitrailStyle.resolve("surface", root.style)
    readonly property var neck: root.island && root.card
                                ? Frame.neck(root.width, root.height, root.edge, root.island, root.card, root.bond, root.radius)
                                : null

    visible: root.neck !== null

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.opacityLevel * root.surface.alpha)
            strokeColor: "transparent"

            PathSvg { path: root.neck ? root.neck.path : "" }
        }

        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.surface.border
            strokeColor: Qt.rgba(1, 1, 1, root.surface.edge * root.opacityLevel)

            PathSvg { path: root.neck ? root.neck.sides[0] : "" }
        }

        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.surface.border
            strokeColor: Qt.rgba(1, 1, 1, root.surface.edge * root.opacityLevel)

            PathSvg { path: root.neck ? root.neck.sides[1] : "" }
        }
    }
}
