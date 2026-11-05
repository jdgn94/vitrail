import QtQuick
import "../kit"
import "../kit/base"
import "tooltip.js" as Tooltip

// The bell next to the launcher: a left click opens (or closes) this
// monitor's notification centre; a right click silences everything for an
// hour, and turns the silence off again if it was already on. A badge counts
// what the centre holds, and the tooltip says *why* it is quiet and for how
// long (see tooltip.js for the rule).
VitrailButton {
    id: root

    property var strings: ({})
    // The panel is open on this monitor, and Do Not Disturb is on.
    property bool opened: false
    property bool muted: false
    // When a timed silence ends (epoch ms, as the preference holds it): 0 when
    // there is none.
    property string muteUntil: "0"
    // What the centre holds, for the badge and the tooltip.
    property int count: 0
    // Re-read while a silence runs, so "X min left" keeps up with the clock.
    property double now: Date.now()

    signal mutedRequested()

    readonly property var tip: Tooltip.describe(
        { notificationDnd: root.muted, notificationMuteUntil: root.muteUntil },
        root.now, root.strings, root.count)

    // What the pointer reads: the bell, the state, and what each click does.
    property string tooltip: root.tip.title
    property string tooltipDetail: root.tip.text

    variant: root.opened || root.tip.muted ? "tonal" : "plain"
    tone: root.tip.muted ? "secondary" : (root.opened ? "primary" : "secondary")
    icon: root.tip.muted ? "notifications_off" : "notifications"

    // The button's own area takes the left click; this one only the right.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.mutedRequested()
    }

    // Never wider than the bell: past nine, the count reads "9+".
    VitrailBadge {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: VitrailTokens.gap("xs")
        text: Tooltip.badge(root.count)
    }

    Timer {
        interval: VitrailTokens.duration("minute")
        running: root.tip.kind === "until"
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
