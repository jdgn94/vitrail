import QtQuick
import ".."

// Text primitive: size, weight and color come from the `text` variant.
// Icons are never filled: the active state is the colour, not the FILL axis.
Text {
    id: root

    property string variant: ""
    // A family from outside the kit (the Fonts page's preview).
    property string family: ""

    readonly property var style: VitrailStyle.resolve("text", root.variant)
    // Icons follow the shell's chosen Material Symbols family, text the
    // system's: one binding each, so a preference change repaints at once.
    readonly property string resolvedFamily: root.family !== ""
                                             ? root.family
                                             : (root.style.family === "icons"
                                                ? VitrailTokens.iconFamily
                                                : VitrailTokens.fontFamily)

    color: VitrailTokens.color(root.style.role)
    opacity: root.style.opacity
    font.pixelSize: VitrailTokens.size(root.style.size)
    font.family: root.resolvedFamily
    font.weight: root.style.weight
}
