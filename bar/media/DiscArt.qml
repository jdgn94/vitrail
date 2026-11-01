import QtQuick
import QtQuick.Effects
import "../kit"
import "../kit/base"
import "media.js" as Media

// The disc look: a round cover with a hole, like a record, inside a ring of
// dash marks. Paused, every mark is the same small dot (a dotted border). While
// it plays the marks grow and bounce like playback bars, and the cover turns;
// pausing freezes the cover at its angle, and the ring settles back to dots.
// Only the cover turns; the ring never does.
Item {
    id: root

    property bool playing: false
    property string cover: ""

    readonly property var look: VitrailTokens.media.disc
    // The palette roles it paints with. The settings window passes its own:
    // its `kit` is another module from the bar's, so its singleton tokens are
    // not the ones the bar's components read.
    property color primary: VitrailTokens.color("primary", "transparent")
    property color foreground: VitrailTokens.color("foreground", "transparent")
    property color surface: VitrailTokens.color("surface", "transparent")
    // 0 paused (dots) .. 1 playing (bars); eased with a token duration.
    property real energy: root.playing ? 1 : 0
    // Where the marks are in their bounce, 0..1.
    property real phase: 0

    implicitWidth: root.look.size + 2 * root.look.pad
    implicitHeight: root.look.size + 2 * root.look.pad

    Behavior on energy { NumberAnimation { duration: root.look.settle; easing.type: Easing.InOutQuad } }

    // The bounce and the record's turn follow the frame clock, so they stop
    // where they are; nothing runs while paused once the ring has settled.
    FrameAnimation {
        running: root.playing || root.energy > 0
        onTriggered: root.phase = (root.phase + frameTime * 1000 / root.look.bounce) % 1
    }

    FrameAnimation {
        running: root.playing
        onTriggered: record.rotation = (record.rotation + 360 * frameTime * 1000 / root.look.turn) % 360
    }

    Repeater {
        model: root.look.marks

        delegate: Rectangle {
            id: mark

            required property int index

            readonly property real angle: 2 * Math.PI * mark.index / root.look.marks
            readonly property real beat: Media.beat(root.phase, mark.index)
            // From the cover's edge outwards.
            readonly property real reach: root.look.size / 2 + root.look.gap + width / 2

            width: Media.markLength(mark.beat, root.energy, root.look.dot, root.look.longest)
            height: root.look.dot
            radius: height / 2
            x: root.width / 2 + mark.reach * Math.cos(mark.angle) - width / 2
            y: root.height / 2 + mark.reach * Math.sin(mark.angle) - height / 2
            rotation: mark.angle * 180 / Math.PI
            opacity: Media.markOpacity(mark.beat, root.energy, root.look.idle, root.look.low)
            color: root.primary
        }
    }

    // `clip: true` only cuts to the bounding box, not to `radius`: the round
    // shape is a mask over the cover, the tint and the hole (they are drawn
    // square in `content`, which is not shown itself).
    Item {
        id: record

        anchors.centerIn: parent
        width: root.look.size
        height: root.look.size

        Item {
            id: content

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(root.foreground, root.look.tint)
            }

            Image {
                anchors.fill: parent
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.cover !== ""
            }

            VitrailIcon {
                anchors.centerIn: parent
                visible: root.cover === ""
                icon: "music_note"
                size: "lg"
                color: root.foreground
            }

            // The hole in the middle of a record (the music note stands there
            // when there is no cover).
            Rectangle {
                anchors.centerIn: parent
                visible: root.cover !== ""
                width: root.look.hole
                height: root.look.hole
                radius: width / 2
                color: root.surface
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: content
            maskEnabled: true
            maskSource: disc
        }

        Item {
            id: disc

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "black"
            }
        }
    }
}
