import QtQuick
import "../kit"
import "../kit/base"

// A button of the editor with its tooltip: icon, optional label, filled while
// `highlighted` (the chosen tool, a toggle that is on). The tooltip names it and
// carries the key; a disabled one fades and still says why through the
// tooltip (so not `enabled`: a disabled item gets no hover).
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string tooltip: ""
    property string tooltipDetail: ""
    property bool highlighted: false
    property bool available: true
    property string disabledWhy: ""
    property bool busy: false
    // The emphasis when not highlighted: text (quiet), outlined or flat.
    property string variant: "text"
    property string tone: "secondary"
    property string size: "sm"
    // Where the tooltip sits, always above the button: centred, or flush with
    // its start / end edge (a button near the window's edge, whose tooltip
    // would be cut).
    property string align: "center"

    signal clicked()

    readonly property bool hovered: hover.hovered

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    HoverHandler {
        id: hover
    }

    VitrailButton {
        id: button

        anchors.fill: parent
        enabled: root.available
        busy: root.busy
        variant: root.highlighted ? "flat" : root.variant
        tone: root.highlighted ? "primary" : root.tone
        size: root.size
        icon: root.icon
        text: root.text
        onClicked: root.clicked()
    }

    VitrailTooltip {
        text: root.tooltip
        detail: root.available ? root.tooltipDetail : root.disabledWhy
        active: root.hovered
        edge: "bottom"
        x: root.align === "start" ? 0 : root.align === "end" ? root.width - width : (root.width - width) / 2
        y: -height - VitrailTokens.gap("xs")
    }
}
