import QtQuick
import QtQuick.Shapes
import "../kit"
import "../kit/base"
import "../kit/frame.js" as Frame
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

    // One fused path, not overlapping translucent items: the neck follows the
    // origin→mass centre line, so diagonal launches keep their liquid bridge.
    readonly property var goo: Frame.goo(root.originRect, root.massRect,
                                         root.opening ? root.look.bond : 0,
                                         drop.radius, root.look.swell)

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
                      ? Math.min(target.width, target.height) / 2
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

    // The animated item owns the mass rect and opacity; its child draws in
    // monitor coordinates so the birth circle and diagonal neck can extend
    // outside that rect. No timer or repaint runs once the geometry settles.
    Item {
        id: drop

        objectName: "dropletMass"
        visible: root.current !== null
        opacity: 0
        property real radius: 0

        Behavior on x { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: VitrailTokens.droplet.fade; easing.type: Easing.OutCubic } }

        Shape {
            x: -drop.x
            y: -drop.y
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: VitrailTokens.color("primary")
                strokeColor: "transparent"
                fillRule: ShapePath.WindingFill

                PathSvg { path: root.goo.path }
            }
        }
    }

    VitrailBusy {
        objectName: "dropletLoader"
        running: root.current !== null
                 && (root.current.phase === "hold" || root.current.phase === "settling")
        color: VitrailTokens.color("accentForeground", VitrailTokens.color("primary"))
        x: root.massRect.x + root.massRect.width / 2 - width / 2
        y: root.massRect.y + root.massRect.height / 2 - height / 2
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
