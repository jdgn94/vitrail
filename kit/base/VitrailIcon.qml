import QtQuick
import ".."

// Icon primitive: one Material Symbol, always outlined.
//
// `icon` is the ligature name and is validated by tests/test_icons.py, so a
// typo fails the suite instead of rendering a word. `size` follows the text
// scale (sm/md/lg/xl), and `pixelSize` overrides it when a component has its
// own sizing table. An active icon is the accent colour, never a fill.
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

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    VitrailText {
        id: glyph

        variant: "icon"
        text: root.icon
        color: root.color
        font.pixelSize: root.pixelSize
    }
}
