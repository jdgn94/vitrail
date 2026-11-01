import QtQuick
import ".."

// A line of text that does not get cut when it is too long: it slides to the
// left like a carousel, then the same text comes in again after a gap, so the
// loop reads as two lines and not as one endless one. A text that fits stays
// still.
Item {
    id: root

    property string text: ""
    property string variant: "body"
    property color color: VitrailTokens.color("foreground")
    property real gap: VitrailTokens.gap("xl")
    // Pixels per second while it travels.
    property real speed: 28

    readonly property real textWidth: measure.implicitWidth
    readonly property bool scrolling: root.width > 0 && root.textWidth > root.width
    readonly property real distance: root.textWidth + root.gap

    implicitHeight: measure.implicitHeight
    clip: true

    // Measured once; never shown.
    VitrailText {
        id: measure

        visible: false
        variant: root.variant
        text: root.text
    }

    Row {
        id: row

        spacing: root.gap

        VitrailText {
            variant: root.variant
            color: root.color
            text: root.text
        }

        VitrailText {
            variant: root.variant
            color: root.color
            text: root.text
            visible: root.scrolling
        }
    }

    NumberAnimation {
        target: row
        property: "x"
        from: 0
        to: -root.distance
        duration: root.speed > 0 ? root.distance / root.speed * 1000 : 0
        loops: Animation.Infinite
        running: root.scrolling
        // The first placement does not jump: the text starts at rest and the
        // loop takes over once it has settled.
        alwaysRunToEnd: false
    }
}
