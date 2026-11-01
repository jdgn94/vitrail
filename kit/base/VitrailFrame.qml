import QtQuick
import QtQuick.Shapes
import ".."
import "../frame.js" as Frame

// Screen frame: the whole screen minus a rounded content hole. A docked bar
// is just the thick side of this same shape, so bar and border share one
// edge and one curve with no seam between them.
Item {
    id: root

    property string variant: ""
    // Hole insets and corner radius, usually from frame.js layout().
    property var hole: ({ left: 0, top: 0, right: 0, bottom: 0 })
    property real radius: 0
    // Cards docked into the frame, [{ edge, rect, reveal }]: the hole bends
    // around each one (see frame.js holePath). Callers animate reveal.
    property var tabs: []
    property real opacityLevel: VitrailTokens.opacity

    readonly property var style: VitrailStyle.resolve("frame", root.variant)
    readonly property var surface: VitrailStyle.resolve("surface", VitrailTokens.surfaceMode)
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property color tint: VitrailTokens.color(root.style.role)
    readonly property color foreground: VitrailTokens.color("foreground")

    // Animated copies of the geometry, so variant, edge and panel changes
    // glide. Attached panels follow these to stay glued to the frame.
    property real leftInset: root.hole.left
    property real topInset: root.hole.top
    property real rightInset: root.hole.right
    property real bottomInset: root.hole.bottom
    property real corner: root.radius
    readonly property string holePath: Frame.holePath(root.width, root.height, {
        left: root.leftInset, top: root.topInset, right: root.rightInset, bottom: root.bottomInset
    }, root.corner, root.tabs)

    Behavior on leftInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on topInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on rightInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on bottomInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on corner { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Asynchronous: the path is processed off the GUI thread. Synchronous, a
        // frame whose path only changes because a card in ANOTHER window moves
        // (a popup resizing) could stop being repainted (Qt 6.11: the window never
        // got its update request), leaving the old tab on screen until the next
        // hover repainted it.
        asynchronous: true

        ShapePath {
            fillColor: Qt.rgba(root.tint.r, root.tint.g, root.tint.b,
                               root.opacityLevel * root.surface.alpha)
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill

            // One pixel past the screen on every side: when an inset is 0 the
            // hole would share an edge with this rectangle, and the GPU curve
            // renderer then fills the hole instead of cutting it out.
            PathRectangle {
                x: -1
                y: -1
                width: root.width + 2
                height: root.height + 2
            }

            PathSvg { path: root.holePath }
        }

        // Glass edge along the hole, like the light edge of VitrailSurface.
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.surface.border
            strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                                 root.surface.edge * root.opacityLevel)

            PathSvg { path: root.holePath }
        }
    }
}
