import QtQuick
import QtTest
import "../../bar/notifications"

// Which notifications are on screen and which wait their turn.
TestCase {
    name: "NotificationQueue"

    Component {
        id: fake

        QtObject {
            property int id
            signal closed(int reason)
        }
    }

    Component {
        id: queueComponent

        NotificationQueue {}
    }

    function make(queue, count) {
        var list = []
        for (var i = 0; i < count; i++) {
            var n = createTemporaryObject(fake, this, { id: i + 1 })
            queue.push(n)
            list.push(n)
        }
        return list
    }

    function shownIds(queue) {
        var ids = []
        for (var i = 0; i < queue.shown.count; i++)
            ids.push(queue.shown.get(i).nid)
        return ids
    }

    function test_newest_shows_first() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 3)
        compare(shownIds(queue), [3, 2, 1])
    }

    function test_past_the_maximum_they_wait() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 2 })
        make(queue, 4)
        compare(shownIds(queue), [2, 1])
        compare(queue.waiting, [3, 4])
    }

    function test_a_closed_one_frees_its_slot_for_the_next_in_line() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 2 })
        var list = make(queue, 4)
        list[0].closed(1)
        compare(shownIds(queue), [3, 2])
        compare(queue.waiting, [4])
    }

    function test_a_closed_waiting_one_leaves_the_line() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 1 })
        var list = make(queue, 3)
        list[1].closed(1)
        compare(queue.waiting, [3])
    }

    function test_a_replaced_notification_is_not_shown_twice() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var list = make(queue, 1)
        queue.push(list[0])
        compare(queue.shown.count, 1)
    }

    function test_raising_the_maximum_shows_the_waiting_ones() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 1 })
        make(queue, 3)
        queue.maximum = 3
        compare(queue.shown.count, 3)
        compare(queue.waiting, [])
    }
}
