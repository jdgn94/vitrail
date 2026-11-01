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
    // A popup, the launcher or the session menu is open: no tooltip at all.
    property bool popupOpen: false
    // Clicked, or something opened or closed, since the pointer entered: the
    // tooltip stays quiet until the pointer leaves and comes back.
    property bool dismissed: false

    onPopupOpenChanged: {
        if (root.target !== null)
            root.dismissed = true
    }

    function hover(item, on) {
        if (on)
            root.target = item
        else if (root.target === item)
            root.target = null
    }

    // The bar window and this one are full-screen layers on the same screen,
    // so the target's scene rect is also its rect here. The bounding rect
    // (not the mapped corner) keeps rotated targets, like the tray chevron,
    // right.
    function place() {
        if (!root.target)
            return
        var rect = root.target.mapToItem(null, Qt.rect(0, 0, root.target.width, root.target.height))
        var at = Frame.tooltipAt(root.edge, rect, tip.width, tip.height, root.offset,
                                 VitrailTokens.gap("sm"), root.width, root.height)
        tip.x = at.x
        tip.y = at.y
    }

    // The window is sized by the compositor once it shows.
    onWidthChanged: root.place()
    onHeightChanged: root.place()

    onTargetChanged: {
        root.dismissed = false
        root.place()
    }

    // Not tip.visible: that is false while this window is hidden, so the
    // window would never show.
    visible: tip.opacity > 0
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

    // The element moved or resized (layouts settle after the hover starts).
    Connections {
        function onXChanged() { root.place() }
        function onYChanged() { root.place() }
        function onWidthChanged() { root.place() }
        function onHeightChanged() { root.place() }

        target: root.target
    }

    // A click that opens nothing (a toggle, an action) hides it too. Not every
    // element has `clicked`.
    Connections {
        function onClicked() { root.dismissed = true }

        target: root.target
        ignoreUnknownSignals: true
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

        active: root.target !== null && !root.dismissed && !root.popupOpen
        edge: root.edge
        opacityLevel: root.opacityLevel
        onWidthChanged: root.place()
        onHeightChanged: root.place()
        onShownChanged: if (tip.shown) root.place()

        // Moving to the next element glides; the first appearance does not.
        Behavior on x { enabled: tip.shown; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        Behavior on y { enabled: tip.shown; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
    }
}
