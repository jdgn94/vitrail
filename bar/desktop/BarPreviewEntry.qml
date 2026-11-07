import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// One entry of the bar preview: an element as a pill, a chip as one wider pill
// around its members and a divider as the hairline the bar draws. The preview
// is a schematic, so an element shows its icon; the card below names it.
Item {
    id: root

    // One entry of Layouts.entries: { id }, { chip, ids } or { divider: true }.
    property var entry: null
    property bool highlighted: false
    // The bar's own icon and label lookups, handed down by the editor.
    property var iconOf: function (id) { return "widgets" }

    readonly property bool divider: root.entry !== null && root.entry.divider === true
    readonly property bool chip: root.entry !== null && root.entry.chip !== undefined
    readonly property var ids: {
        if (!root.entry)
            return []
        if (root.entry.chip !== undefined)
            return root.entry.ids || []
        return root.entry.id !== undefined ? [root.entry.id] : []
    }

    implicitWidth: root.divider ? VitrailTokens.gap("xs") : pill.implicitWidth
    implicitHeight: root.divider ? VitrailTokens.size("body") : pill.implicitHeight

    VitrailSurface {
        id: line

        visible: root.divider
        anchors.centerIn: parent
        width: 1
        height: root.implicitHeight
        radius: 0
        tint: VitrailTokens.color("muted", "#c4c6d0")
        opacityLevel: VitrailTokens.opacity * 0.61
    }

    VitrailSurface {
        id: pill

        visible: !root.divider
        width: implicitWidth
        height: implicitHeight
        implicitWidth: icons.implicitWidth + 2 * VitrailTokens.gap("xs")
        implicitHeight: icons.implicitHeight + 2 * VitrailTokens.gap("xs")
        radius: height / 2
        tint: root.chip ? VitrailTokens.color("primary", "#a8c7fa")
                        : VitrailTokens.color("surfaceHigh", "#282a2f")
        opacityLevel: root.highlighted ? VitrailTokens.opacity * 0.61
                                       : (root.chip ? VitrailTokens.opacity * 0.39
                                                    : VitrailTokens.opacity * 0.23)

        RowLayout {
            id: icons

            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: root.ids

                delegate: VitrailIcon {
                    required property string modelData

                    icon: root.iconOf(modelData)
                    size: "sm"
                    color: root.chip ? VitrailTokens.color("primary", "#a8c7fa")
                                     : VitrailTokens.color("foreground", "#e2e2e9")
                }
            }
        }
    }
}
