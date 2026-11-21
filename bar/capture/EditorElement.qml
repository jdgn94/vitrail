pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../kit"
import "editor.js" as Editor

// One element of the editor drawn in the picture's own pixels: the parent
// scales it for the view, the export draws it at 1:1, so both are the same
// picture. The element is plain data (see editor.js); `null` draws nothing.
// `bare` leaves a text element's letters out (its background only), for the
// one being typed, whose letters are the text input's.
Item {
    id: root

    property var element: null
    property bool bare: false

    readonly property string kind: root.element ? root.element.type : ""

    Loader {
        active: root.element !== null
        sourceComponent: root.kind === "pen" ? pen
                         : root.kind === "arrow" ? arrow
                         : root.kind === "text" ? label
                         : root.kind === "rect" ? rectangle
                         : root.kind === "ellipse" ? ellipse : null
    }

    Component {
        id: pen

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(root.element.color, root.element.opacity)
                strokeWidth: root.element.width
                capStyle: root.element.round ? ShapePath.RoundCap : ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: Editor.penPath(root.element.points)
                }
            }
        }
    }

    Component {
        id: rectangle

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.alpha(root.element.color, root.element.fillAlpha)
                strokeColor: root.element.color
                strokeWidth: root.element.width
                joinStyle: ShapePath.MiterJoin

                PathRectangle {
                    x: root.element.x
                    y: root.element.y
                    width: root.element.w
                    height: root.element.h
                }
            }
        }
    }

    Component {
        id: ellipse

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.alpha(root.element.color, root.element.fillAlpha)
                strokeColor: root.element.color
                strokeWidth: root.element.width

                PathAngleArc {
                    centerX: root.element.x + root.element.w / 2
                    centerY: root.element.y + root.element.h / 2
                    radiusX: root.element.w / 2
                    radiusY: root.element.h / 2
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }

    Component {
        id: arrow

        Shape {
            id: shape

            readonly property var geometry: Editor.arrowGeometry(root.element)

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.element.color
                strokeWidth: root.element.width
                capStyle: ShapePath.FlatCap
                strokeStyle: root.element.dashed ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: Editor.dash(VitrailTokens.capture.editor, root.element.dashed)

                PathSvg {
                    path: shape.geometry.line
                          ? "M " + shape.geometry.line.x1 + " " + shape.geometry.line.y1
                            + " L " + shape.geometry.line.x2 + " " + shape.geometry.line.y2 : ""
                }
            }

            ShapePath {
                fillColor: root.element.color
                strokeWidth: -1

                PathSvg {
                    path: shape.geometry.heads.length > 0 ? Editor.headPath(shape.geometry.heads[0]) : ""
                }
            }

            ShapePath {
                fillColor: root.element.color
                strokeWidth: -1

                PathSvg {
                    path: shape.geometry.heads.length > 1 ? Editor.headPath(shape.geometry.heads[1]) : ""
                }
            }
        }
    }

    Component {
        id: label

        Item {
            x: root.element.x
            y: root.element.y
            width: letters.implicitWidth + 2 * root.element.pad
            height: letters.implicitHeight + 2 * root.element.pad

            Rectangle {
                anchors.fill: parent
                visible: root.element.ground !== ""
                radius: root.element.pad / 2
                color: root.element.ground
            }

            Text {
                id: letters

                x: root.element.pad
                y: root.element.pad
                visible: !root.bare
                text: root.element.text
                color: root.element.color
                font.pixelSize: root.element.size
                font.bold: root.element.bold
                font.family: VitrailTokens.fontFamily
            }
        }
    }
}
