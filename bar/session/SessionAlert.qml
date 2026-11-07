import QtQuick
import "actions.js" as Session

// The alert surface: the dimmed backdrop (drawn by SessionConfirm) and the
// question card, with no window of its own so it can be driven and tested as
// a plain item. AlertLayer puts one on a full-screen overlay per monitor.
//
// It knows nothing about the session menu or the bar popup: `shown` comes from
// the pending action alone (Session.alertVisible), so a confirmation opened
// from the menu and one opened from the popout are the same alert.
Item {
    id: root

    property var strings: ({})
    // An action waits for an answer (problem or countdown; never the check).
    property bool shown: false
    property string action: ""
    property string phase: "countdown"
    property var jobs: []
    property int remaining: 0
    property int total: Session.SECONDS

    signal cancelled()
    signal confirmed()

    visible: root.shown

    onShownChanged: if (root.shown) Qt.callLater(confirm.forceActiveFocus)

    SessionConfirm {
        id: confirm

        anchors.fill: parent
        allowed: root.shown
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
