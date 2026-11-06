import QtQuick
import ".."

// Icon primitive: one Material Symbol, resolved by `VitrailIcons`.
//
// `icon` is the ligature name: it goes through the resolver, which draws
// `question_mark` for a name the table does not know (empty means "no icon").
// `size` follows the text scale (sm/md/lg/xl), and `pixelSize` overrides it
// when a component has its own sizing table.
//
// `container` is the user's icon style: outlined draws the bare glyph, the
// container draws it inside a circular badge (primary, `accentForeground`
// glyph). The circle takes the glyph's own advance and the glyph is scaled
// down inside it, so the implicit size is exactly the outlined one and no
// layout moves. The badge is a shape, never a FILL axis, and it owns its ink:
// an explicit `color` is ignored inside it. An active icon is otherwise the
// accent colour, never a fill.
Item {
    id: root

    property string icon: ""
    property string size: "md"
    // Colour role from the palette, or an explicit colour.
    property string tone: "foreground"
    property color color: VitrailTokens.color(root.tone, VitrailTokens.color("foreground"))
    // A family from outside the kit (the Fonts page's preview).
    property string family: ""
    // The badge; a preview may override it to show both states (the gallery).
    property bool container: VitrailTokens.iconContainer

    readonly property var scaleBySize: ({
        sm: "body",
        md: "subtitle",
        lg: "title",
        xl: "display"
    })
    readonly property string step: root.scaleBySize[root.size] || root.scaleBySize.md
    property real pixelSize: VitrailTokens.size(root.step)

    // The name the resolver will draw: empty means "no icon"; an unknown name
    // becomes `question_mark`.
    readonly property string glyph: root.icon !== "" ? VitrailIcons.resolve(root.icon) : ""
    readonly property string resolvedFamily: root.family !== "" ? root.family : VitrailTokens.iconFamily
    // The circle never grows past the glyph's advance, so it stays inside the
    // outlined footprint instead of overlapping its neighbours.
    readonly property real badgeSize: Math.min(glyphText.implicitWidth, glyphText.implicitHeight)
    readonly property color ink: root.container
                                  ? VitrailTokens.color(VitrailTokens.icon.ink, VitrailTokens.color("accentForeground"))
                                  : root.color

    implicitWidth: glyphText.implicitWidth
    implicitHeight: glyphText.implicitHeight

    Rectangle {
        objectName: "badge"
        anchors.centerIn: parent
        width: root.badgeSize
        height: width
        radius: width / 2
        color: VitrailTokens.color(VitrailTokens.icon.badge, VitrailTokens.color("primary"))
        visible: root.container
    }

    VitrailText {
        id: glyphText

        objectName: "glyph"
        anchors.centerIn: parent
        // Inside the badge the glyph's line box is replaced by the circle, so
        // the alignment below centres the drawn glyph on the badge instead of
        // leaving the extra line height below the baseline. The implicit size
        // stays the glyph's own, so the outlined footprint does not move.
        width: root.container ? root.badgeSize : glyphText.implicitWidth
        height: root.container ? root.badgeSize : glyphText.implicitHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        variant: "icon"
        family: root.resolvedFamily
        icon: root.glyph
        color: root.ink
        font.pixelSize: root.pixelSize
        // Scaling about the glyph's centre keeps its layout box (and so the
        // icon's footprint) untouched while the badge draws around it.
        scale: root.container ? VitrailTokens.icon.scale : 1
    }
}
