import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../kit"
import "../kit/base"

// The cassette look: a tape. A dark shell with a screw in each corner, a light
// label (a big "A", a few lines or, when there is no cover, the track's text,
// and a coloured band along its foot), a window with the cover behind two
// reels and the tape between them, and a darker base with the usual holes. The reels turn in opposite directions while it plays and
// stop where they are when it pauses. Every size is a px of an 80 px wide tape
// (`VitrailTokens.media.cassette`); scale the item to fit elsewhere.
Item {
    id: root

    property bool playing: false
    property string cover: ""
    // The track's text, shown on the label when there is no cover.
    property string label: ""
    // How far the reels have turned, in degrees.
    property real angle: 0

    readonly property var look: VitrailTokens.media.cassette
    // The palette roles it paints with. The settings window passes its own:
    // its `kit` is another module from the bar's, so its singleton tokens are
    // not the ones the bar's components read.
    property bool dark: VitrailTokens.dark
    property color foreground: VitrailTokens.color("foreground", "transparent")
    property color surface: VitrailTokens.color("surface", "transparent")
    property color surfaceHigh: VitrailTokens.color("surfaceHigh", "transparent")
    property color primary: VitrailTokens.color("primary", "transparent")
    property color info: VitrailTokens.color("info", "transparent")
    // Dark parts and the light label, whichever theme: the shell is the dark
    // one, the label the light one.
    readonly property color ink: root.dark ? root.surfaceHigh : root.foreground
    readonly property color paper: root.dark ? root.foreground : root.surface
    readonly property bool covered: root.cover !== "" && art.status === Image.Ready
    readonly property color deep: Qt.darker(root.ink, root.look.deepen)
    readonly property color deepest: Qt.darker(root.deep, root.look.deepen)

    implicitWidth: root.look.width
    implicitHeight: root.look.height

    FrameAnimation {
        running: root.playing
        onTriggered: root.angle = (root.angle + 360 * frameTime * 1000 / root.look.turn) % 360
    }

    Rectangle {
        anchors.fill: parent
        radius: root.look.radius
        color: root.ink
        border.width: root.look.edgeWidth
        border.color: Qt.alpha(root.foreground, root.look.edge)
    }

    // A screw in each corner.
    Repeater {
        model: 4

        delegate: Rectangle {
            required property int index

            x: index % 2 === 0 ? root.look.screwAt : root.width - root.look.screwAt - root.look.screw
            y: index < 2 ? root.look.screwAt : root.height - root.look.screwAt - root.look.screw
            width: root.look.screw
            height: root.look.screw
            radius: width / 2
            color: Qt.alpha(root.paper, root.look.screwTone)
        }
    }

    // The base: a trapezoid with two round holes and two slots.
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.deep
            startX: root.look.baseInset
            startY: root.look.baseY

            PathLine { x: root.width - root.look.baseInset; y: root.look.baseY }
            PathLine { x: root.width - root.look.baseInset - root.look.baseTaper; y: root.look.baseY + root.look.baseHeight }
            PathLine { x: root.look.baseInset + root.look.baseTaper; y: root.look.baseY + root.look.baseHeight }
            PathLine { x: root.look.baseInset; y: root.look.baseY }
        }
    }

    Repeater {
        model: 2

        delegate: Rectangle {
            required property int index

            x: index === 0 ? root.look.holeAt : root.width - root.look.holeAt - width
            y: root.look.baseY + (root.look.baseHeight - height) / 2
            width: root.look.hole
            height: root.look.hole
            radius: width / 2
            color: root.deepest
        }
    }

    Repeater {
        model: 2

        delegate: Rectangle {
            required property int index

            x: root.width / 2 + (index === 0 ? -root.look.slotAt / 2 - width : root.look.slotAt / 2)
            y: root.look.baseY + (root.look.baseHeight - height) / 2
            width: root.look.slot
            height: root.look.slot
            color: root.deepest
        }
    }

    // The label: a big "A", a few thin lines, a band along its foot.
    Rectangle {
        x: root.look.labelX
        y: root.look.labelY
        width: root.look.labelWidth
        height: root.look.labelHeight
        radius: root.look.labelRadius
        color: root.paper

        VitrailText {
            x: root.look.letterX
            y: root.look.letterY
            text: "A"
            color: root.ink
            font.pixelSize: root.look.letter
            font.weight: Font.Bold
        }

        // The text that stands in for a missing cover, where the lines are.
        VitrailText {
            x: root.look.lineX
            y: root.look.lineY
            width: root.look.lineWidth
            height: 3 * root.look.lineStep
            visible: !root.covered && root.label !== ""
            text: root.label
            variant: "label"
            color: root.ink
            opacity: 1
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: root.look.textMin
        }

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                visible: root.covered || root.label === ""
                x: root.look.lineX
                y: root.look.lineY + index * root.look.lineStep
                width: index === 2 ? root.look.lineShort : root.look.lineWidth
                height: root.look.edgeWidth
                color: Qt.alpha(root.ink, root.look.lineTone)
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.look.bandPrimary + root.look.bandSecondary
            bottomLeftRadius: root.look.labelRadius
            bottomRightRadius: root.look.labelRadius
            color: root.primary

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.look.bandSecondary
                bottomLeftRadius: root.look.labelRadius
                bottomRightRadius: root.look.labelRadius
                color: root.info
            }
        }
    }

    // The window: the cover behind, the tape, and the two reels.
    Rectangle {
        id: window

        readonly property real middle: height / 2
        readonly property real leftReel: root.look.reel
        readonly property real rightReel: width - root.look.reel

        x: root.look.windowX
        y: root.look.windowY
        width: root.look.windowWidth
        height: root.look.windowHeight
        radius: root.look.windowRadius
        color: root.deepest

        // `clip: true` only cuts to the bounding box, not to `radius`: the
        // cover is masked to the window's rounded shape instead.
        Image {
            id: art

            anchors.fill: parent
            source: root.cover
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: art
            visible: root.covered
            maskEnabled: true
            maskSource: windowMask
        }

        Item {
            id: windowMask

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: window.radius
                color: "black"
            }
        }

        // Tape wound on the left reel, thinning to the strip that runs across.
        Shape {
            anchors.fill: parent

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.ink
                startX: window.leftReel
                startY: window.middle - root.look.reel / 2

                PathLine { x: window.width / 2; y: window.middle - root.look.taper / 2 }
                PathLine { x: window.width / 2; y: window.middle + root.look.taper / 2 }
                PathLine { x: window.leftReel; y: window.middle + root.look.reel / 2 }
                PathLine { x: window.leftReel; y: window.middle - root.look.reel / 2 }
            }
        }

        Rectangle {
            x: window.width / 2
            y: window.middle - root.look.stripHeight / 2
            width: window.rightReel - window.width / 2
            height: root.look.stripHeight
            color: root.paper
        }

        Repeater {
            model: 2

            delegate: Item {
                id: reel

                required property int index

                x: (index === 0 ? window.leftReel : window.rightReel) - width / 2
                y: window.middle - height / 2
                width: root.look.reel
                height: root.look.reel
                rotation: index === 0 ? root.angle : -root.angle

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.paper
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.look.hub
                    height: root.look.hub
                    radius: width / 2
                    color: root.deepest
                }

                // Teeth around the hub, pointing in.
                Repeater {
                    model: root.look.teeth

                    delegate: Rectangle {
                        required property int index

                        readonly property real angle: 2 * Math.PI * index / root.look.teeth
                        readonly property real reach: (root.look.hub - root.look.tooth) / 2

                        x: reel.width / 2 + reach * Math.cos(angle) - width / 2
                        y: reel.height / 2 + reach * Math.sin(angle) - height / 2
                        width: root.look.tooth
                        height: root.look.tooth
                        rotation: angle * 180 / Math.PI
                        color: root.paper
                    }
                }
            }
        }
    }
}
