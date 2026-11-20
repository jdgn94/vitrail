import Quickshell
import Quickshell.Wayland
import QtQuick
import "../kit"
import "capture.js" as Capture

// One pinned area as its own layer surface: it is the size of the pin, sits
// where the area was on the monitor it came from, stays above the windows, and
// takes the keyboard only while it is clicked (Escape closes it), never for
// good. Moving and zooming change its margins and size; the layer around it
// does not exist, so the rest of the screen is untouched.
PanelWindow {
    id: root

    required property string image
    required property real startX
    required property real startY
    required property real baseWidth
    required property real baseHeight
    required property real startZoom
    // The monitor's name; "" or unknown: the default output.
    required property string output

    property var t: function (key) {
        return key
    }
    property real left: root.startX
    property real top: root.startY
    property real zoom: root.startZoom
    property real level: 1

    // (not `closed`: the window has a signal of that name)
    signal dismissed()

    function screenNamed(name) {
        var all = Quickshell.screens
        for (var index = 0; index < all.length; index++) {
            if (all[index].name === name)
                return all[index]
        }
        return null
    }

    screen: root.screenNamed(root.output)
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(root.left)
        top: Math.round(root.top)
    }
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-pin"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    PinCard {
        id: card

        anchors.fill: parent
        t: root.t
        image: root.image
        baseWidth: root.baseWidth
        baseHeight: root.baseHeight
        zoom: root.zoom
        level: root.level
        onDragged: function (dx, dy) {
            root.left += dx
            root.top += dy
        }
        onZoomed: function (factor, anchor) {
            var next = Capture.pinZoom({ x: root.left, y: root.top, zoom: root.zoom }, factor,
                                       { x: root.left + anchor.x, y: root.top + anchor.y },
                                       VitrailTokens.capture.pin.zoomMin, VitrailTokens.capture.pin.zoomMax)
            root.left = next.x
            root.top = next.y
            root.zoom = next.zoom
        }
        onFaded: function (delta) {
            root.level = Capture.pinOpacity(root.level, delta, VitrailTokens.capture.pin.opacityMin)
        }
        onLevelSet: function (level) { root.level = level }
        onClosed: root.dismissed()
    }
}
