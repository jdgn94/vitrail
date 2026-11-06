import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../kit"
import "../kit/base"
import "media.js" as Media

// Now playing, in two looks:
//
//   disc      a vinyl record with a ring of marks: dots while paused, bouncing
//             bars while it plays, when the record turns (DiscArt);
//   cassette  a tape with the cover in its window and two reels that turn
//             (CassetteArt).
//
// The progress is the same in both: the shell's slider (seekable), with a wave
// over its filled part that fades in while it plays. Below: loop, shuffle,
// previous/play/next, and the application chip, whose list of players (when
// more than one is running) opens upward over the card, so it never changes the
// card's size (the popup is sized to its content and clips anything outside).
// The chip and the list size to their content: a name takes its text width up to
// `media.chip.nameMax`, then scrolls.
//
// One spacing (`unit`) separates every cell of the grid; the host card pads the
// content by the same amount, so the padding is even on all sides.
Item {
    id: root

    property var player: null
    property var players: []
    property int index: 0
    property var strings: ({})
    property string style: "disc"
    // sm / md / lg: the card's spacing and control sizes. "md" is today's look.
    property string size: "md"
    // The widget's own typography; empty values keep the variant's look.
    property string fontFamily: ""
    property string fontWeight: ""
    property bool italic: false

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

    readonly property var look: VitrailTokens.media
    readonly property var scaleBySize: ({
        sm: { small: "sm", main: "sm", unit: "sm" },
        md: { small: "sm", main: "md", unit: "md" },
        lg: { small: "md", main: "lg", unit: "lg" }
    })[root.size] || ({ small: "sm", main: "md", unit: "md" })
    readonly property real unit: VitrailTokens.gap(root.scaleBySize.unit)

    implicitWidth: Math.max(root.look.panel.width, body.implicitWidth)
    implicitHeight: body.implicitHeight

    function appName(item) {
        return item ? (item.identity || item.desktopEntry || "") : ""
    }

    function appIcon(item) {
        var entry = item ? (item.desktopEntry || "") : ""
        return entry !== "" ? Quickshell.iconPath(entry, true) : ""
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
        running: root.playing && !bar.pressed
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

    GridLayout {
        id: body

        width: parent.width
        columns: root.style === "minimal" ? 1 : 2
        columnSpacing: root.unit
        rowSpacing: root.unit

        // --- the cover, in either look: a cell as big as the larger one, so
        // switching looks does not move anything.
        Item {
            id: art

            Layout.alignment: Qt.AlignVCenter
            visible: root.style !== "minimal"
            implicitWidth: Math.max(disc.implicitWidth, cassette.implicitWidth)
            implicitHeight: Math.max(disc.implicitHeight, cassette.implicitHeight)

            DiscArt {
                id: disc

                anchors.centerIn: parent
                visible: root.style === "disc"
                playing: root.playing && visible
                cover: root.cover
                label: root.trackLabel
            }

            CassetteArt {
                id: cassette

                anchors.centerIn: parent
                visible: root.style === "cassette"
                playing: root.playing && visible
                cover: root.cover
                label: root.trackLabel
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: VitrailTokens.gap("xs")

            VitrailMarquee {
                Layout.fillWidth: true
                variant: "body"
                family: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                text: root.trackLabel !== "" ? root.trackLabel : root.t("media.nothing")
            }

            VitrailMarquee {
                Layout.fillWidth: true
                variant: "label"
                family: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                color: Qt.alpha(VitrailTokens.color("foreground"), 0.7)
                text: root.current ? (root.current.trackArtist || root.current.identity || "") : ""
            }

            // The progress: the shell's slider, seekable, with a wave drawn
            // over its filled part. Playing, the wave eases in (`energy`) while
            // the straight fill steps aside; pausing eases it back.
            Item {
                id: progress

                // 0 paused .. 1 playing, eased with a token duration.
                property real energy: root.playing ? 1 : 0
                // How far the wave has travelled, in radians.
                property real phase: 0
                readonly property var wave: root.look.progress

                Layout.fillWidth: true
                implicitHeight: bar.implicitHeight

                Behavior on energy { NumberAnimation { duration: progress.wave.settle; easing.type: Easing.InOutQuad } }

                onEnergyChanged: canvas.requestPaint()

                VitrailSlider {
                    id: bar

                    width: parent.width
                    size: "sm"
                    stepSize: 0
                    from: 0
                    to: Math.max(root.length, 0)
                    value: root.position
                    readOnly: !root.current || !root.current.canSeek || root.length <= 0
                    fillOpacity: progress.energy > 0 ? 0 : 1
                    onMoved: function (v) {
                        root.position = v
                        root.current.position = v
                    }
                }

                Canvas {
                    id: canvas

                    readonly property real end: bar.activeEnd

                    anchors.fill: bar

                    onEndChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: VitrailTokens

                        function onPaletteChanged() { canvas.requestPaint() }
                    }

                    Connections {
                        target: progress

                        function onPhaseChanged() { canvas.requestPaint() }
                    }

                    // Frame clock: the wave slows to a stop as it flattens.
                    FrameAnimation {
                        running: root.playing || progress.energy > 0
                        onTriggered: progress.phase = (progress.phase + 2 * Math.PI * frameTime * 1000
                                                       / progress.wave.period * progress.energy) % (2 * Math.PI)
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var look = progress.wave
                        var thick = bar.track
                        var cap = thick / 2
                        var amplitude = look.amplitude * progress.energy
                        if (end <= 0 || progress.energy <= 0)
                            return
                        ctx.strokeStyle = VitrailTokens.color("primary")
                        ctx.lineWidth = thick
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        var tip = Math.max(cap, end - cap)
                        for (var x = cap; x < tip; x += look.step)
                            ctx.lineTo(x, height / 2 + Math.sin(2 * Math.PI * x / look.wavelength - progress.phase) * amplitude)
                        ctx.lineTo(tip, height / 2 + Math.sin(2 * Math.PI * tip / look.wavelength - progress.phase) * amplitude)
                        ctx.stroke()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                VitrailText {
                    variant: "label"
                    family: root.fontFamily
                    fontWeight: root.fontWeight
                    italic: root.italic
                    text: root.elapsed
                }

                Item { Layout.fillWidth: true }

                VitrailText {
                    variant: "label"
                    family: root.fontFamily
                    fontWeight: root.fontWeight
                    italic: root.italic
                    text: root.total
                }
            }
        }

        // --- the controls
        RowLayout {
            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignHCenter
            spacing: VitrailTokens.gap("sm")

            VitrailButton {
                variant: "plain"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                tone: root.shuffled ? "primary" : "secondary"
                size: root.scaleBySize.small
                icon: "shuffle"
                enabled: root.current ? root.current.shuffleSupported : false
                onClicked: if (root.current) root.current.shuffle = !root.current.shuffle
            }

            VitrailButton {
                variant: "text"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                tone: "secondary"
                size: root.scaleBySize.small
                icon: "skip_previous"
                enabled: root.current ? root.current.canGoPrevious : false
                onClicked: if (root.current) root.current.previous()
            }

            VitrailButton {
                variant: "filled"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                size: root.scaleBySize.main
                icon: root.playing ? "pause" : "play_arrow"
                enabled: root.current ? root.current.canTogglePlaying : false
                onClicked: if (root.current) root.current.togglePlaying()
            }

            VitrailButton {
                variant: "text"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                tone: "secondary"
                size: root.scaleBySize.small
                icon: "skip_next"
                enabled: root.current ? root.current.canGoNext : false
                onClicked: if (root.current) root.current.next()
            }

            VitrailButton {
                variant: "plain"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                tone: root.looping ? "primary" : "secondary"
                size: root.scaleBySize.small
                icon: "repeat"
                enabled: root.current !== null
                onClicked: root.cycleLoop()
            }
        }

        // --- the application: a chip with the icon, the name (its text width, up
        // to `nameMax`) and a chevron when there is a list to open. Only the chip
        // takes room in the grid; its list of players (when more than one is
        // running) is drawn after the grid, over the card (see `choices`).
        Item {
            id: selector

            readonly property var chipLook: root.look.chip
            readonly property bool open: selector.expanded && root.players.length > 1
            property bool expanded: false

            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: chip.implicitWidth
            implicitHeight: chip.implicitHeight

            // Keyboard: Tab reaches the chip, Enter or Space opens the list,
            // Down opens it on the current player, Escape closes it.
            activeFocusOnTab: root.players.length > 1
            Keys.onReturnPressed: if (root.players.length > 1) selector.expanded = !selector.expanded
            Keys.onSpacePressed: if (root.players.length > 1) selector.expanded = !selector.expanded
            Keys.onDownPressed: {
                if (root.players.length < 2)
                    return
                selector.expanded = true
                var at = choiceList.itemAt(Math.max(0, root.index))
                if (at)
                    at.forceActiveFocus()
            }
            Keys.onEscapePressed: selector.expanded = false

            Rectangle {
                id: chip

                anchors.fill: parent
                implicitWidth: chipRow.implicitWidth + 2 * VitrailTokens.gap("sm")
                implicitHeight: chipRow.implicitHeight + 2 * selector.chipLook.padY
                radius: height / 2
                color: VitrailTokens.solid("foreground", selector.open ? selector.chipLook.open : selector.chipLook.rest)

                Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }

                // Where the keyboard is.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: selector.activeFocus ? 2 : 0
                    border.color: VitrailTokens.color("primary")
                    visible: selector.activeFocus
                }

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: VitrailTokens.gap("xs")

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: selector.chipLook.icon
                        height: selector.chipLook.icon
                        source: root.appIcon(root.current)
                        visible: source !== ""
                        asynchronous: true
                    }

                    VitrailMarquee {
                        id: chipName

                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(chipName.textWidth, selector.chipLook.nameMax)
                        variant: "label"
                        family: root.fontFamily
                        fontWeight: root.fontWeight
                        italic: root.italic
                        text: root.appName(root.current)
                    }

                    VitrailIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.players.length > 1
                        icon: selector.open ? "expand_less" : "expand_more"
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

    // Clicking anywhere else on the card closes the list, and only closes it.
    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: selector.open
        onClicked: selector.expanded = false
    }

    // One entry per application; the current one is shaded. It sits just above
    // the chip, over the cover and the controls: as wide as its widest entry
    // (plus padding), centred on the chip and kept inside the card. `body` fills
    // the card from its corner, so `selector.x` is already in the card's space.
    Rectangle {
        id: choices

        // The most an entry's name can take: the card's width less the padding.
        readonly property real nameRoom: root.width - 2 * VitrailTokens.gap("xs") - 2 * VitrailTokens.gap("sm")

        z: 2
        x: Math.max(0, Math.min(root.width - width, selector.x + (selector.width - width) / 2))
        y: selector.y - height - VitrailTokens.gap("xs")
        width: Math.min(implicitWidth, root.width)
        height: implicitHeight
        visible: selector.open
        implicitWidth: listColumn.implicitWidth + 2 * VitrailTokens.gap("xs")
        implicitHeight: listColumn.implicitHeight + 2 * VitrailTokens.gap("xs")
        radius: VitrailTokens.radius * selector.chipLook.listRadius
        color: VitrailTokens.color("surfaceHigh")

        ColumnLayout {
            id: listColumn

            anchors.fill: parent
            anchors.margins: VitrailTokens.gap("xs")
            spacing: selector.chipLook.listGap

            Repeater {
                id: choiceList

                model: root.players

                delegate: Item {
                    id: choice

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitWidth: choiceRow.implicitWidth + 2 * VitrailTokens.gap("sm")
                    implicitHeight: selector.chipLook.row

                    // Keyboard: Tab reaches a row, the arrows move through the
                    // list, Enter or Space picks it, Escape goes back to the chip.
                    activeFocusOnTab: choices.visible
                    KeyNavigation.up: choiceList.itemAt(choice.index - 1)
                    KeyNavigation.down: choiceList.itemAt(choice.index + 1)
                    Keys.onReturnPressed: {
                        root.playerChosen(choice.index)
                        selector.expanded = false
                        selector.forceActiveFocus()
                    }
                    Keys.onSpacePressed: {
                        root.playerChosen(choice.index)
                        selector.expanded = false
                        selector.forceActiveFocus()
                    }
                    Keys.onEscapePressed: {
                        selector.expanded = false
                        selector.forceActiveFocus()
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: VitrailTokens.radius * selector.chipLook.rowRadius
                        color: choice.index === root.index
                               ? Qt.alpha(VitrailTokens.color("primary"), selector.chipLook.current)
                               : "transparent"
                    }

                    Row {
                        id: choiceRow

                        anchors.centerIn: parent
                        spacing: VitrailTokens.gap("xs")

                        Image {
                            id: choiceIcon

                            anchors.verticalCenter: parent.verticalCenter
                            width: selector.chipLook.rowIcon
                            height: selector.chipLook.rowIcon
                            source: root.appIcon(choice.modelData)
                            visible: source !== ""
                            asynchronous: true
                        }

                        VitrailMarquee {
                            id: choiceName

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(choiceName.textWidth, selector.chipLook.nameMax,
                                            choices.nameRoom - (choiceIcon.visible ? choiceIcon.width + choiceRow.spacing : 0))
                            variant: "label"
                            family: root.fontFamily
                            fontWeight: root.fontWeight
                            italic: root.italic
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

                    // Where the keyboard is.
                    Rectangle {
                        anchors.fill: parent
                        radius: VitrailTokens.radius * selector.chipLook.rowRadius
                        color: "transparent"
                        border.width: choice.activeFocus ? 2 : 0
                        border.color: VitrailTokens.color("primary")
                        visible: choice.activeFocus
                    }
                }
            }
        }
    }
}
