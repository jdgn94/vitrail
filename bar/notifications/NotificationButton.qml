import QtQuick
import "../kit"
import "../kit/base"

// The bell next to the launcher: a left click opens (or closes) this
// monitor's notification centre; a right click silences everything for an
// hour, and turns the silence off again if it was already on.
VitrailButton {
    id: root

    property var strings: ({})
    // The panel is open on this monitor, and Do Not Disturb is on.
    property bool opened: false
    property bool muted: false
    // What the centre holds, for the tooltip.
    property int count: 0

    signal mutedRequested()

    // What the pointer reads: the bell, the state, and what each click does.
    property string tooltip: root.t("tooltip.notifications")
    property string tooltipDetail: root.muted ? root.t("tooltip.notificationsMuted")
        : root.count > 0 ? root.t("tooltip.notificationsCount").replace("%1", root.count)
        : root.t("tooltip.notificationsHint")

    variant: root.opened || root.muted ? "tonal" : "plain"
    tone: root.muted ? "secondary" : (root.opened ? "primary" : "secondary")
    icon: root.muted ? "notifications_off" : "notifications"

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The button's own area takes the left click; this one only the right.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.mutedRequested()
    }
}
