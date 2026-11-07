import QtQuick
import Quickshell
import Quickshell.Wayland
import "actions.js" as Session

// The session alert: a window of its own per monitor, above every application
// and above the session menu, so a confirmation or an alert is seen whether
// the menu was opened full screen or the popout was used.
//
// It is independent of `sessionOpen`, the popup and the menu window: `shown`
// comes from the pending action alone, and while it is hidden the window is
// unmapped and takes no keyboard focus. While shown it covers the screen and
// holds the keyboard exclusively, so Escape cancels and Enter confirms.
//
// The namespace is the session one on purpose: the compositor's glass rule
// (dots/.config/hypr/hyprland.lua and scripts/apply-settings.sh) lists the
// namespaces it blurs, and a new `vitrail-alert` entry would mean editing
// that list. The alert is a session surface like the menu; the blur is the
// same. See README "Login and lock" for the lock-screen limit: hyprlock is an
// external ext-session-lock client, so no layer-shell surface (this one
// included) can draw over it.
PanelWindow {
    id: root

    // The monitor this layer belongs to (the shell repeats one per screen).
    required property var screen

    property bool shown: false
    property var strings: ({})
    property string action: ""
    property string phase: "countdown"
    property var jobs: []
    property int remaining: 0
    property int total: Session.SECONDS

    signal cancelled()
    signal confirmed()

    // Idle, the surface is unmapped: it can never swallow a click, and the
    // layer under it (the menu, the popup, an app) keeps its focus.
    visible: root.shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // A full-screen mask while shown: the card is the only thing to reach.
    mask: Region {
        item: root.shown ? alert : null
    }

    SessionAlert {
        id: alert

        anchors.fill: parent
        shown: root.shown
        strings: root.strings
        action: root.action
        phase: root.phase
        jobs: root.jobs
        remaining: root.remaining
        total: root.total
        onCancelled: root.cancelled()
        onConfirmed: root.confirmed()
    }
}
