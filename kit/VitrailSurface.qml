import QtQuick

// The container most Vitrail components inherit from. Its look comes from the
// surface variants (VitrailVariants.surface), chosen by `style`:
//
// solid: the alpha is exactly opacityLevel. No blur, no border.
// glass: the alpha is reduced and the surface gains a light edge.
//   Real backdrop blur comes from the compositor (Hyprland), which is why
//   the window itself must stay translucent.
Item {
    id: root

    property string style: VitrailTokens.surfaceMode
    property real radius: VitrailTokens.radius
    property color tint: VitrailTokens.color("surface", "#1d2024")
    property real opacityLevel: VitrailTokens.opacity

    readonly property var look: VitrailStyle.resolve("surface", root.style)

    default property alias content: holder.data

    Rectangle {
        id: fill

        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.opacityLevel * root.look.alpha)
        border.width: root.look.border
        border.color: Qt.rgba(1, 1, 1, root.look.edge * root.opacityLevel)

        Behavior on radius { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("slow") } }
        Behavior on border.color { ColorAnimation { duration: VitrailTokens.duration("slow") } }
    }

    Item {
        id: holder

        anchors.fill: parent
    }
}
