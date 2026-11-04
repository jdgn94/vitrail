import QtQuick
import ".."

// Text primitive: size, weight and color come from the `text` variant.
Text {
    id: root

    property string variant: ""
    // Icons only: the filled Material Symbol instead of the outlined one.
    property bool filled: false
    // A family from outside the kit (the Fonts page's preview).
    property string family: ""

    readonly property var style: VitrailStyle.resolve("text", root.variant)

    color: VitrailTokens.color(root.style.role)
    opacity: root.style.opacity
    font.pixelSize: VitrailTokens.size(root.style.size)
    font.family: root.family !== "" ? root.family
                                    : (root.style.family === "icons" ? VitrailTokens.iconFamily
                                                                     : VitrailTokens.fontFamily)
    font.variableAxes: root.style.family === "icons" ? ({ "FILL": root.filled ? 1 : 0 }) : ({})
    font.weight: root.style.weight
}
