import QtQuick
import "../kit"

// The toasts on screen, newest nearest the screen edge the stack hangs
// from. Docked, the frame draws the card around the whole stack; floating,
// each toast is its own island.
Item {
    id: root

    property var queue
    property var strings: ({})
    // Hangs from the bottom edge: the newest toast goes at the bottom.
    property bool atBottom: false
    property bool docked: true

    readonly property int pad: root.docked ? VitrailTokens.gap("sm") : 0

    implicitWidth: 360 + 2 * root.pad
    implicitHeight: list.count > 0 ? list.contentHeight + 2 * root.pad : 0

    ListView {
        id: list

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: list.contentHeight
        interactive: false
        spacing: root.docked ? 0 : VitrailTokens.gap("sm")
        verticalLayoutDirection: root.atBottom ? ListView.BottomToTop : ListView.TopToBottom
        model: root.queue ? root.queue.shown : null

        delegate: NotificationToast {
            required property int index
            required property int nid

            width: list.width
            notification: root.queue.byId[nid] || null
            strings: root.strings
            card: !root.docked
            divider: root.docked && index > 0
            dividerBelow: root.atBottom
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
