import QtQuick
import ".."

// Text primitive: size, weight and color come from the `text` variant.
// Icons take the user's FILL style (outline or container); an active/selected
// icon still changes only its colour, never the axis.
Text {
    id: root

    property string variant: ""
    // A family from outside the kit (the Fonts page's preview).
    property string family: ""
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
    font.variableAxes: root.style.family === "icons" ? ({ "FILL": VitrailTokens.iconFill }) : ({})
    font.weight: root.style.weight
}
