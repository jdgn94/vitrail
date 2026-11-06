import QtQuick
import "../kit"

// The drop itself: a circle at the icon that grows into a rounded card over
// the space the launching window will take, then fades when the window maps
// (or when the request times out). A closing window gets the reverse: its last
// rect shrinks to a point while it fades. It is a plain Item so the state can
// be tested offscreen; the layer supplies the request.
Item {
    id: root

    // A request from droplet.js, local to this monitor.
    property var request: null
    property string screen: ""
    readonly property var current: root.request && root.request.screen === root.screen
                                     ? root.request : null

    // The first request grows from its origin; a later one (the window mapped
    // or the timeout fired) moves straight to its new target and fades.
    property bool grown: false
    property real started: -1
    readonly property bool fading: root.current !== null && root.current.phase === "fading"

    function reach() {
        if (!root.current)
            return
        var target = root.current.target
        drop.x = target.x
        drop.y = target.y
        drop.width = target.width
        drop.height = target.height
        drop.radius = root.current.phase === "closing"
                      ? Math.min(target.width, target.height) / 2
                      : VitrailTokens.radius
        drop.opacity = root.current.phase === "fading"
                       || root.current.phase === "closing"
                       ? 0 : VitrailTokens.opacity * VitrailTokens.droplet.tint
    }

    onCurrentChanged: {
        if (!root.current) {
            root.grown = false
            drop.opacity = 0
            return
        }
        var fresh = root.current.started !== root.started
        root.started = root.current.started
        if (!root.grown || fresh) {
            root.grown = true
            var origin = root.current.origin
            drop.x = origin.x
            drop.y = origin.y
            drop.width = origin.width
            drop.height = origin.height
            drop.radius = Math.min(origin.width, origin.height) / 2
            drop.opacity = VitrailTokens.opacity * VitrailTokens.droplet.tint
            Qt.callLater(root.reach)
            return
        }
        root.reach()
    }

    Rectangle {
        id: drop

        visible: root.current !== null
        color: VitrailTokens.color("primary")
        opacity: 0
        radius: 0

        Behavior on x { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: VitrailTokens.droplet.fade; easing.type: Easing.OutCubic } }
    }
}
