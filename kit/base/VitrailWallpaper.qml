import QtQuick
import QtQuick.Effects
import QtMultimedia
import ".."
import "../wallpaper.js" as Transition

// Wallpaper: an image or a looping, muted video.
//
// The `wallpaper` variant picks the fit: "frame" lays the media inside the
// frame hole, so it makes room when a full panel opens; "screen" covers the
// whole screen and never moves. Either way only the hole shows it sharp. On
// glass a blurred copy fills the screen behind the translucent frame; on
// solid the frame sits on the plain surface color.
//
// A picture change can carry a short animation (`transition`: random, ink,
// outline or fade). A shader draws the outgoing picture and the incoming one
// through the animation (kit/shaders/wallpaper-transition); videos change in
// place. The spec comes from the incoming picture (kit/wallpaper.js), so both
// outputs showing the same picture animate together.
Item {
    id: root

    property string variant: ""
    // Absolute path to an image or a video file.
    property string source: ""
    // none | random | ink | outline | fade. "random" picks between ink and
    // outline from the incoming picture's path.
    property string transition: "none"
    property int transitionTime: VitrailTokens.ranges.transition.value
    // Hole insets and corner radius, usually from frame.js layout().
    property var hole: ({ left: 0, top: 0, right: 0, bottom: 0 })
    property real radius: 0
    // A fullscreen window owns the screen: the video stops instead of decoding
    // behind it, and the change animation is skipped (nothing to animate for).
    property bool paused: false

    readonly property var style: VitrailStyle.resolve("wallpaper", root.variant)
    readonly property var surface: VitrailStyle.resolve("surface", VitrailTokens.surfaceMode)
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property bool video: root.isVideo(root.source)
    readonly property bool leavingVideo: root.isVideo(root.leavingSource)

    // A covered screen costs nothing: the player stops and the last frame stays.
    onPausedChanged: {
        if (!root.video)
            return
        if (root.paused)
            video.pause()
        else
            video.play()
    }

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

    // --- the change ---------------------------------------------------------
    // `shownSource` is on screen; `leavingSource` is what the animation is
    // replacing. Both are paths, so the shader can sample their textures while
    // the plain images stay out of the way.
    property string shownSource: ""
    property string leavingSource: ""
    property string transitionKind: "none"
    property real transitionProgress: 1
    property real transitionSeed: 0
    property real transitionOriginX: 0.5
    property real transitionOriginY: 0.5
    property int transitionDuration: 0
    property bool transitionPending: false
    // The shader's two textures need a frame or two to be captured: until
    // then the old picture stays on screen instead of a black frame.
    property bool texturesWarm: false

    readonly property bool transitioning: root.leavingSource !== ""
    readonly property bool shaderTransition: root.transitioning && root.transitionKind !== "none"
                                             && !root.video && !root.leavingVideo
    readonly property bool shaderOn: root.shaderTransition && root.texturesWarm

    function isVideo(path) {
        return /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(path || "")
    }

    function finishTransition() {
        progressAnimation.stop()
        safety.stop()
        warm.stop()
        root.leavingSource = ""
        root.transitionKind = "none"
        root.transitionProgress = 1
        root.transitionPending = false
        root.texturesWarm = false
    }

    // The animation ended (or was skipped): the new picture takes over the
    // plain layer.
    function completeTransition() {
        root.shownSource = root.source
        root.finishTransition()
    }

    function beginTransition(leaving) {
        var spec = Transition.spec(root.source, root.transition, root.transitionTime)
        root.leavingSource = leaving
        // A video has no still to draw; a picture with the animation off
        // changes at once.
        if (spec.kind === "none" || root.video || root.leavingVideo) {
            root.completeTransition()
            return
        }
        root.transitionKind = spec.kind
        root.transitionDuration = spec.duration
        root.transitionSeed = spec.seed
        root.transitionOriginX = spec.originX
        root.transitionOriginY = spec.originY
        root.transitionProgress = 0
        root.texturesWarm = false
        root.transitionPending = true
        safety.interval = root.transitionDuration + 1500
        safety.restart()
        root.maybeStart()
    }

    // The shader needs both textures loaded: starting earlier would flash a
    // blank frame at the first move.
    function maybeStart() {
        if (!root.transitionPending || !root.shaderTransition)
            return
        if (incomingImage.status !== Image.Ready || currentImage.status !== Image.Ready)
            return
        root.transitionPending = false
        warm.restart()
    }

    onSourceChanged: {
        var leaving = root.shownSource
        if (root.transitioning) {
            // A second change cuts the first one short: go straight to the
            // newest picture instead of starting a third animation.
            root.completeTransition()
            return
        }
        if (leaving === "" || leaving === root.source || root.transition === "none") {
            root.completeTransition()
            return
        }
        root.beginTransition(leaving)
    }
    onTransitionChanged: if (root.transition === "none") root.completeTransition()

    Component.onCompleted: root.shownSource = root.source

    Timer {
        id: warm

        interval: 60
        onTriggered: {
            root.texturesWarm = true
            progressAnimation.restart()
        }
    }

    NumberAnimation {
        id: progressAnimation

        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: root.transitionDuration
        easing.type: Easing.InOutCubic
        onFinished: root.completeTransition()
    }

    // A shader that never starts (a missing .qsb, a backend without shaders)
    // must still end on the new picture.
    Timer {
        id: safety

        onTriggered: root.completeTransition()
    }

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

        // The pair the shader samples. While it runs, `hideSource` keeps these
        // out of the layer and the shader draws their textures instead.
        Image {
            id: currentImage

            anchors.fill: parent
            source: root.video || root.shownSource === "" ? "" : "file://" + root.shownSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            onStatusChanged: root.maybeStart()
        }

        // The incoming picture only feeds the shader; it must never show
        // before the animation starts.
        Image {
            id: incomingImage

            anchors.fill: parent
            visible: false
            layer.enabled: true
            source: root.video || root.source === "" ? "" : "file://" + root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            onStatusChanged: root.maybeStart()
        }

        Video {
            id: video

            anchors.fill: parent
            source: root.video && root.shownSource !== "" ? "file://" + root.shownSource : ""
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: !root.paused
            opacity: root.video ? 1 : 0
        }

        // The old picture stays visible while the textures warm; once the
        // shader is on, it is hidden and sampled as `previous`.
        ShaderEffectSource {
            id: previousTexture

            sourceItem: currentImage
            hideSource: root.shaderOn
            live: root.shaderTransition
            width: media.width
            height: media.height
        }

        ShaderEffectSource {
            id: incomingTexture

            sourceItem: incomingImage
            hideSource: true
            live: root.shaderTransition
            width: media.width
            height: media.height
        }

        ShaderEffect {
            anchors.fill: parent
            // `visible` bindings do not update under this hidden layer: fade
            // the shader itself instead, and keep it out of the way at rest.
            opacity: root.shaderOn ? 1 : 0
            // The two samplers are declared in this order in the shader.
            property var previous: previousTexture
            property var incoming: incomingTexture
            property real progress: root.transitionProgress
            property real mode: root.transitionKind === "ink" ? 0
                                 : (root.transitionKind === "outline" ? 1 : 2)
            property vector2d origin: Qt.vector2d(root.transitionOriginX, root.transitionOriginY)
            property real seed: root.transitionSeed
            property vector2d texel: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            fragmentShader: "../shaders/wallpaper-transition.frag.qsb"
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
