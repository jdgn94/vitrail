import QtQuick
import QtTest
import "../../bar/notifications"
import "../../bar/kit"

// The toasts on screen: one below the other, never over each other, whatever
// their heights do and however fast they arrive (a card gliding to its place
// may cross the next for a moment; what it settles at is what is checked), and
// each leaves on its own timeout. Runs with the stand-ins of ./stubs for the
// shell's Quickshell module (-import stubs).
TestCase {
    name: "NotificationStack"
    when: windowShown
    width: 520
    height: 900
    visible: true

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    Component {
        id: fake

        QtObject {
            id: note

            property int id
            property int urgency: 1
            property string summary: "Title " + id
            property string body: "Body " + id
            property string appName: "App"
            property string appIcon: ""
            property string image: ""
            // Milliseconds, -1 when the app gave none, as Quickshell reports it.
            property real expireTimeout: -1
            property var hints: ({})
            property bool hasInlineReply: false
            property string inlineReplyPlaceholder: ""
            property var actions: []
            signal closed(int reason)

            function dismiss() { closed(1) }
            function expire() { closed(1) }
        }
    }

    Component {
        id: queueComponent

        NotificationQueue {}
    }

    Component {
        id: stackComponent

        NotificationStack {
            width: 400
            strings: ({})
        }
    }

    function action(identifier) {
        return { identifier: identifier, text: identifier, invoke: function () {} }
    }

    function add(queue, id, props) {
        var note = createTemporaryObject(fake, this, Object.assign({ id: id }, props || {}))
        queue.push(note)
        return note
    }

    // Every toast the stack holds, top to bottom: { id, y, height }.
    function toasts(stack) {
        var found = []
        function walk(item) {
            for (var i = 0; i < item.children.length; i++) {
                var child = item.children[i]
                if (child.objectName === "toast")
                    found.push({ id: child.notification ? child.notification.id : 0,
                                 y: child.mapToItem(stack, 0, 0).y, height: child.height })
                else
                    walk(child)
            }
        }
        walk(stack)
        found.sort(function (a, b) { return a.y - b.y })
        return found
    }

    function ids(stack) {
        return toasts(stack).map(function (toast) { return toast.id })
    }

    function assertApart(stack, label) {
        var list = toasts(stack)
        for (var i = 1; i < list.length; i++) {
            var gap = list[i].y - (list[i - 1].y + list[i - 1].height)
            verify(gap >= stack.pad - 0.5,
                   label + ": toast " + list[i].id + " starts " + gap + " px under toast " + list[i - 1].id
                   + " (y " + list[i - 1].y + " h " + list[i - 1].height + " / y " + list[i].y + ")")
        }
        if (list.length > 0)
            verify(stack.implicitHeight >= list[list.length - 1].y + list[list.length - 1].height - 0.5,
                   label + ": the stack's height " + stack.implicitHeight + " cuts the last toast")
    }

    // Past the glide of the cards into place.
    function settle() {
        wait(320)
    }

    function build(atBottom) {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var stack = createTemporaryObject(stackComponent, this, { queue: queue, atBottom: atBottom === true })
        verify(stack)
        return { queue: queue, stack: stack }
    }

    function test_toasts_of_different_heights_never_overlap_as_they_arrive() {
        var s = build()
        add(s.queue, 1, { body: "short", actions: [action("default"), action("open")] })
        wait(30)
        add(s.queue, 2, { body: "a longer body that has to wrap over several lines of the card, " +
                                "so this toast is taller than the one before it " +
                                "and than the one that comes after it" })
        wait(30)
        add(s.queue, 3, { body: "x", hasInlineReply: true, actions: [action("a"), action("b"), action("c")] })
        wait(20)
        compare(ids(s.stack).length, 3)
        settle()
        assertApart(s.stack, "settled")
    }

    function test_the_newest_stays_nearest_the_edge() {
        var s = build()
        add(s.queue, 1)
        add(s.queue, 2)
        add(s.queue, 3)
        settle()
        compare(ids(s.stack), [3, 2, 1])
        var low = build(true)
        add(low.queue, 1)
        add(low.queue, 2)
        add(low.queue, 3)
        settle()
        compare(ids(low.stack), [1, 2, 3])
        assertApart(low.stack, "from the bottom edge")
    }

    function test_expanding_and_collapsing_moves_the_ones_below() {
        var s = build()
        add(s.queue, 1, { actions: [action("open")] })
        add(s.queue, 2, { actions: [action("open")] })
        add(s.queue, 3, { actions: [action("open")] })
        settle()
        for (var round = 0; round < 3; round++) {
            var cards = []
            function collect(item) {
                for (var i = 0; i < item.children.length; i++) {
                    var child = item.children[i]
                    if ("userExpanded" in child)
                        cards.push(child)
                    else
                        collect(child)
                }
            }
            collect(s.stack)
            compare(cards.length, 3)
            for (var c = 0; c < cards.length; c++)
                cards[c].userExpanded = round % 2 === 0
            settle()
            assertApart(s.stack, "settled after toggling, round " + round)
        }
    }

    function test_a_toast_leaves_on_its_own_timeout_and_the_others_stay() {
        var s = build()
        add(s.queue, 1, { expireTimeout: 600 })
        add(s.queue, 2, { expireTimeout: 200 })
        add(s.queue, 3, { expireTimeout: 1000 })
        wait(20)
        compare(ids(s.stack).length, 3)
        tryCompare(s.queue.shown, "count", 2, 1000)
        compare(s.queue.shown.get(0).nid, 3)
        compare(s.queue.shown.get(1).nid, 1)
        tryCompare(s.queue.shown, "count", 1, 1500)
        compare(s.queue.shown.get(0).nid, 3)
        settle()
        assertApart(s.stack, "after the second expired")
        tryCompare(s.queue.shown, "count", 0, 2000)
    }

    function test_a_toast_without_a_timeout_stays_and_a_critical_one_too() {
        var s = build()
        add(s.queue, 1, { expireTimeout: 0 })
        add(s.queue, 2, { urgency: 2 })
        add(s.queue, 3, { expireTimeout: 200 })
        tryCompare(s.queue.shown, "count", 2, 1000)
        wait(500)
        compare(s.queue.shown.count, 2)
        compare(s.queue.shown.get(0).nid, 2)
        compare(s.queue.shown.get(1).nid, 1)
    }

    function test_a_toast_that_is_dismissed_lets_the_others_close_the_gap() {
        var s = build()
        var first = add(s.queue, 1, { actions: [action("open")] })
        add(s.queue, 2, { actions: [action("open")] })
        add(s.queue, 3, { actions: [action("open")] })
        settle()
        first.dismiss()
        settle()
        compare(ids(s.stack), [3, 2])
        assertApart(s.stack, "after the gap closed")
    }
}
