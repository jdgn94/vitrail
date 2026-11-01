import QtQuick
import QtQuick.Effects
import "../kit"
import "../kit/base"
import "media.js" as Media

// The disc look: a vinyl record (black, with grooves, a label and a spindle
// hole) inside a ring of dash marks, and a tonearm over its right side. The
// label carries the cover, cropped to the circle, or the track's text when
// there is none. Paused, every mark is the same small dot (a dotted border).
// While it plays the marks grow and bounce like playback bars, and the record
// turns; pausing freezes it at its angle, and the ring settles back to dots.
// Only the record turns; the ring and the tonearm never do.
Item {
    id: root

    property bool playing: false
    property string cover: ""
    // The track's text, shown on the label when there is no cover.
    property string label: ""

    readonly property var look: VitrailTokens.media.disc
    // The palette roles it paints with. The settings window passes its own:
    // its `kit` is another module from the bar's, so its singleton tokens are
    // not the ones the bar's components read.
    property bool dark: VitrailTokens.dark
    property color primary: VitrailTokens.color("primary", "transparent")
    property color accentForeground: VitrailTokens.color("accentForeground", "transparent")
    property color foreground: VitrailTokens.color("foreground", "transparent")
    property color surface: VitrailTokens.color("surface", "transparent")
    property color surfaceHigh: VitrailTokens.color("surfaceHigh", "transparent")
    // The dark and the light tone of the theme, whichever it is: the record is
    // the dark one made darker, its grooves and the arm the light one.
    readonly property color ink: root.dark ? root.surfaceHigh : root.foreground
    readonly property color paper: root.dark ? root.foreground : root.surface
    readonly property color vinyl: Qt.darker(root.ink, root.look.vinyl)
    readonly property bool covered: root.cover !== "" && art.status === Image.Ready
    // The tonearm: where its pivot and its head are, from the centre.
    readonly property real radius: root.look.size / 2
    readonly property real pivotAngle: root.look.armAngle * Math.PI / 180
    readonly property real headAngle: root.look.headAngle * Math.PI / 180
    readonly property real pivotX: root.width / 2 + root.radius * root.look.armReach * Math.cos(root.pivotAngle)
    readonly property real pivotY: root.height / 2 + root.radius * root.look.armReach * Math.sin(root.pivotAngle)
    readonly property real headX: root.width / 2 + root.radius * root.look.headReach * Math.cos(root.headAngle)
    readonly property real headY: root.height / 2 + root.radius * root.look.headReach * Math.sin(root.headAngle)
    readonly property real armAt: Math.atan2(root.headY - root.pivotY, root.headX - root.pivotX)
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

    // The record turns as one: disc, grooves, label and hole.
    Item {
        id: record

        anchors.centerIn: parent
        width: root.look.size
        height: root.look.size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.vinyl
            border.width: root.look.edgeWidth
            border.color: Qt.alpha(root.paper, root.look.edge)
        }

        Repeater {
            model: root.look.grooves

            delegate: Rectangle {
                required property real modelData

                anchors.centerIn: parent
                width: 2 * modelData
                height: 2 * modelData
                radius: width / 2
                color: "transparent"
                border.width: root.look.edgeWidth
                border.color: Qt.alpha(root.paper, root.look.groove)
            }
        }

        // `clip: true` only cuts to the bounding box, not to `radius`: the
        // label's round shape is a mask over the cover and its fill (they are
        // drawn square in `content`, which is not shown itself).
        Item {
            id: content

            anchors.centerIn: parent
            width: root.look.label
            height: root.look.label
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                color: root.primary
            }

            Image {
                id: art

                anchors.fill: parent
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        MultiEffect {
            anchors.fill: content
            source: content
            maskEnabled: true
            maskSource: labelMask
        }

        Item {
            id: labelMask

            anchors.fill: content
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "black"
            }
        }

        // The text that stands in for a missing cover: inside the square that
        // fits the label circle, shrunk and elided to fit it.
        VitrailText {
            anchors.centerIn: parent
            width: root.look.label * Math.SQRT1_2
            height: root.look.label * Math.SQRT1_2
            visible: !root.covered && root.label !== ""
            text: root.label
            variant: "label"
            color: root.accentForeground
            opacity: 1
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: root.look.labelMin
        }

        // The spindle hole.
        Rectangle {
            anchors.centerIn: parent
            width: root.look.hole
            height: root.look.hole
            radius: width / 2
            color: root.surface
            visible: root.covered || root.label === ""
        }
    }

    // The tonearm: a base on the record's edge, a thin arm and a head over the
    // grooves. It stays still while the record turns.
    Rectangle {
        x: root.pivotX
        y: root.pivotY - height / 2
        width: Math.hypot(root.headX - root.pivotX, root.headY - root.pivotY)
        height: root.look.arm
        radius: height / 2
        color: root.paper
        opacity: root.look.armTone
        transformOrigin: Item.Left
        rotation: root.armAt * 180 / Math.PI
    }

    Rectangle {
        x: root.headX - width / 2
        y: root.headY - height / 2
        width: root.look.headLength
        height: root.look.headWidth
        radius: root.look.edgeWidth
        color: root.paper
        opacity: root.look.armTone
        rotation: root.armAt * 180 / Math.PI
    }

    Rectangle {
        x: root.pivotX - width / 2
        y: root.pivotY - height / 2
        width: root.look.pivot
        height: root.look.pivot
        radius: width / 2
        color: root.paper
        opacity: root.look.armTone
    }
}
