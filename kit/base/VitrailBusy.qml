import QtQuick
import ".."
import "../shapes.js" as Shapes

// Busy indicator in the Material 3 Expressive style: a shape that turns
// continuously and morphs into another random one every cycle. The outgoing
// shape shrinks and turns away while the incoming one pops in. Stopped, it
// fades out and nothing keeps running.
Item {
    id: root

    property bool running: false
    // Edge of the indicator, in px.
    property real size: VitrailTokens.size("title")
    property color color: VitrailTokens.color("primary")
    // A tinted disc behind the shape.
    property bool contained: false

    // The shape on show, and whether the timer is ticking (for tests).
    readonly property string shape: root.current
    readonly property bool ticking: cycle.running
    readonly property real shapeSize: root.contained ? root.size * 0.62 : root.size
    readonly property int duration: VitrailTokens.duration("base")

    property string current: ""
    property var front: null

    function advance() {
        var next = Shapes.random(root.current)
        var incoming = root.front === first ? second : first
        if (root.front)
            root.front.leave()
        incoming.enter(next)
        root.front = incoming
        root.current = next
    }

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: root.running ? 1 : 0
    visible: root.running || root.opacity > 0
    onVisibleChanged: if (root.visible && root.current === "") root.advance()
    Component.onCompleted: if (root.visible && root.current === "") root.advance()

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }

    Rectangle {
        anchors.fill: parent
        visible: root.contained
        radius: width / 2
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.18)
    }

    Item {
        anchors.centerIn: parent
        width: root.shapeSize
        height: root.shapeSize

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: VitrailTokens.duration("spin")
            loops: Animation.Infinite
            running: root.visible
        }

        Slot { id: first }

        Slot { id: second }
    }

    Timer {
        id: cycle

        interval: VitrailTokens.duration("cycle")
        repeat: true
        running: root.visible
        onTriggered: root.advance()
    }

    // One of the two shapes that trade places.
    component Slot: VitrailShape {
        id: slot

        function enter(name) {
            leaving.stop()
            slot.kind = name
            entering.restart()
        }

        function leave() {
            entering.stop()
            leaving.restart()
        }

        anchors.fill: parent
        fill: root.color
        scale: 0
        opacity: 0

        ParallelAnimation {
            id: entering

            NumberAnimation { target: slot; property: "scale"; from: 0; to: 1; duration: root.duration; easing.type: Easing.OutBack }
            NumberAnimation { target: slot; property: "rotation"; from: -45; to: 0; duration: root.duration; easing.type: Easing.OutCubic }
            NumberAnimation { target: slot; property: "opacity"; to: 1; duration: root.duration }
        }

        ParallelAnimation {
            id: leaving

            NumberAnimation { target: slot; property: "scale"; to: 0; duration: root.duration; easing.type: Easing.InCubic }
            NumberAnimation { target: slot; property: "rotation"; to: 45; duration: root.duration; easing.type: Easing.InCubic }
            NumberAnimation { target: slot; property: "opacity"; to: 0; duration: root.duration }
        }
    }
}
