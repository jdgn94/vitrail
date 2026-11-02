import QtQuick
import "../kit"
import "../kit/base"

// The full-screen launcher: a dimmed backdrop (glass keeps it translucent so
// the compositor's blur shows) with the shared Launcher content in its
// `fullscreen` variant. It fades and scales in like the session menu; Escape
// or a click on the backdrop dismisses. The window belongs to the shell; this
// only reports `dismissed` and what the content asks for.
Item {
    id: root

    property var strings: ({})
    property var prefs: ({})
    property var store: null
    property string initialMode: ""
    // Fades and scales in while true; the content is made fresh on every open.
    property bool open: false

    signal dismissed()
    signal openPopup(string kind)
    signal openSession()

    focus: true
    opacity: root.open ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

    VitrailSurface {
        anchors.fill: parent
        style: VitrailTokens.surfaceMode
        radius: 0
        tint: VitrailTokens.color("surface")
        opacityLevel: VitrailTokens.opacity
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    // The content is heavy (the app scan, the categories, the pages). Built the
    // first time the launcher opens, it took over two seconds to show; built
    // while the bar settles, the first open is instant. It costs one build per
    // bar start, off screen and after the bar is up.
    property bool warmed: false

    Timer {
        interval: 1500
        running: true
        onTriggered: root.warmed = true
    }

    Loader {
        id: loader

        anchors.fill: parent
        active: root.warmed || root.open || root.opacity > 0
        scale: root.open ? 1 : VitrailTokens.motion.smooth.scale

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }

        sourceComponent: Launcher {
            variant: "fullscreen"
            strings: root.strings
            prefs: root.prefs
            store: root.store
            initialMode: root.initialMode
            screenWidth: root.width
            screenHeight: root.height
            onDone: root.dismissed()
            onOpenPopup: function (kind) { root.openPopup(kind) }
            onOpenSession: root.openSession()
        }
    }
}
