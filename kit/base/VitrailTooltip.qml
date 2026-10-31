import QtQuick
import ".."

// A small pill that names what is under the pointer: a title and, optionally,
// a muted second line. The surface is the shared one (glass or solid, like
// every card). `active` says the pointer is over the element: the pill
// appears after the hover delay, fades and scales in from the side of the bar
// (`edge`), and goes at once when `active` ends. It never takes input; the
// caller sets x / y (see Frame.tooltipAt).
Item {
    id: root

    property string text: ""
    property string detail: ""
    property bool active: false
    // The bar's edge: the pill grows from that side.
    property string edge: "top"
    property int delay: VitrailTokens.duration("tooltip")
    property real opacityLevel: VitrailTokens.opacity

    // The delay has run out since `active` began.
    property bool waited: false
    readonly property bool shown: root.active && root.waited && root.text !== ""
    readonly property real maxWidth: VitrailTokens.size("display") * 10

    implicitWidth: Math.min(root.maxWidth, Math.max(title.implicitWidth, extra.implicitWidth)) + 2 * VitrailTokens.gap("md")
    implicitHeight: lines.implicitHeight + 2 * VitrailTokens.gap("sm")
    width: implicitWidth
    height: implicitHeight
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : VitrailTokens.motion.smooth.scale
    visible: root.opacity > 0
    transformOrigin: root.edge === "bottom" ? Item.Bottom : root.edge === "left" ? Item.Left
                     : root.edge === "right" ? Item.Right : Item.Top

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }

    onActiveChanged: if (!root.active) root.waited = false

    Timer {
        interval: root.delay
        running: root.active
        onTriggered: root.waited = true
    }

    VitrailSurface {
        anchors.fill: parent
        opacityLevel: root.opacityLevel
    }

    Column {
        id: lines

        anchors.centerIn: parent
        width: parent.width - 2 * VitrailTokens.gap("md")

        VitrailText {
            id: title

            width: parent.width
            variant: "label"
            font.weight: Font.DemiBold
            color: VitrailTokens.color("foreground")
            opacity: 1
            elide: Text.ElideRight
            text: root.text
        }

        VitrailText {
            id: extra

            width: parent.width
            visible: root.detail !== ""
            variant: "label"
            elide: Text.ElideRight
            text: root.detail
        }
    }
}
