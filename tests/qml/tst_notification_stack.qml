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
            // What reached the app: every close, whatever the reason.
            property int closes: 0
            signal closed(int reason)

            function dismiss() { closes++; closed(1) }
            function expire() { closes++; closed(1) }
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

    // Every slot the stack holds, top to bottom: { id, y, height, slot }.
    // Leaving ones are listed too; `ids` only names the ones that stay.
    function toasts(stack) {
        var found = []
        function walk(item) {
            for (var i = 0; i < item.children.length; i++) {
                var child = item.children[i]
                if (child.objectName === "slot")
                    found.push({ id: child.nid, y: child.mapToItem(stack, 0, 0).y, height: child.height,
                                 slot: child })
                else
                    walk(child)
            }
        }
        walk(stack)
        found.sort(function (a, b) { return a.y - b.y })
        return found
    }

    function ids(stack) {
        return toasts(stack).filter(function (toast) { return !toast.slot.leaving })
                            .map(function (toast) { return toast.id })
    }

    // The toast inside a slot, and its card.
    function cardOf(slot) {
        var found = null
        function walk(item) {
            for (var i = 0; i < item.children.length && !found; i++) {
                if ("userExpanded" in item.children[i])
                    found = item.children[i]
                else
                    walk(item.children[i])
            }
        }
        walk(slot)
        return found
    }

    function closeButtonOf(card) {
        var found = null
        function walk(item) {
            for (var i = 0; i < item.children.length && !found; i++) {
                var child = item.children[i]
                if (child.icon === "close" && "hovered" in child)
                    found = child
                else
                    walk(child)
            }
        }
        walk(card)
        return found
    }

    function assertApart(stack, label) {
        var list = toasts(stack).filter(function (toast) { return !toast.slot.leaving })
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

    // Slots never overlap, at any instant: their heights are the animation.
    function assertNeverOver(stack, label) {
        var list = toasts(stack)
        for (var i = 1; i < list.length; i++)
            verify(list[i].y >= list[i - 1].y + list[i - 1].height - 0.5,
                   label + ": slot of toast " + list[i].id + " (y " + list[i].y + ") is over the one of toast "
                   + list[i - 1].id + " (y " + list[i - 1].y + " h " + list[i - 1].height + ")")
    }

    function test_slots_never_overlap_even_while_they_move() {
        var s = build()
        add(s.queue, 1, { actions: [action("open")] })
        for (var frame = 0; frame < 6; frame++) {
            wait(16)
            assertNeverOver(s.stack, "arriving 1 / frame " + frame)
        }
        add(s.queue, 2, { actions: [action("open"), action("b")], hasInlineReply: true })
        add(s.queue, 3)
        for (frame = 0; frame < 24; frame++) {
            wait(16)
            assertNeverOver(s.stack, "arriving 2, 3 / frame " + frame)
        }
        s.queue.hide(2)
        for (frame = 0; frame < 24; frame++) {
            wait(16)
            assertNeverOver(s.stack, "hiding 2 / frame " + frame)
        }
    }

    function test_a_new_toast_opens_with_its_content_already_inside() {
        var s = build()
        add(s.queue, 1, { actions: [action("open")] })
        wait(16)
        var slot = toasts(s.stack)[0].slot
        var card = cardOf(slot)
        verify(slot.height < slot.full, "starts closed and grows")
        for (var frame = 0; frame < 5; frame++) {
            compare(card.opacity, 1)
            compare(card.parent.opacity, 1)
            verify(card.summary !== "")
            wait(16)
        }
        tryVerify(function () { return slot.height >= slot.full - 0.5 }, 1000)
    }

    function test_a_leaving_toast_keeps_its_content_while_its_slot_closes() {
        var s = build()
        var first = add(s.queue, 1, { actions: [action("open")] })
        add(s.queue, 2, { actions: [action("open")] })
        settle()
        var gone = toasts(s.stack).filter(function (toast) { return toast.id === 1 })[0].slot
        var card = cardOf(gone)
        var before = gone.height
        verify(before > 0)
        first.dismiss()
        wait(30)
        verify(gone.leaving, "the slot stays while it closes")
        verify(gone.height > 0 && gone.height < before, "and its height is what animates: " + gone.height)
        var last = gone.height
        for (var frame = 0; frame < 6 && gone && gone.height > 1; frame++) {
            compare(card.opacity, 1)
            compare(card.parent.opacity, 1)
            compare(card.summary, "Title 1")
            verify(gone.height <= last + 0.01, "it only shrinks")
            last = gone.height
            assertNeverOver(s.stack, "while leaving / frame " + frame)
            wait(16)
        }
        tryCompare(s.stack.rows, "count", 1, 1000)
        compare(ids(s.stack), [2])
    }

    function test_the_last_toast_closes_its_container_before_the_stack_is_empty() {
        var s = build()
        var only = add(s.queue, 1)
        settle()
        var full = s.stack.implicitHeight
        verify(full > 0)
        only.dismiss()
        wait(40)
        verify(s.stack.count === 1, "its slot is still there")
        verify(s.stack.implicitHeight > 0 && s.stack.implicitHeight < full,
               "the stack shrinks with it: " + s.stack.implicitHeight + " of " + full)
        tryCompare(s.stack, "implicitHeight", 0, 1000)
        compare(s.stack.count, 0)
    }

    function test_the_x_hides_the_toast_and_keeps_the_notification() {
        var s = build()
        var first = add(s.queue, 1, { actions: [action("open")] })
        var second = add(s.queue, 2)
        settle()
        var slot = toasts(s.stack).filter(function (toast) { return toast.id === 1 })[0].slot
        var button = closeButtonOf(cardOf(slot))
        verify(button, "the card has an X")
        mouseClick(button)
        wait(30)
        compare(s.queue.shown.count, 1)
        compare(s.queue.shown.get(0).nid, 2)
        // Nothing reached the app and the panel still lists it, live.
        compare(first.closes, 0)
        compare(second.closes, 0)
        compare(s.queue.history.count, 2)
        var row = s.queue.row(1)
        verify(row !== null)
        compare(row.expired, false)
        compare(row.acted, false)
        verify(s.queue.byId[1] === first)
        // Its slot closes like any other, content in place.
        verify(slot.leaving)
        compare(cardOf(slot).opacity, 1)
        tryCompare(s.stack.rows, "count", 1, 1000)
        compare(ids(s.stack), [2])
    }

    function test_a_hidden_toast_does_not_expire_on_its_way_out() {
        var s = build()
        var note = add(s.queue, 1, { expireTimeout: 120 })
        add(s.queue, 2, { expireTimeout: 0 })
        wait(10)
        s.queue.hide(1)
        wait(400)
        compare(note.closes, 0)
        compare(s.queue.row(1).expired, false)
    }
}
