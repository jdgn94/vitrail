import Quickshell
import Quickshell.Wayland
import QtQuick

// The launch droplet of one monitor: an overlay layer that takes no input at
// all (an empty mask, no keyboard focus), above the launcher and the popups.
// It exists only while a request names this monitor; the shell clears the
// request once the drop has faded.
PanelWindow {
    id: root

    required property var screen
    property var request: null

    readonly property bool shown: root.request !== null && root.request.screen === root.screen.name

    visible: root.shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // The shell's glass rule covers this namespace; the drop draws no surface.
    WlrLayershell.namespace: "vitrail-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    LaunchDroplet {
        anchors.fill: parent
        request: root.request
        screen: root.screen.name
    }
}
