import QtQuick
import ".."
import "../color.js" as Color

// The colour wheel of the picker: every hue around the circle, the saturation
// growing from the centre (grey) to the rim (the full colour), painted by
// kit/shaders/color-wheel. A pointer press or drag anywhere picks the hue and
// saturation under it (beyond the rim it is the rim); the marker sits on the
// current point and holds `marker`, the colour the picker has made of it.
//
//   size        sm / md / lg: the wheel's diameter (tokens.colorPicker.wheel)
//   hue         degrees, 0..360
//   saturation  0..1
//   marker      the colour inside the ring
//   picked      emitted while the pointer picks; the owner sets hue and
//               saturation from it
Item {
    id: root

    property string size: "md"
    property real hue: 0
    property real saturation: 1
    property color marker: "transparent"

    signal picked(real hue, real saturation)

    readonly property var look: VitrailTokens.colorPicker
    readonly property bool pressed: area.pressed
    readonly property real markerSize: root.look.marker[root.size] || root.look.marker.md
    readonly property real diameter: root.look.wheel[root.size] || root.look.wheel.md
    // The disc leaves half a marker around it, so a marker on the rim stays inside.
    readonly property real radius: Math.max(0, (Math.min(root.width, root.height) - root.markerSize) / 2)
    readonly property var point: Color.wheelPoint(root.hue, root.saturation, root.radius)

    implicitWidth: root.diameter + root.markerSize
    implicitHeight: root.diameter + root.markerSize

    ShaderEffect {
        anchors.centerIn: parent
        width: 2 * root.radius
        height: 2 * root.radius

        property real lightness: root.look.lightness
        property real edge: root.radius > 0 ? root.look.edge / root.radius : 0

        fragmentShader: "../shaders/color-wheel.frag.qsb"
    }

    Rectangle {
        x: root.width / 2 + root.point.x - width / 2
        y: root.height / 2 + root.point.y - height / 2
        width: root.markerSize
        height: root.markerSize
        radius: width / 2
        color: root.marker
        border.width: root.look.ring
        border.color: VitrailTokens.color("foreground")
        scale: root.pressed ? root.look.grow : 1

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: area

        function pick(mouse) {
            var at = Color.wheelAt(mouse.x - root.width / 2, mouse.y - root.height / 2, root.radius)
            root.picked(at.h, at.s)
        }

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: function (mouse) { area.pick(mouse) }
        onPositionChanged: function (mouse) { if (area.pressed) area.pick(mouse) }
    }
}
