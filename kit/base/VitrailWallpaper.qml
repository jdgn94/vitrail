import QtQuick
import QtQuick.Effects
import QtMultimedia
import ".."

// Wallpaper: an image or a looping, muted video.
//
// The `wallpaper` variant picks the fit: "frame" lays the media inside the
// frame hole, so it makes room when a full panel opens; "screen" covers the
// whole screen and never moves. Either way only the hole shows it sharp. On
// glass a blurred copy fills the screen behind the translucent frame; on
// solid the frame sits on the plain surface color.
Item {
    id: root

    property string variant: ""
    // Absolute path to an image or a video file.
    property string source: ""
    // Hole insets and corner radius, usually from frame.js layout().
    property var hole: ({ left: 0, top: 0, right: 0, bottom: 0 })
    property real radius: 0

    readonly property var style: VitrailStyle.resolve("wallpaper", root.variant)
    readonly property var surface: VitrailStyle.resolve("surface", VitrailTokens.surfaceMode)
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property bool video: /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(root.source)
    readonly property url url: root.source === "" ? "" : "file://" + root.source

    // Same animation as VitrailFrame, so both glide together.
    property real leftInset: root.hole.left
    property real topInset: root.hole.top
    property real rightInset: root.hole.right
    property real bottomInset: root.hole.bottom
    property real corner: root.radius

    Behavior on leftInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on topInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on rightInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on bottomInset { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
    Behavior on corner { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: VitrailTokens.color("surface")
    }

    // The media, sized for the fit. Hidden: the effects below draw it.
    Item {
        id: media

        readonly property bool framed: root.style.fit === "frame"

        x: framed ? root.leftInset : 0
        y: framed ? root.topInset : 0
        width: framed ? root.width - root.leftInset - root.rightInset : root.width
        height: framed ? root.height - root.topInset - root.bottomInset : root.height
        visible: false
        layer.enabled: true

        Image {
            id: picture

            anchors.fill: parent
            visible: !root.video
            source: root.video ? "" : root.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        Video {
            anchors.fill: parent
            visible: root.video
            source: root.video ? root.url : ""
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.surface.blur
        source: media
        blurEnabled: true
        blur: VitrailTokens.blur / VitrailTokens.ranges.blur.max
    }

    // Only the rounded hole shows the media sharp.
    MultiEffect {
        x: media.x
        y: media.y
        width: media.width
        height: media.height
        source: media
        maskEnabled: true
        maskSource: holeMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Item {
        id: holeMask

        width: media.width
        height: media.height
        visible: false
        layer.enabled: true

        Rectangle {
            x: root.leftInset - media.x
            y: root.topInset - media.y
            width: root.width - root.leftInset - root.rightInset
            height: root.height - root.topInset - root.bottomInset
            radius: root.corner
        }
    }
}
