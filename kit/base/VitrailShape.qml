import QtQuick
import QtQuick.Shapes
import "../shapes.js" as Shapes

// One Material 3 Expressive shape (see shapes.js for the names), filled.
Item {
    id: root

    // A name from shapes.names.
    property string kind: "circle"
    property color fill: "transparent"

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: "transparent"

            PathSvg { path: Shapes.path(root.kind, Math.max(root.width, root.height)) }
        }
    }
}
