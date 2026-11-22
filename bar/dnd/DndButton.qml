import QtQuick
import ".."
import "dnd.js" as Dnd

// The Do Not Disturb element: a moon that fills while notifications are held
// back. A left or middle click turns it on (for the remembered duration) or
// off; a right click opens the popup, where the duration and the applications
// that may still come through are chosen. The state is the notifications
// layer's own (bar.ini `notificationDnd` and `notificationMuteUntil`), so a
// time that runs out turns it off exactly as the bell's one-hour silence does.
BarElementBase {
    id: root

    property bool dndOn: false
    property double muteUntil: 0
    property string apps: ""
    property bool bypass: true
    property double now: Date.now()

    readonly property var state: Dnd.state(root.dndOn, root.muteUntil, root.now)

    signal toggleRequested()
    signal menuRequested()

    showMode: "always"
    active: root.state.on
    icon: root.state.on ? "bedtime" : "dark_mode"
    tone: root.state.on ? "primary" : "secondary"
    tooltip: Dnd.summary(root.dndOn, root.muteUntil, root.now, root.t)
    tooltipDetail: Dnd.detail(root.apps, root.bypass, root.t)

    onClicked: root.toggleRequested()
    onMiddleClicked: root.toggleRequested()
    onRightClicked: root.menuRequested()
}
