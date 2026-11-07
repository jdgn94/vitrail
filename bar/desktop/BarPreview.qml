import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../layouts.js" as Layouts

// The live preview of the bar at the top of the Bar tab: the start, center and
// end zones, every element as a pill, a chip as one pill around its members
// and a divider as its hairline. It draws the document the editor is about to
// write, so a drag reorders the strip before the pointer is released; the zone
// (or the chip) a drop would land in is marked with the primary tint.
Item {
    id: root

    property var doc: null
    property var strings: ({})
    // The drop the drag is heading for ({ kind, group, chip }), if any.
    property var target: null
    property var iconOf: function (id) { return "widgets" }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The visible entries of one group, as the bar would draw them.
    function entries(group) {
        if (!root.doc)
            return []
        return Layouts.entries(root.doc.order ? root.doc.order[group] : [],
                                root.doc.hidden || [], "bar", root.doc.chips || {})
    }

    implicitHeight: zones.implicitHeight

    RowLayout {
        id: zones

        width: parent.width
        spacing: VitrailTokens.gap("sm")

        Repeater {
            model: Layouts.groups("bar")

            delegate: VitrailSurface {
                id: zone

                required property string modelData

                readonly property bool highlighted: root.target !== null
                                                    && root.target.kind === "group"
                                                    && root.target.group === zone.modelData

                Layout.fillWidth: true
                Layout.preferredHeight: body.implicitHeight + 2 * VitrailTokens.gap("xs")
                radius: VitrailTokens.radius * 0.7
                tint: zone.highlighted ? VitrailTokens.color("primary", "#a8c7fa")
                                       : VitrailTokens.color("surface", "#1d2024")
                opacityLevel: zone.highlighted ? VitrailTokens.opacity * 0.39
                                               : VitrailTokens.opacity * 0.23

                ColumnLayout {
                    id: body

                    anchors.fill: parent
                    anchors.margins: VitrailTokens.gap("xs")
                    spacing: VitrailTokens.gap("xs")

                    VitrailText {
                        variant: "label"
                        text: root.t("bar.editor.group." + zone.modelData)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: VitrailTokens.gap("xs")
                        clip: true

                        Repeater {
                            model: root.entries(zone.modelData)

                            delegate: BarPreviewEntry {
                                required property var modelData

                                entry: modelData
                                iconOf: root.iconOf
                                highlighted: root.target !== null
                                             && (root.target.kind === "chip"
                                                 ? root.target.chip === modelData.chip
                                                 : (root.target.kind === "group"
                                                    && root.target.group === zone.modelData))
                            }
                        }
                    }
                }
            }
        }
    }
}
