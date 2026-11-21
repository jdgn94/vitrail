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

    function build(atBottom, exit, carry) {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var props = { queue: queue, atBottom: atBottom === true }
        if (exit)
            props.exit = exit
        if (carry)
            props.carry = true
        var stack = createTemporaryObject(stackComponent, this, props)
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

    // Where the card is inside its slot, while it leaves or arrives.
    function offsetOf(slot) {
        var toast = cardOf(slot).parent
        return { x: toast.x, y: toast.y }
    }

    function leavesTowards(exit, atBottom, sign) {
        var s = build(atBottom, exit)
        var first = add(s.queue, 1, { actions: [action("open")] })
        add(s.queue, 2, { actions: [action("open")] })
        settle()
        var gone = toasts(s.stack).filter(function (toast) { return toast.id === 1 })[0].slot
        var card = cardOf(gone)
        compare(offsetOf(gone).x, 0)
        first.dismiss()
        var moved = 0
        var last = 0
        for (var frame = 0; frame < 30 && gone.height > 1; frame++) {
            wait(16)
            if (!(gone.height > 1))
                break
            var at = offsetOf(gone)
            // Whole and opaque while it slides out of its slot's side.
            compare(card.opacity, 1)
            compare(card.parent.opacity, 1)
            compare(card.summary, "Title 1")
            verify(at.x * sign >= last - 0.01, exit + ": it only moves outwards: " + at.x + " after " + last)
            last = at.x * sign
            moved = Math.max(moved, last)
            assertNeverOver(s.stack, exit + " leaving / frame " + frame)
        }
        verify(moved > 40, exit + ": it slid sideways, moved " + moved)
        tryCompare(s.stack.rows, "count", 1, 1000)
        compare(ids(s.stack), [2])
    }

    function test_the_newest_toast_leaves_open_instead_of_folding_on_the_way_out() {
        var s = build(false, "right")
        var only = add(s.queue, 1, { actions: [action("open")] })
        settle()
        var slot = toasts(s.stack)[0].slot
        var card = cardOf(slot)
        verify(card.expanded, "the newest opens expanded")
        only.dismiss()
        wait(60)
        verify(slot.leaving && slot.height > 1)
        verify(card.expanded, "and keeps its size while it goes")
    }

    function test_a_stack_at_the_right_edge_sends_a_leaving_toast_out_to_the_right() {
        leavesTowards("right", false, 1)
    }

    function test_a_stack_at_the_left_edge_sends_a_leaving_toast_out_to_the_left() {
        leavesTowards("left", false, -1)
    }

    function test_a_stack_at_the_bottom_right_still_leaves_to_the_right() {
        leavesTowards("right", true, 1)
    }

    function test_a_sideways_card_keeps_its_row_while_the_slot_closes() {
        var s = build(false, "right")
        var first = add(s.queue, 1, { actions: [action("open")] })
        settle()
        var gone = toasts(s.stack)[0].slot
        first.dismiss()
        wait(40)
        compare(offsetOf(gone).y, 0)
        verify(offsetOf(gone).x > 0)
        var low = build(true, "right")
        var other = add(low.queue, 1, { actions: [action("open")] })
        settle()
        var below = toasts(low.stack)[0].slot
        other.dismiss()
        wait(40)
        // Stuck to the bottom, the card keeps its bottom while the slot's top comes down.
        compare(offsetOf(below).y, below.height - cardOf(below).parent.height)
    }

    function test_a_new_toast_comes_in_from_the_edge_it_is_stuck_to() {
        var s = build(false, "left")
        add(s.queue, 1)
        wait(16)
        var slot = toasts(s.stack)[0].slot
        verify(offsetOf(slot).x < 0, "it starts outside, on the left: " + offsetOf(slot).x)
        tryVerify(function () { return slot.settled }, 1000)
        compare(offsetOf(slot).x, 0)
    }

    function test_a_centred_stack_still_leaves_up_or_down() {
        var s = build(false, "top")
        var first = add(s.queue, 1, { actions: [action("open")] })
        settle()
        var gone = toasts(s.stack)[0].slot
        first.dismiss()
        var up = 0
        for (var frame = 0; frame < 30 && gone.height > 1; frame++) {
            wait(16)
            if (!(gone.height > 1))
                break
            compare(offsetOf(gone).x, 0)
            up = Math.min(up, offsetOf(gone).y)
        }
        verify(up < -20, "it slid up: " + up)
        var low = build(true, "bottom")
        var other = add(low.queue, 1, { actions: [action("open")] })
        settle()
        var below = toasts(low.stack)[0].slot
        other.dismiss()
        wait(40)
        compare(offsetOf(below).x, 0)
        compare(offsetOf(below).y, 0)
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

    // A lone toast of a sideways stack is carried by the container: the slot
    // is at its full height at once and the card sits still in it, so the
    // container's own horizontal reveal is the whole motion.
    function test_a_lone_toast_of_a_carrying_stack_has_its_full_height_at_once() {
        var s = build(false, "right", true)
        add(s.queue, 1, { actions: [action("open")] })
        wait(16)
        var slot = toasts(s.stack)[0].slot
        verify(slot.height >= slot.full - 0.5 && slot.full > 0, "full at once: " + slot.height + " of " + slot.full)
        compare(offsetOf(slot).x, 0)
        verify(s.stack.implicitHeight > 0)
    }

    function test_a_lone_toast_of_a_carrying_stack_holds_its_size_until_the_container_is_gone() {
        var s = build(false, "right", true)
        var only = add(s.queue, 1, { actions: [action("open")] })
        settle()
        var slot = toasts(s.stack)[0].slot
        var full = slot.height
        var tall = s.stack.implicitHeight
        only.dismiss()
        for (var frame = 0; frame < 20; frame++) {
            wait(16)
            compare(slot.height, full)
            compare(s.stack.implicitHeight, tall)
            compare(offsetOf(slot).x, 0)
            compare(cardOf(slot).summary, "Title 1")
        }
        verify(slot.leaving, "it is still there")
        verify(!s.stack.open, "and the container is asked to close")
        s.stack.onScreen = false
        tryCompare(s.stack.rows, "count", 0, 1000)
    }

    function test_a_carrying_stack_keeps_the_per_card_slide_when_others_are_shown() {
        var s = build(false, "right", true)
        add(s.queue, 1, { actions: [action("open")] })
        settle()
        var second = add(s.queue, 2, { actions: [action("open")] })
        wait(16)
        var slot = toasts(s.stack).filter(function (toast) { return toast.id === 2 })[0].slot
        verify(slot.height < slot.full, "the new one grows: " + slot.height)
        verify(offsetOf(slot).x > 0, "and slides in from the right: " + offsetOf(slot).x)
        settle()
        second.dismiss()
        wait(30)
        verify(slot.leaving && slot.height > 0 && slot.height < slot.full, "it closes its slot while the first stays")
        verify(offsetOf(slot).x > 0, "sliding out to the right")
        tryCompare(s.stack.rows, "count", 1, 1000)
    }

    function test_a_carrying_stack_is_open_while_a_toast_is_live() {
        var s = build(false, "right", true)
        verify(!s.stack.open)
        var only = add(s.queue, 1)
        verify(s.stack.open)
        only.dismiss()
        verify(!s.stack.open, "closed as soon as the last one is dismissed")
    }

    function test_a_stack_that_does_not_carry_stays_open_until_its_slots_are_gone() {
        var s = build(false, "right")
        var only = add(s.queue, 1)
        settle()
        only.dismiss()
        verify(s.stack.open)
        tryCompare(s.stack, "open", false, 1000)
    }

    function test_a_slot_already_closing_does_not_jump_back_when_the_last_one_leaves() {
        var s = build(false, "right", true)
        var first = add(s.queue, 1, { actions: [action("open")] })
        var second = add(s.queue, 2, { actions: [action("open")] })
        settle()
        var gone = toasts(s.stack).filter(function (toast) { return toast.id === 1 })[0].slot
        first.dismiss()
        wait(60)
        var mid = gone.height
        verify(mid > 0 && mid < gone.full, "it is closing: " + mid)
        second.dismiss()
        wait(16)
        verify(gone.height <= mid + 0.01, "it keeps closing instead of reopening: " + gone.height)
        tryCompare(s.stack.rows, "count", 1, 1000)
        s.stack.onScreen = false
        tryCompare(s.stack.rows, "count", 0, 1000)
    }
}
