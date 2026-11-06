import QtQuick
import ".."

// Text primitive: size, weight and color come from the `text` variant.
//
// `icon` draws a Material Symbol ligature instead of text; it is the glyph
// renderer VitrailIcon wraps in its container badge. The glyph is never
// filled: the FILL axis stays 0, and a container icon is a shape drawn by
// VitrailIcon, not a Material Symbols fill. An active/selected icon still
// changes only its colour, never the axis.
Text {
    id: root

    property string variant: ""
    // A family from outside the kit (the Fonts page's preview and a widget's
    // own typography; "" keeps the shell's font).
    property string family: ""
    // "" keeps the variant's weight; regular, medium and bold override it.
    property string fontWeight: ""
    property bool italic: false
    // An icon ligature name. It goes through the resolver, so a name the table
    // does not know draws `question_mark` instead of the word itself; an empty
    // value is "no icon" and draws nothing.
    property string icon: ""

    readonly property var style: VitrailStyle.resolve("text", root.variant)
    // Icons follow the shell's chosen Material Symbols family, text the
    // system's: one binding each, so a preference change repaints at once.
    readonly property string resolvedFamily: root.family !== ""
                                             ? root.family
                                             : (root.style.family === "icons"
                                                ? VitrailTokens.iconFamily
                                                : VitrailTokens.fontFamily)

    text: root.icon !== "" ? VitrailIcons.resolve(root.icon) : ""
    color: VitrailTokens.color(root.style.role)
    opacity: root.style.opacity
    font.pixelSize: VitrailTokens.size(root.style.size)
    font.family: root.resolvedFamily
    font.variableAxes: root.style.family === "icons" ? ({ "FILL": 0 }) : ({})
    font.weight: root.fontWeight === "bold" ? Font.Bold
                 : root.fontWeight === "medium" ? Font.Medium
                 : root.fontWeight === "regular" ? Font.Normal
                 : root.style.weight
    font.italic: root.italic
}
