import QtQuick
import "../kit"
import "../kit/base"
import "media.js" as Media

// Minimal now-playing indicator: album art when there is one, the play glyph
// otherwise. The click opens the panel; the tooltip names the track.
Item {
    id: root

    property var player
    property var strings: ({})

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property string trackLabel: root.player ? Media.label(root.player.metadata, root.player.identity) : ""
    property string tooltip: root.trackLabel !== "" ? root.trackLabel : root.t("media.nothing")
    property string tooltipDetail: root.player && Media.isPlaying(root.player.playbackState)
                                  ? root.t("media.playing") : root.t("media.paused")

    implicitWidth: VitrailTokens.size("title") + VitrailTokens.gap("sm")
    implicitHeight: VitrailTokens.size("title") + VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        visible: !!root.player
        color: VitrailTokens.solid("primary", 0.14)
    }

    Image {
        id: art

        anchors.centerIn: parent
        width: VitrailTokens.size("title")
        height: width
        visible: root.player && root.player.trackArtUrl !== ""
        source: art.visible ? root.player.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    VitrailIcon {
        anchors.centerIn: parent
        // An art URL that fails to load leaves the circle empty: fall back.
        visible: !art.visible || art.status !== Image.Ready
        icon: root.player && Media.isPlaying(root.player.playbackState) ? "pause" : "play_arrow"
        size: "md"
        tone: root.player ? "primary" : "muted"
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
