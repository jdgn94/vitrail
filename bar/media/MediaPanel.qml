import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../kit"
import "../kit/base"
import "media.js" as Media

// Now playing, in two looks:
//
//   disc      a round cover with a ring of marks: dots while paused, bouncing
//             bars while it plays, when the cover turns like a record (DiscArt);
//   cassette  a tape with the cover in its window and two reels that turn
//             (CassetteArt).
//
// The progress is the same in both: a wave for the played part, a playhead, a
// thin line and an end dot. Loop, shuffle, previous/play/next, and a player
// selector when more than one is running.
Item {
    id: root

    property var player: null
    property var players: []
    property int index: 0
    property var strings: ({})
    property string style: "disc"

    signal playerChosen(int index)

    readonly property var current: root.players.length > root.index ? root.players[root.index] : root.player
    readonly property bool playing: root.current ? Media.isPlaying(root.current.playbackState) : false
    readonly property bool looping: root.current ? root.current.loopState !== MprisLoopState.None : false
    readonly property bool shuffled: root.current ? root.current.shuffle : false
    property real position: 0
    readonly property real length: root.current ? root.current.length : 0
    readonly property string trackLabel: root.current ? Media.label(root.current.metadata, root.current.identity) : ""
    readonly property string elapsed: Media.clock(root.position)
    readonly property string total: Media.clock(root.length)
    readonly property string cover: root.current ? root.current.trackArtUrl : ""

    implicitWidth: 360
    implicitHeight: body.implicitHeight

    function appName(item) {
        return item ? (item.identity || item.desktopEntry || "") : ""
    }

    function appIcon(item) {
        var entry = item ? (item.desktopEntry || "") : ""
        return entry !== "" ? Quickshell.iconPath(entry, true) : ""
    }

    // A click or a drag on the bar seeks to that fraction of the track.
    function seekAt(x) {
        if (!root.current || !root.current.canSeek || root.length <= 0)
            return
        var seconds = Math.max(0, Math.min(root.length, (x / progress.width) * root.length))
        root.position = seconds
        root.current.position = seconds
    }

    // The elapsed time: follow the player when it seeks, count on our own
    // otherwise, so the readout moves every quarter second.
    function advance() {
        if (!root.current)
            return
        var reported = root.current.position
        if (Math.abs(reported - root.position) > 1.5)
            root.position = reported
        else
            root.position = Math.min(root.length, root.position + 0.25)
    }

    onCurrentChanged: root.position = root.current ? root.current.position : 0

    Timer {
        interval: 250
        repeat: true
        running: root.playing
        onTriggered: root.advance()
    }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // None → Track → Playlist → None.
    function cycleLoop() {
        if (!root.current)
            return
        var next = (Number(root.current.loopState) + 1) % 3
        root.current.loopState = next
    }

    ColumnLayout {
        id: body

        width: parent.width
        spacing: VitrailTokens.gap("xs")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            // --- the cover, in either look -----------------------------------
            Item {
                id: art

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: disc.implicitWidth
                implicitHeight: disc.implicitHeight

                DiscArt {
                    id: disc

                    anchors.centerIn: parent
                    visible: root.style === "disc"
                    playing: root.playing && visible
                    cover: root.cover
                }

                CassetteArt {
                    anchors.centerIn: parent
                    visible: root.style === "cassette"
                    playing: root.playing && visible
                    cover: root.cover
                }
            }


            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("xs")

                    VitrailMarquee {
                        Layout.fillWidth: true
                        variant: "body"
                        text: root.trackLabel !== "" ? root.trackLabel : root.t("media.nothing")
                    }
                }

                VitrailMarquee {
                    Layout.fillWidth: true
                    variant: "label"
                    color: Qt.alpha(VitrailTokens.color("foreground"), 0.7)
                    text: root.current ? (root.current.trackArtist || root.current.identity || "") : ""
                }

                // The progress, in both looks: a wave for the played part, a
                // rounded playhead, a thin line for what is left and a small dot
                // at the end. The wave travels slowly while it plays and holds
                // still when paused.
                Item {
                    id: progress

                    readonly property var look: VitrailTokens.media.progress
                    readonly property var parts: Media.progressLayout(width, Media.progress(root.position, root.length),
                                                                      look.head, look.gap, look.dot)

                    Layout.fillWidth: true
                    implicitHeight: Math.max(look.height, 20)

                    // Click or drag anywhere on the bar to seek.
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.current ? root.current.canSeek : false
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function (mouse) { root.seekAt(mouse.x) }
                        onPositionChanged: function (mouse) { if (pressed) root.seekAt(mouse.x) }
                    }

                    // Paused: a flat bar that is always visible (the volume
                    // slider's look); it fades out when the wave comes in.
                    Item {
                        anchors.fill: parent
                        opacity: root.playing ? 0 : 1

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: progress.look.wave
                            radius: height / 2
                            color: Qt.alpha(VitrailTokens.color("primary"), progress.look.rest)
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * Media.progress(root.position, root.length)
                            height: progress.look.wave
                            radius: height / 2
                            color: VitrailTokens.color("primary")

                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.Linear } }
                        }
                    }

                    // Playing: the wave, the playhead, the line and the end dot.
                    Item {
                        anchors.fill: parent
                        opacity: root.playing ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }

                        Canvas {
                            id: wave

                            // How far the wave has travelled, in radians.
                            property real phase: 0
                            readonly property real end: progress.parts.waveEnd

                            anchors.fill: parent

                            onEndChanged: requestPaint()
                            onPhaseChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            Connections {
                                target: VitrailTokens

                                function onPaletteChanged() { wave.requestPaint() }
                            }

                            FrameAnimation {
                                running: root.playing
                                onTriggered: wave.phase = (wave.phase + 2 * Math.PI * frameTime * 1000 / progress.look.period) % (2 * Math.PI)
                            }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var look = progress.look
                                var cap = look.wave / 2
                                if (end <= 0)
                                    return
                                ctx.strokeStyle = VitrailTokens.color("primary")
                                ctx.lineWidth = look.wave
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                var tip = Math.max(cap, end - cap)
                                for (var x = cap; x < tip; x += look.step)
                                    ctx.lineTo(x, height / 2 + Math.sin(2 * Math.PI * x / look.wavelength - phase) * look.amplitude)
                                ctx.lineTo(tip, height / 2 + Math.sin(2 * Math.PI * tip / look.wavelength - phase) * look.amplitude)
                                ctx.stroke()
                            }
                        }

                        // The playhead.
                        Rectangle {
                            x: progress.parts.headX
                            anchors.verticalCenter: parent.verticalCenter
                            width: progress.look.head
                            height: progress.look.headHeight
                            radius: width / 2
                            color: VitrailTokens.color("primary")
                        }

                        // What is left.
                        Rectangle {
                            x: progress.parts.lineStart
                            anchors.verticalCenter: parent.verticalCenter
                            width: progress.parts.lineWidth
                            height: progress.look.line
                            radius: height / 2
                            visible: width > 0
                            color: Qt.alpha(VitrailTokens.color("primary"), progress.look.rest)
                        }

                        // The end dot.
                        Rectangle {
                            x: progress.parts.dotX
                            anchors.verticalCenter: parent.verticalCenter
                            width: progress.look.dot
                            height: progress.look.dot
                            radius: width / 2
                            color: Qt.alpha(VitrailTokens.color("primary"), progress.look.end)
                        }
                    }
                }


                RowLayout {
                    Layout.fillWidth: true

                    VitrailText {
                        variant: "label"
                        text: root.elapsed
                    }

                    Item { Layout.fillWidth: true }

                    VitrailText {
                        variant: "label"
                        text: root.total
                    }
                }
            }
        }

        // The controls.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: VitrailTokens.gap("sm")

            VitrailButton {
                variant: "plain"
                tone: root.shuffled ? "primary" : "secondary"
                size: "sm"
                icon: "shuffle"
                enabled: root.current ? root.current.shuffleSupported : false
                onClicked: if (root.current) root.current.shuffle = !root.current.shuffle
            }

            VitrailButton {
                variant: "text"
                tone: "secondary"
                size: "sm"
                icon: "skip_previous"
                enabled: root.current ? root.current.canGoPrevious : false
                onClicked: if (root.current) root.current.previous()
            }

            VitrailButton {
                variant: "filled"
                size: "md"
                icon: root.playing ? "pause" : "play_arrow"
                enabled: root.current ? root.current.canTogglePlaying : false
                onClicked: if (root.current) root.current.togglePlaying()
            }

            VitrailButton {
                variant: "text"
                tone: "secondary"
                size: "sm"
                icon: "skip_next"
                enabled: root.current ? root.current.canGoNext : false
                onClicked: if (root.current) root.current.next()
            }

            VitrailButton {
                variant: "plain"
                tone: root.looping ? "primary" : "secondary"
                size: "sm"
                icon: "repeat"
                enabled: root.current !== null
                onClicked: root.cycleLoop()
            }
        }

        // The application selector: a chip with the icon and the name that
        // opens the list of players, one entry per application.
        Item {
            id: selector

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: chip.implicitWidth
            implicitHeight: chip.implicitHeight
            property bool expanded: false

            // The list opens above the chip.
            Rectangle {
                visible: selector.expanded && root.players.length > 1
                anchors.bottom: chip.top
                anchors.bottomMargin: VitrailTokens.gap("xs")
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(chip.width, listColumn.implicitWidth + 2 * VitrailTokens.gap("sm"))
                height: listColumn.implicitHeight + 2 * VitrailTokens.gap("xs")
                radius: VitrailTokens.radius * 0.6
                color: VitrailTokens.color("surfaceHigh")

                Column {
                    id: listColumn

                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: root.players

                        delegate: Item {
                            id: choice

                            required property var modelData
                            required property int index

                            width: listColumn.width
                            height: 26

                            Rectangle {
                                anchors.fill: parent
                                radius: VitrailTokens.radius * 0.4
                                color: choice.index === root.index
                                       ? Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                                                 VitrailTokens.color("primary").b, 0.16)
                                       : "transparent"
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: VitrailTokens.gap("xs")

                                Image {
                                    width: 16
                                    height: 16
                                    source: root.appIcon(choice.modelData)
                                    visible: source !== ""
                                    asynchronous: true
                                }

                                VitrailText {
                                    variant: "label"
                                    text: root.appName(choice.modelData)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.playerChosen(choice.index)
                                    selector.expanded = false
                                }
                            }
                        }
                    }
                }
            }

            // The chip.
            Rectangle {
                id: chip

                width: chipRow.implicitWidth + 2 * VitrailTokens.gap("sm")
                height: chipRow.implicitHeight + 6
                radius: height / 2
                color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                               VitrailTokens.color("foreground").b, selector.expanded ? 0.12 : 0.07)

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: VitrailTokens.gap("xs")

                    Image {
                        width: 14
                        height: 14
                        source: root.appIcon(root.current)
                        visible: source !== ""
                        asynchronous: true
                    }

                    VitrailMarquee {
                        width: 96
                        variant: "label"
                        text: root.appName(root.current)
                    }

                    VitrailIcon {
                        visible: root.players.length > 1
                        icon: selector.expanded ? "expand_less" : "expand_more"
                        size: "sm"
                        tone: "secondary"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.players.length > 1
                    onClicked: selector.expanded = !selector.expanded
                }
            }
        }
    }
}
