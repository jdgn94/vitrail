import QtQuick

// The container most Vitrail components inherit from.
//
// style "solid": the alpha is exactly opacityLevel. No blur, no border.
// style "glass": the alpha is reduced and the surface gains a light edge.
//   Real backdrop blur comes from the compositor (Hyprland), which is why
//   the window itself must stay translucent.
Item {
    id: root

    property string style: "glass"
    property real radius: VitrailTokens.radius
    property color tint: VitrailTokens.color("surface", "#1d2024")
    property real opacityLevel: 0.9

    default property alias content: holder.data

    Rectangle {
        id: fill

        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b,
                       root.opacityLevel * (root.style === "glass" ? 0.62 : 1.0))
        border.width: root.style === "glass" ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.18 * root.opacityLevel)

        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 240 } }
        Behavior on border.color { ColorAnimation { duration: 240 } }
    }

    Item {
        id: holder

        anchors.fill: parent
    }
}
