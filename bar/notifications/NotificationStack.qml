import QtQuick
import "../kit"

// The cards on screen, newest nearest the screen edge the stack hangs
// from. The container behind them (a tab of the frame when the bar is
// docked, an island when it floats) belongs to the shell.
//
// Every card sits where the heights of the ones before it say, one below the
// other with `pad` between: its y is computed from the heights the cards
// report, never left to a view's cached positions (a ListView's `displaced`
// transition, cut short by the next arrival while a card changed height,
// stranded cards on top of each other). A card only glides to its place.
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
    // nid -> height of that card, as it reports it.
    property var heights: ({})
    readonly property int count: root.queue ? root.queue.shown.count : 0
    readonly property real contentHeight: root.stackHeight(root.heights)

    implicitWidth: 380 + 2 * root.pad
    implicitHeight: root.count > 0 ? root.contentHeight + 2 * root.pad : 0

    // Height of the cards, with `pad` between them.
    function stackHeight(known) {
        var rows = root.queue.shown
        var total = 0
        for (var i = 0; i < rows.count; i++)
            total += (known[rows.get(i).nid] || 0) + (i > 0 ? root.pad : 0)
        return total
    }

    // Where card `index` (of height `own`) starts, counted from the stack's
    // top: the newest is the first from the edge it hangs from.
    function place(index, own, known) {
        var rows = root.queue.shown
        var before = 0
        for (var i = 0; i < index && i < rows.count; i++)
            before += (known[rows.get(i).nid] || 0) + root.pad
        return root.atBottom ? root.stackHeight(known) - before - own : before
    }

    function report(nid, height) {
        if (root.heights[nid] === height)
            return
        var copy = Object.assign({}, root.heights)
        copy[nid] = height
        root.heights = copy
    }

    function forget(nid) {
        var copy = Object.assign({}, root.heights)
        delete copy[nid]
        root.heights = copy
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Repeater {
        model: root.queue ? root.queue.shown : null

        onItemRemoved: function (index, item) { root.forget(item.nid) }

        delegate: NotificationToast {
            id: toast

            required property int index
            required property int nid
            // Only a card that is already placed glides; a new one starts in its slot.
            property bool placed: false

            x: root.pad
            y: root.pad + root.place(toast.index, toast.height, root.heights)
            width: root.width - 2 * root.pad
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
            onHeightChanged: root.report(toast.nid, toast.height)
            Component.onCompleted: {
                root.report(toast.nid, toast.height)
                toast.placed = true
                toast.opacity = 1
            }

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on y {
                enabled: toast.placed
                NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
            }
        }
    }
}
