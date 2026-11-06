import QtQuick
import "../kit"
import "../kit/base"
import "burst.js" as Burst

// The drop itself: a gooey mass born at the icon or pointer, stretched toward
// the space the window will take by a liquid neck, then expanded over its final
// rect. It stays opaque on that space, fades when the window maps, and a closing
// window gets the reverse: a quick puff and a ring of droplets bursting out.
// It is a plain Item so the state can be tested offscreen; the layer supplies
// the request.
Item {
    id: root

    // A request from droplet.js, local to this monitor.
    property var request: null
    property string screen: ""
    readonly property var current: root.request && root.request.screen === root.screen
                                     ? root.request : null

    // The first request grows from its origin; a later one (the window mapped
    // or the timeout fired) moves straight to its new target. `placing` keeps
    // the drop opaque over the final rect; only `fading` lets it fade away.
    property bool grown: false
    property real started: -1
    readonly property bool fading: root.current !== null && root.current.phase === "fading"
    readonly property bool closing: root.current !== null && root.current.phase === "closing"
    readonly property bool opening: root.current !== null
                                  && (root.current.phase === "hold"
                                      || root.current.phase === "settling"
                                      || root.current.phase === "placing")
    readonly property real opacityLevel: VitrailTokens.opacity * VitrailTokens.droplet.tint
    readonly property var originRect: root.current ? root.current.origin : Qt.rect(0, 0, 0, 0)
    readonly property var massRect: Qt.rect(drop.x, drop.y, drop.width, drop.height)

    // The popup's liquid timeline (frame.js liquid / smooth). It runs only while
    // the drop is opening or holding, so its neck cannot grow back while fading.
    VitrailLiquid {
        id: liquid

        open: root.opening
    }
    readonly property var look: liquid.look

    // The neck leaves the side of the origin that faces the target.
    readonly property string neckEdge: {
        if (!root.current)
            return "left"
        var o = root.originRect, t = root.current.target
        var dx = (t.x + t.width / 2) - (o.x + o.width / 2)
        var dy = (t.y + t.height / 2) - (o.y + o.height / 2)
        if (Math.abs(dx) >= Math.abs(dy))
            return dx >= 0 ? "left" : "right"
        return dy >= 0 ? "top" : "bottom"
    }

    // The burst is the closing bubble: a deterministic ring from burst.js.
    readonly property var burstParticles: {
        if (!root.closing)
            return []
        var reach = Math.max(VitrailTokens.droplet.burst.reachMin,
                             Math.max(root.originRect.width, root.originRect.height)
                             * VitrailTokens.droplet.burst.reach)
        return Burst.particles(VitrailTokens.droplet.burst.count, reach,
                               VitrailTokens.droplet.burst.duration,
                               VitrailTokens.droplet.burst.size)
    }
    readonly property var burstCentre: {
        var o = root.originRect
        return { x: o.x + o.width / 2, y: o.y + o.height / 2 }
    }

    function reach() {
        if (!root.current)
            return
        var target = root.current.target
        drop.x = target.x
        drop.y = target.y
        drop.width = target.width
        drop.height = target.height
        var ending = root.current.phase === "fading" || root.current.phase === "closing"
        drop.radius = root.current.phase === "closing"
                      ? Math.min(VitrailTokens.radius,
                                  Math.min(target.width, target.height) / 2)
                      : Math.min(VitrailTokens.radius * root.look.swell,
                                  Math.min(target.width, target.height) / 2)
        drop.opacity = ending ? 0 : root.opacityLevel
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
            drop.opacity = root.opacityLevel
            Qt.callLater(root.reach)
            return
        }
        root.reach()
    }

    // The liquid neck between the birth point and the growing mass.
    VitrailNeck {
        objectName: "dropletNeck"

        anchors.fill: parent
        visible: root.opening && root.look.bond > 0.01
        edge: root.neckEdge
        island: root.originRect
        card: root.current ? root.current.target : root.massRect
        bond: root.look.bond
        radius: Math.min(VitrailTokens.radius,
                         Math.min(root.massRect.width, root.massRect.height) / 2)
        tint: VitrailTokens.color("primary")
        opacityLevel: root.opacityLevel
    }

    Rectangle {
        id: drop

        objectName: "dropletMass"
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

    // The closing burst: small drops leave the last rect, each on its own angle
    // and delay, and fade before `droplet.burst.duration`.
    Repeater {
        model: root.burstParticles

        delegate: VitrailShape {
            id: speck

            required property var modelData
            required property int index

            objectName: "burstParticle" + index
            width: modelData.size
            height: modelData.size
            kind: "circle"
            fill: index % 2 === 0 ? VitrailTokens.color("primary")
                                  : VitrailTokens.color("info")
            x: root.burstCentre.x - width / 2
            y: root.burstCentre.y - height / 2
            opacity: 0

            SequentialAnimation {
                running: true

                PauseAnimation { duration: speck.modelData.delay }

                ParallelAnimation {
                    NumberAnimation {
                        target: speck
                        property: "x"
                        to: root.burstCentre.x
                            + Math.cos(speck.modelData.angle) * speck.modelData.distance
                            - speck.width / 2
                        duration: speck.modelData.duration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: speck
                        property: "y"
                        to: root.burstCentre.y
                            + Math.sin(speck.modelData.angle) * speck.modelData.distance
                            - speck.height / 2
                        duration: speck.modelData.duration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: speck
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: speck.modelData.duration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
