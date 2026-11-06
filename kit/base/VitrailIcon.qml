import QtQuick
import ".."

// Icon primitive: one Material Symbol, resolved by `VitrailIcons`.
//
// `icon` is the ligature name: it goes through the resolver, which draws
// `question_mark` for a name the table does not know (empty means "no icon").
// `size` follows the text scale (sm/md/lg/xl), and `pixelSize` overrides it
// when a component has its own sizing table. An active icon is the accent
// colour, never a fill.
Item {
    id: root

    property string icon: ""
    property string size: "md"
    // Colour role from the palette, or an explicit colour.
    property string tone: "foreground"
    property color color: VitrailTokens.color(root.tone, VitrailTokens.color("foreground"))

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

    implicitWidth: glyphText.implicitWidth
    implicitHeight: glyphText.implicitHeight

    VitrailText {
        id: glyphText

        variant: "icon"
        icon: root.glyph
        color: root.color
        font.pixelSize: root.pixelSize
    }
}
