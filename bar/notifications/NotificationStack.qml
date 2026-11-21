import QtQuick
import "../kit"
import "notifications.js" as Notifications

// The cards on screen, newest nearest the screen edge the stack hangs
// from. The container behind them (a tab of the frame when the bar is
// docked, an island when it floats) belongs to the shell.
//
// Every card sits in a slot, and the slots sit one below the other with `pad`
// between: a slot's y comes from the heights the slots report, never from a
// view's cached positions (a ListView's `displaced` transition, cut short by
// the next arrival while a card changed height, stranded cards on top of each
// other). The slot is the container: its height grows from 0 when a toast
// arrives and shrinks to 0 when it leaves, with the card already inside,
// whole and opaque, clipped by the slot and sliding in or out towards the edge
// the stack hangs from; the slots after it follow that height in the same
// motion. A leaving card (it expired, the X, dismissed) stays in `rows` until
// its slot is gone, showing a snapshot of the notification.
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
    // One row per card on screen, leaving ones included, newest first:
    // { nid, key, leaving }. `key` never repeats, `nid` is the notification's.
    property ListModel rows: ListModel {}
    property int lastKey: 0
    // The first card that is not leaving: the one that opens expanded.
    property int newestKey: -1
    // key -> { h, p }: the slot's height and how present it is, 0..1 (its gap
    // goes with it).
    property var metrics: ({})
    readonly property int count: root.rows.count
    readonly property real presence: root.presenceOf(root.metrics)
    // The padding around the cards goes with them when the last one leaves.
    readonly property real inset: root.pad * Math.min(1, root.presence)
    readonly property real contentHeight: root.stackHeight(root.metrics)

    implicitWidth: 380 + 2 * root.pad
    implicitHeight: root.presence > 0.001 ? root.contentHeight + 2 * root.inset : 0

    function presenceOf(known) {
        var total = 0
        for (var i = 0; i < root.rows.count; i++) {
            var slot = known[root.rows.get(i).key]
            total += slot ? slot.p : 0
        }
        return total
    }

    // The slots' heights, and one gap fewer than slots (as present as they are).
    function stackHeight(known) {
        var total = 0
        for (var i = 0; i < root.rows.count; i++) {
            var slot = known[root.rows.get(i).key]
            total += slot ? slot.h : 0
        }
        return total + root.pad * Math.max(0, root.presenceOf(known) - 1)
    }

    // Where slot `index` (of height `own`) starts, counted from the stack's
    // top: the slots before it, each with its gap.
    function place(index, own, known) {
        var before = 0
        for (var i = 0; i < index && i < root.rows.count; i++) {
            var slot = known[root.rows.get(i).key]
            before += slot ? slot.h + root.pad * slot.p : 0
        }
        return root.atBottom ? root.stackHeight(known) - before - own : before
    }

    function report(key, height, presence) {
        var seen = root.metrics[key]
        if (seen && seen.h === height && seen.p === presence)
            return
        var copy = Object.assign({}, root.metrics)
        copy[key] = { h: height, p: presence }
        root.metrics = copy
    }

    // Matches `rows` to the queue: a card the queue dropped starts leaving, a
    // new one is put in front.
    function sync() {
        if (!root.queue)
            return
        var shown = root.queue.shown
        var live = {}
        var have = {}
        for (var i = 0; i < shown.count; i++)
            live[shown.get(i).nid] = true
        for (var j = 0; j < root.rows.count; j++) {
            var row = root.rows.get(j)
            if (row.leaving)
                continue
            have[row.nid] = true
            if (!live[row.nid])
                root.rows.setProperty(j, "leaving", true)
        }
        for (var k = shown.count - 1; k >= 0; k--) {
            var nid = shown.get(k).nid
            if (!have[nid]) {
                root.lastKey += 1
                root.rows.insert(0, { nid: nid, key: root.lastKey, leaving: false })
            }
        }
        root.newestKey = -1
        for (var m = 0; m < root.rows.count; m++) {
            if (!root.rows.get(m).leaving) {
                root.newestKey = root.rows.get(m).key
                break
            }
        }
    }

    // Its slot has closed.
    function finish(key) {
        for (var i = 0; i < root.rows.count; i++) {
            if (root.rows.get(i).key === key) {
                root.rows.remove(i)
                break
            }
        }
        var copy = Object.assign({}, root.metrics)
        delete copy[key]
        root.metrics = copy
    }

    onQueueChanged: root.sync()
    Component.onCompleted: root.sync()

    Connections {
        target: root.queue ? root.queue.shown : null

        function onCountChanged() {
            root.sync()
        }
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Repeater {
        model: root.rows

        delegate: Item {
            id: slot

            objectName: "slot"

            required property int index
            required property int nid
            required property int key
            required property bool leaving

            readonly property var live: root.queue.byId[slot.nid] || null
            // What the card shows once the notification is gone.
            property var frozen: null
            // Opens on the next frame: a new slot starts at 0 and grows.
            property bool entered: false
            // It has reached its height once; until then (and while leaving)
            // the card slides with the slot's moving side.
            property bool settled: false
            readonly property bool open: slot.entered && !slot.leaving
            readonly property real full: toast.implicitHeight
            property real presence: slot.open ? 1 : 0

            x: root.pad
            y: root.inset + root.place(slot.index, slot.height, root.metrics)
            width: root.width - 2 * root.pad
            height: slot.open ? slot.full : 0
            clip: true

            onHeightChanged: {
                root.report(slot.key, slot.height, slot.presence)
                if (slot.open && slot.full > 1 && slot.height >= slot.full - 0.5)
                    slot.settled = true
                if (slot.leaving && slot.height < 0.5)
                    Qt.callLater(root.finish, slot.key)
            }
            onPresenceChanged: root.report(slot.key, slot.height, slot.presence)
            onLeavingChanged: {
                if (!slot.leaving)
                    return
                slot.frozen = Notifications.snapshot(slot.live)
                if (slot.height < 0.5)
                    Qt.callLater(root.finish, slot.key)
            }
            Component.onCompleted: {
                root.report(slot.key, slot.height, slot.presence)
                slot.entered = true
            }

            Behavior on height { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on presence { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

            NotificationToast {
                id: toast

                width: parent.width
                // Coming or going, the card keeps its size and moves with the
                // slot's moving side (the bottom of a stack that hangs from
                // the top): it slides in from, and out towards, the edge.
                y: (!slot.settled || slot.leaving) && !root.atBottom ? slot.height - toast.height : 0
                enabled: !slot.leaving
                leaving: slot.leaving
                notification: slot.leaving ? slot.frozen : slot.live
                queue: root.queue
                arrived: root.queue.arrived[slot.nid] || Date.now()
                now: root.now
                newest: root.newestKey === slot.key
                strings: root.strings
                act: root.act
                snoozeEnabled: root.snoozeEnabled
                mutedApps: root.mutedApps
            }
        }
    }
}
