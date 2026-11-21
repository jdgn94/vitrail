import QtQuick
import ".."
import "../color.js" as Color

// The tone slider of the colour picker: the whole track is painted with the
// colour being made (`hue` and `saturation`) going through its tones, from the
// darkest to the lightest, so the handle shows where on that road the colour
// is. The track repaints as the wheel moves. The handle holds `marker`, the
// colour itself. Left / Right step the tone (tokens.colorPicker.step), the
// pointer picks it anywhere on the track.
//
//   hue         degrees, 0..360
//   saturation  0..1
//   tone        the lightness, 0 (black) .. 1 (white); the hue and saturation
//               themselves sit in the middle
//   moved       emitted with the new tone; the owner sets `tone` from it
FocusScope {
    id: root

    property string size: "md"
    property real hue: 0
    property real saturation: 1
    property real tone: 0.5
    property color marker: "transparent"

    signal moved(real tone)

    readonly property var look: VitrailTokens.colorPicker
    readonly property bool pressed: area.pressed
    readonly property bool focused: root.activeFocus
    readonly property real markerSize: root.look.marker[root.size] || root.look.marker.md
    readonly property real trackSize: root.look.track[root.size] || root.look.track.md
    // The handle's centre travels between half a handle from each end.
    readonly property real span: Math.max(1, root.width - root.markerSize)

    function setTone(next) {
        var tone = Math.max(0, Math.min(1, next))
        if (tone !== root.tone)
            root.moved(tone)
    }

    implicitWidth: root.look.wheel[root.size] || root.look.wheel.md
    implicitHeight: Math.ceil(root.markerSize * root.look.grow)
    activeFocusOnTab: true

    Keys.onLeftPressed: root.setTone(root.tone - root.look.step)
    Keys.onRightPressed: root.setTone(root.tone + root.look.step)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        height: root.trackSize
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: Color.hslToHex(root.hue, root.saturation, 0) }
            GradientStop { position: 0.5; color: Color.hslToHex(root.hue, root.saturation, 0.5) }
            GradientStop { position: 1; color: Color.hslToHex(root.hue, root.saturation, 1) }
        }
    }

    Rectangle {
        x: root.markerSize / 2 + root.tone * root.span - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.markerSize
        height: root.markerSize
        radius: width / 2
        color: root.marker
        border.width: root.look.ring
        border.color: VitrailTokens.color(root.focused ? "primary" : "foreground")
        scale: root.pressed ? root.look.grow : 1

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: area

        function pick(mouse) {
            root.forceActiveFocus()
            root.setTone((mouse.x - root.markerSize / 2) / root.span)
        }

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: function (mouse) { area.pick(mouse) }
        onPositionChanged: function (mouse) { if (area.pressed) area.pick(mouse) }
    }
}
