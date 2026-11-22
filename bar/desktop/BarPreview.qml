import QtQuick
import QtQuick.Layouts
import ".."
import "../kit"
import "../kit/base"
import "../kit/frame.js" as Frame
import "../layouts.js" as Layouts
import "../elements.js" as Elements

// The bar as it hangs on its edge, at the top of the editor's Bar tab: only
// the strip, nothing behind it. It draws what the bar draws on screen — the
// real element buttons (BarElementBase, with the registry's glyph), a chip as
// the bar's own pill around its members (BarChip), a divider as its hairline
// (BarDivider) — with the document's density and the bar's edge, style
// (docked, floating, islands), radius and opacity. It draws the document the
// editor is about to write, so a drag reorders the strip before the pointer is
// released, and the group (or chip) the drop would land in wears the primary
// tint. An element the document hides is drawn dimmed instead of left out.
// The strip shrinks to fit its box when the elements are longer than it.
Item {
    id: root

    property var doc: null
    property var strings: ({})
    // The drop the drag is heading for ({ kind, group, chip }), if any.
    property var target: null
    // The bar's edge and style (bar.ini `barEdge`, `barStyle`) and opacity.
    property string edge: "left"
    property string variant: ""
    property real opacityLevel: VitrailTokens.opacity

    readonly property var style: VitrailStyle.resolve("bar", root.variant)
    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    readonly property real densityScale: root.doc && VitrailTokens.density[root.doc.density] !== undefined
                                         ? VitrailTokens.density[root.doc.density] : 1
    readonly property int gap: Math.round(VitrailTokens.gap(root.style.gap) * root.densityScale)
    readonly property var layout: Frame.layout(VitrailStyle.resolve("frame", ""), root.style, root.edge, {
        frame: VitrailTokens.frame,
        bar: VitrailTokens.bar,
        gap: root.gap,
        radius: VitrailTokens.radius
    })
    // The strip's distance from the box (0 docked) and its inner padding.
    readonly property real inset: root.layout.bar.margin
    readonly property real pad: root.layout.bar.padding + root.gap
    readonly property real thickness: VitrailTokens.bar
    // The shortest strip that keeps the three groups apart, with the centre
    // group centred as the bar centres it.
    readonly property real naturalLength: 2 * root.pad + 2 * VitrailTokens.gap("lg")
                                          + root.lengthOf(centerSlot)
                                          + 2 * Math.max(root.lengthOf(startSlot), root.lengthOf(endSlot))
    readonly property real available: Math.max(1, (root.vertical ? root.height : root.width) - 2 * root.inset)
    readonly property real fit: Math.min(1, root.available / Math.max(1, root.naturalLength))
    readonly property real stripLength: Math.max(root.naturalLength, root.available / root.fit)
    // Whether any entry is drawn dimmed, for the editor's note.
    readonly property bool anyHidden: Layouts.groups("bar").some(function (group) {
        return root.entries(group).some(function (entry) {
            return entry.chip !== undefined ? entry.ids.some(root.hidden) : root.hidden(entry.id)
        })
    })

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function lengthOf(slot) {
        return root.vertical ? slot.implicitHeight : slot.implicitWidth
    }

    // Every entry of one group, hidden ones included: the strip dims them.
    function entries(group) {
        if (!root.doc || !root.doc.order)
            return []
        return Layouts.entries(root.doc.order[group] || [], [], "bar", root.doc.chips || {})
    }

    function hidden(id) {
        return !!root.doc && (root.doc.hidden || []).indexOf(id) >= 0
    }

    function labelOf(id) {
        var widget = Layouts.find(id, "bar")
        return root.t(widget ? widget.labelKey : id)
    }

    function groupTargeted(group) {
        return root.target !== null && root.target.kind === "group" && root.target.group === group
    }

    function chipTargeted(chip) {
        return root.target !== null && root.target.kind === "chip" && root.target.chip === chip
    }

    implicitWidth: root.vertical ? (root.thickness + 2 * root.inset) * root.fit : 0
    implicitHeight: root.vertical ? 0 : (root.thickness + 2 * root.inset) * root.fit

    // One group's slot: the drop marker behind it, then its entries.
    component Slot: GridLayout {
        id: slot

        // Inline components do not see the file's ids: the preview comes in.
        required property Item preview
        property string group: ""

        objectName: "barPreviewGroup-" + slot.group
        flow: slot.preview.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: slot.preview.gap
        columnSpacing: slot.preview.gap

        // A chip member: the bar's own button for that id (BarChip loads it).
        Component {
            id: memberPart

            BarElementBase {
                readonly property string elementId: parent && parent.modelData !== undefined
                                                    ? parent.modelData : ""

                objectName: "barPreviewElement-" + elementId
                strings: slot.preview.strings
                icon: Elements.icon(elementId)
                tooltip: slot.preview.labelOf(elementId)
                opacity: slot.preview.hidden(elementId) ? VitrailTokens.barPreview.hidden : 1
            }
        }

        Repeater {
            model: slot.preview.entries(slot.group)

            // One face per entry: the bar's button, its chip or its divider.
            delegate: Loader {
                id: cell

                required property var modelData

                Layout.alignment: Qt.AlignCenter
                sourceComponent: cell.modelData.divider === true ? dividerPart
                               : (cell.modelData.chip !== undefined ? chipPart : elementPart)

                Component {
                    id: dividerPart

                    BarDivider {
                        objectName: "barPreviewDivider-" + cell.modelData.id
                        vertical: slot.preview.vertical
                    }
                }

                Component {
                    id: chipPart

                    Item {
                        implicitWidth: chip.implicitWidth
                        implicitHeight: chip.implicitHeight

                        // The chip a drop would land in.
                        VitrailSurface {
                            objectName: "barPreviewChipTarget-" + cell.modelData.chip
                            visible: slot.preview.chipTargeted(cell.modelData.chip)
                            anchors.fill: parent
                            anchors.margins: -VitrailTokens.gap("xs")
                            radius: height / 2
                            tint: VitrailTokens.color("primary")
                            opacityLevel: VitrailTokens.barPreview.target
                        }

                        BarChip {
                            id: chip

                            objectName: "barPreviewChip-" + cell.modelData.chip
                            anchors.fill: parent
                            vertical: slot.preview.vertical
                            ids: cell.modelData.ids
                            componentFor: function (id) { return memberPart }
                        }
                    }
                }

                Component {
                    id: elementPart

                    BarElementBase {
                        objectName: "barPreviewElement-" + cell.modelData.id
                        strings: slot.preview.strings
                        icon: Elements.icon(cell.modelData.id)
                        tooltip: slot.preview.labelOf(cell.modelData.id)
                        opacity: slot.preview.hidden(cell.modelData.id) ? VitrailTokens.barPreview.hidden : 1
                    }
                }
            }
        }
    }

    // The strip at its natural size, scaled down only when the box is short.
    Item {
        id: box

        objectName: "barPreviewStrip"

        readonly property real along: root.stripLength
        readonly property real across: root.thickness

        x: root.inset * root.fit
        y: root.inset * root.fit
        width: root.vertical ? box.across : box.along
        height: root.vertical ? box.along : box.across
        scale: root.fit
        transformOrigin: Item.TopLeft

        // A floating bar is its own rounded island; a docked one is part of
        // the frame (square, flush); an islands bar draws one per group.
        VitrailSurface {
            objectName: "barPreviewSurface"
            anchors.fill: parent
            visible: !root.style.islands
            style: VitrailTokens.surfaceMode
            radius: root.style.docked ? 0 : VitrailTokens.radius
            tint: VitrailTokens.color("surface")
            opacityLevel: root.opacityLevel
        }

        Repeater {
            model: root.style.islands ? [startSlot, centerSlot, endSlot] : []

            delegate: VitrailSurface {
                required property Item modelData

                visible: modelData.implicitWidth > 0 && modelData.implicitHeight > 0
                x: root.vertical ? 0 : modelData.x - root.gap
                y: root.vertical ? modelData.y - root.gap : 0
                width: root.vertical ? box.across : modelData.width + 2 * root.gap
                height: root.vertical ? modelData.height + 2 * root.gap : box.across
                style: VitrailTokens.surfaceMode
                radius: VitrailTokens.radius
                tint: VitrailTokens.color("surface")
                opacityLevel: root.opacityLevel
            }
        }

        // The group a drop would land in.
        Repeater {
            model: [startSlot, centerSlot, endSlot]

            delegate: VitrailSurface {
                required property Item modelData

                objectName: "barPreviewTarget-" + modelData.group
                visible: root.groupTargeted(modelData.group)
                x: root.vertical ? VitrailTokens.gap("xs") : modelData.x - root.gap
                y: root.vertical ? modelData.y - root.gap : VitrailTokens.gap("xs")
                width: root.vertical ? box.across - 2 * VitrailTokens.gap("xs")
                                     : Math.max(modelData.width, VitrailTokens.size("body")) + 2 * root.gap
                height: root.vertical ? Math.max(modelData.height, VitrailTokens.size("body")) + 2 * root.gap
                                      : box.across - 2 * VitrailTokens.gap("xs")
                radius: Math.min(width, height) / 2
                tint: VitrailTokens.color("primary")
                opacityLevel: VitrailTokens.barPreview.target
            }
        }

        Slot {
            id: startSlot

            preview: root
            group: "start"
            x: root.vertical ? (box.across - width) / 2 : root.pad
            y: root.vertical ? root.pad : (box.across - height) / 2
        }

        Slot {
            id: centerSlot

            preview: root
            group: "center"
            x: root.vertical ? (box.across - width) / 2 : (box.along - width) / 2
            y: root.vertical ? (box.along - height) / 2 : (box.across - height) / 2
        }

        Slot {
            id: endSlot

            preview: root
            group: "end"
            x: root.vertical ? (box.across - width) / 2 : box.along - width - root.pad
            y: root.vertical ? box.along - height - root.pad : (box.across - height) / 2
        }
    }
}
