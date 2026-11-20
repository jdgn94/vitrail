import QtQuick
import QtQuick.Shapes
import "../kit"
import "../kit/base"
import "../kit/frame.js" as Frame
import "../bar/droplet/burst.js" as Burst

// A frozen frame of the launch droplet for the gallery: the gooey opening
// (`phase: "open"`) joined to its origin by a liquid neck, or the closing
// ring of droplets (`phase: "burst"`) leaving a closing window's last rect.
Item {
    id: root

    property string phase: "open"
    // Where the liquid timeline is (0 closed .. 1 open).
    property real progress: 0.18
    // How far the burst has travelled (0 born .. 1 gone).
    property real burstProgress: 0.65

    implicitWidth: 360
    implicitHeight: 260

    readonly property var tokens: VitrailTokens.glass ? VitrailTokens.motion.liquid
                                                      : VitrailTokens.motion.smooth
    readonly property var look: VitrailTokens.glass ? Frame.liquid(root.progress, root.tokens)
                                                    : Frame.smooth(root.progress, root.tokens)
    readonly property var origin: Qt.rect(24, 198, 34, 34)
    readonly property var target: Qt.rect(116, 32, 220, 150)
    readonly property var mass: {
        var grow = root.phase === "open" ? root.look.grow : 1
        var w = root.origin.width + (root.target.width - root.origin.width) * grow
        var h = root.origin.height + (root.target.height - root.origin.height) * grow
        return Qt.rect(root.origin.x + (root.target.x - root.origin.x) * grow,
                       root.origin.y + (root.target.y - root.origin.y) * grow, w, h)
    }
    readonly property real level: VitrailTokens.opacity * VitrailTokens.droplet.tint
    readonly property var burst: {
        if (root.phase !== "burst")
            return []
        var reach = Math.max(VitrailTokens.droplet.burst.reachMin,
                             Math.max(root.target.width, root.target.height)
                             * VitrailTokens.droplet.burst.reach)
        return Burst.particles(VitrailTokens.droplet.burst.count, reach,
                               VitrailTokens.droplet.burst.duration,
                               VitrailTokens.droplet.burst.size)
    }
    readonly property var goo: Frame.goo(root.origin, root.mass,
                                         root.phase === "open" ? root.look.bond : 0,
                                         Math.min(VitrailTokens.radius * root.look.swell,
                                                  Math.min(root.mass.width, root.mass.height) / 2),
                                         root.look.swell)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.phase === "open"
        opacity: root.level * root.look.fade

        ShapePath {
            fillColor: VitrailTokens.color("primary")
            strokeColor: "transparent"
            fillRule: ShapePath.WindingFill

            PathSvg { path: root.goo.path }
        }
    }

    Repeater {
        model: root.burst

        delegate: VitrailShape {
            required property var modelData
            required property int index

            width: modelData.size
            height: modelData.size
            kind: "circle"
            fill: index % 2 === 0 ? VitrailTokens.color("primary")
                                  : VitrailTokens.color("info")
            readonly property var start: Burst.edge(root.target, modelData.angle)
            x: start.x + Math.cos(modelData.angle) * modelData.distance
               * root.burstProgress - width / 2
            y: start.y + Math.sin(modelData.angle) * modelData.distance
               * root.burstProgress - height / 2
            opacity: 1 - root.burstProgress
        }
    }
}
