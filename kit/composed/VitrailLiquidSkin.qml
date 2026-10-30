import QtQuick
import ".."
import "../base"
import "../frame.js" as Frame

// A floating card (a bar popup, the notification stack) as an island that
// grows out of its bar and back into it. `rect` is where the card rests; the
// skin draws it as `look` (VitrailLiquid.look) says: in glass it leaves the
// bar face as a drop, joined to the `source` island by a liquid neck that
// thins and snaps; in solid it fades and slides in. Fills the layer it is in.
Item {
    id: root

    property string edge: "left"
    property var rect: Qt.rect(0, 0, 0, 0)
    // The button (or point) it grows from, and the island or bar it leaves.
    property var origin: null
    property var source: null
    property var look
    // Distance of the card's near face from the bar face at rest.
    property real gap: 0
    // Where the card is still heading along the bar (see Frame.liquidRect).
    property real lag: 0
    property real opacityLevel: VitrailTokens.opacity

    readonly property rect skin: Frame.floatRect(root.rect, root.edge, root.origin, root.look, root.gap, root.lag)
    // A rectangle clamps its own radius when it is small; the neck needs it.
    readonly property real radius: Math.min(VitrailTokens.radius, root.skin.width / 2, root.skin.height / 2)

    opacity: root.look.fade

    VitrailNeck {
        anchors.fill: parent
        edge: root.edge
        island: root.source
        card: root.skin
        bond: root.look.bond
        radius: root.radius
        opacityLevel: root.opacityLevel
    }

    VitrailSurface {
        x: root.skin.x
        y: root.skin.y
        width: root.skin.width
        height: root.skin.height
        visible: width > 0 && height > 0
        opacityLevel: root.opacityLevel
    }
}
