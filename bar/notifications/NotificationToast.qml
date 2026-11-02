import QtQuick
import "../kit"
import "progress.js" as Progress

// One incoming notification: the shared card, a sideways flick that marks it
// read, and the five second expiry (paused while the pointer rests on it).
// A live task (a download) stays on screen until it ends.
Item {
    id: root

    property var notification: null
    property var queue: null
    property var strings: ({})
    // What a button asks the shell to do, and the settings' switches.
    property var act: null
    property bool snoozeEnabled: true
    property string mutedApps: ""
    property real arrived: 0
    property real now: Date.now()
    property bool newest: false

    implicitHeight: card.implicitHeight
    // The stack lays the cards out by this height; a change of content (the
    // actions, the progress bar) must move the ones below.
    height: implicitHeight

    NotificationCard {
        id: card

        width: parent.width
        height: parent.height
        notification: root.notification
        strings: root.strings
        act: root.act
        snoozeEnabled: root.snoozeEnabled
        mutedApps: root.mutedApps
        arrived: root.arrived
        now: root.now
        newest: root.newest
        opacity: 1 - Math.min(1, Math.abs(card.x) / root.width)

        Behavior on x {
            enabled: !swipe.active
            NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
        }

        // A sideways flick past a third of the width marks it read.
        DragHandler {
            id: swipe

            target: card
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    return
                if (Math.abs(card.x) > root.width / 3) {
                    card.x = card.x > 0 ? root.width : -root.width
                    dismissal.start()
                } else {
                    card.x = 0
                }
            }
        }

        Timer {
            id: dismissal

            interval: VitrailTokens.duration("base")
            onTriggered: if (root.notification) root.notification.dismiss()
        }
    }

    // Restarts from zero whenever the pointer leaves or the reply closes.
    Timer {
        interval: 5000
        running: root.notification !== null && !card.held && !Progress.live(root.notification)
        onTriggered: if (root.notification && root.queue) root.queue.expire(root.notification.id)
    }
}
