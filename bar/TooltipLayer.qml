import Quickshell
import Quickshell.Wayland
import QtQuick
import "kit"
import "kit/base"
import "kit/frame.js" as Frame

// The one tooltip host of a monitor. A bar element reports the pointer
// entering or leaving through hover(); the host reads the element's live
// `tooltip` and `tooltipDetail` and shows them in a VitrailTooltip a gap past
// the bar. The window takes no input (empty mask) and stays up only while
// the pill is visible.
PanelWindow {
    id: root

    // The element under the pointer, or null.
    property Item target: null
    // The bar's edge, and how far its inner face is from it.
    property string edge: "top"
    property real offset: 0
    property real opacityLevel: VitrailTokens.opacity
    // Pressed since the pointer entered: it stays quiet until it leaves.
    property bool dismissed: false

    // The element's popout is open: the card says it all.
    readonly property bool suppressed: root.target !== null && root.target.opened === true

    function hover(item, on) {
        if (on)
            root.target = item
        else if (root.target === item)
            root.target = null
    }

    function place() {
        if (!root.target)
            return
        var corner = root.target.mapToItem(null, 0, 0)
        var at = Frame.tooltipAt(root.edge, Qt.rect(corner.x, corner.y, root.target.width, root.target.height),
                                 tip.width, tip.height, root.offset, VitrailTokens.gap("sm"),
                                 root.width, root.height)
        tip.x = at.x
        tip.y = at.y
    }

    onTargetChanged: {
        root.dismissed = false
        root.place()
    }

    visible: tip.visible
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-tooltip"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    // Pressing the element hides its tooltip.
    Connections {
        function onPressedChanged() {
            if (root.target.pressed)
                root.dismissed = true
        }

        target: root.target
    }

    // The text stays while the pill fades out.
    Binding {
        target: tip
        property: "text"
        value: root.target ? root.target.tooltip : ""
        when: root.target !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: tip
        property: "detail"
        value: root.target ? root.target.tooltipDetail || "" : ""
        when: root.target !== null
        restoreMode: Binding.RestoreNone
    }

    VitrailTooltip {
        id: tip

        active: root.target !== null && !root.dismissed && !root.suppressed
        edge: root.edge
        opacityLevel: root.opacityLevel
        onWidthChanged: root.place()
        onHeightChanged: root.place()

        // Moving to the next element glides; the first appearance does not.
        Behavior on x { enabled: tip.shown; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        Behavior on y { enabled: tip.shown; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
    }
}
