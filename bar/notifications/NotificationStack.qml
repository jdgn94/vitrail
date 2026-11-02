import QtQuick
import "../kit"

// The cards on screen, newest nearest the screen edge the stack hangs
// from. The container behind them (a tab of the frame when the bar is
// docked, an island when it floats) belongs to the shell.
Item {
    id: root

    property var queue
    property var strings: ({})
    // What a button asks the shell to do, and the settings' switches.
    property var act: null
    property bool snoozeEnabled: true
    property string mutedApps: ""
    // Hangs from the bottom edge: the newest card goes at the bottom.
    property bool atBottom: false
    // Ticks so every card's "5 min" stays true.
    property real now: Date.now()

    readonly property int pad: VitrailTokens.gap("sm")

    implicitWidth: 380 + 2 * root.pad
    implicitHeight: list.count > 0 ? list.contentHeight + 2 * root.pad : 0

    Timer {
        interval: 30000
        running: list.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    ListView {
        id: list

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: list.contentHeight
        interactive: false
        spacing: root.pad
        verticalLayoutDirection: root.atBottom ? ListView.BottomToTop : ListView.TopToBottom
        model: root.queue ? root.queue.shown : null

        delegate: NotificationToast {
            required property int index
            required property int nid

            width: list.width
            height: implicitHeight
            notification: root.queue.byId[nid] || null
            queue: root.queue
            arrived: root.queue.arrived[nid] || Date.now()
            now: root.now
            newest: index === 0
            strings: root.strings
            act: root.act
            snoozeEnabled: root.snoozeEnabled
            mutedApps: root.mutedApps
            // Fades in on its own: an add transition cut short by the next
            // arrival would leave it half transparent.
            opacity: 0
            Component.onCompleted: opacity = 1

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
        }
    }
}
