import QtQuick
import QtTest
import "../../bar/notifications"
import "../../bar/notifications/notifications.js" as Notifications

// Which notifications are on screen and which wait their turn.
TestCase {
    name: "NotificationQueue"

    Component {
        id: fake

        QtObject {
            property int id
            property int urgency: 1
            property string summary: "Title " + id
            property string body: "Body " + id
            property string appName: "App"
            signal closed(int reason)

            function dismiss() { closed(1) }
            // Quickshell reports a time-out with the dismiss reason.
            function expire() { closed(1) }
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

    function test_arrival_time_is_kept_until_it_closes() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var before = Date.now()
        var list = make(queue, 1)
        verify(queue.arrived[1] >= before)
        list[0].closed(1)
        compare(queue.arrived[1], undefined)
    }

    function historyIds(queue) {
        var ids = []
        for (var i = 0; i < queue.history.count; i++)
            ids.push(queue.history.get(i).nid)
        return ids
    }

    function test_the_history_holds_every_live_notification() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 2 })
        make(queue, 7)
        compare(historyIds(queue), [7, 6, 5, 4, 3, 2, 1])
        compare(shownIds(queue), [2, 1])
    }

    function test_the_history_drops_the_oldest_past_its_limit() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5, limit: 3 })
        make(queue, 5)
        compare(historyIds(queue), [5, 4, 3])
    }

    function test_an_arrival_while_the_panel_is_open_is_listed_but_not_toasted() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5, panelOpen: true })
        make(queue, 2)
        compare(historyIds(queue), [2, 1])
        compare(shownIds(queue), [])
        compare(queue.waiting, [])
    }

    function test_opening_the_panel_clears_the_cards_but_keeps_the_list() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 2)
        queue.panelOpen = true
        compare(shownIds(queue), [])
        compare(queue.waiting, [])
        compare(historyIds(queue), [2, 1])
    }

    function test_closing_the_panel_does_not_raise_the_backlog() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5, panelOpen: true })
        make(queue, 2)
        queue.panelOpen = false
        compare(shownIds(queue), [])
        compare(historyIds(queue), [2, 1])
    }

    function test_a_dismissed_one_leaves_the_history() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var list = make(queue, 2)
        list[0].closed(1)
        compare(historyIds(queue), [2])
    }

    function test_an_expired_one_keeps_its_row() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 2)
        queue.expire(1)
        compare(shownIds(queue), [2])
        compare(historyIds(queue), [2, 1])
        compare(queue.history.get(1).expired, true)
        compare(queue.byId[1], undefined)
    }

    function test_a_row_keeps_its_text_after_the_notification_is_gone() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 1)
        queue.expire(1)
        compare(queue.history.get(0).summary, "Title 1")
        compare(queue.history.get(0).body, "Body 1")
        compare(queue.history.get(0).appName, "App")
    }

    function test_dismissing_an_expired_row_removes_it() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 1)
        queue.expire(1)
        queue.dismiss(1)
        compare(historyIds(queue), [])
    }

    function test_dismissing_a_live_row_removes_it() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 2)
        queue.dismiss(2)
        compare(historyIds(queue), [1])
        compare(shownIds(queue), [1])
    }

    function test_expiring_marks_the_row_instead_of_dropping_it() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 1)
        queue.expire(1)
        compare(historyIds(queue), [1])
        compare(queue.history.get(0).expired, true)
        compare(queue.byId[1], undefined)
    }

    function test_an_app_withdrawal_removes_the_row() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var list = make(queue, 1)
        list[0].closed(2)
        compare(historyIds(queue), [])
    }

    function test_clear_empties_the_list() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 3)
        queue.clear()
        compare(historyIds(queue), [])
        compare(shownIds(queue), [])
    }

    function pushApp(queue, id, appName) {
        var n = createTemporaryObject(fake, this, { id: id, appName: appName })
        queue.push(n)
        return n
    }

    function test_clearing_a_group_dismisses_its_live_notifications() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        pushApp(queue, 1, "A")
        pushApp(queue, 2, "B")
        pushApp(queue, 3, "A")
        queue.clearGroup("A")
        compare(historyIds(queue), [2])
        compare(shownIds(queue), [2])
    }

    function test_clearing_a_group_forgets_its_expired_rows() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        pushApp(queue, 1, "A")
        pushApp(queue, 2, "A")
        pushApp(queue, 3, "B")
        queue.expire(1)
        compare(queue.history.get(2).expired, true)
        queue.clearGroup("A")
        compare(historyIds(queue), [3])
    }

    function test_clearing_a_group_leaves_the_other_apps_alone() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        pushApp(queue, 1, "A")
        pushApp(queue, 2, "B")
        queue.expire(2)
        queue.clearGroup("A")
        compare(historyIds(queue), [2])
        compare(queue.history.get(0).expired, true)
    }

    function test_clearing_an_unknown_group_changes_nothing() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 2)
        queue.clearGroup("nobody")
        compare(historyIds(queue), [2, 1])
    }

    function test_a_muted_app_is_listed_but_never_toasted() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5, muted: "App" })
        make(queue, 2)
        compare(historyIds(queue), [2, 1])
        compare(shownIds(queue), [])
        compare(queue.waiting, [])
    }

    function test_an_urgent_one_toasts_under_do_not_disturb() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5, dnd: true })
        queue.push(createTemporaryObject(fake, this, { id: 1, appName: "Quiet" }))
        compare(shownIds(queue), [])
        queue.push(createTemporaryObject(fake, this, { id: 2, appName: "Calls", urgency: 2 }))
        compare(shownIds(queue), [2])
        queue.urgentBypass = false
        queue.push(createTemporaryObject(fake, this, { id: 3, appName: "Calls", urgency: 2 }))
        compare(shownIds(queue), [2])
    }

    function test_the_stats_count_arrivals_and_acts() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        var list = make(queue, 2)
        var day = Notifications.dayOf(Date.now())
        compare(queue.stats[day].App[0], 2)
        compare(queue.stats[day].App[1], 0)
        list[0].closed(1)
        compare(queue.stats[day].App[1], 1)
    }

    function test_snoozing_takes_the_row_out_and_announces_when() {
        var queue = createTemporaryObject(queueComponent, this, { maximum: 5 })
        make(queue, 1)
        var seen = null
        queue.snoozed.connect(function (row, until) { seen = { row: row, until: until } })
        var until = queue.snooze(1, "15m")
        verify(seen !== null)
        compare(until, seen.until)
        compare(seen.row.summary, "Title 1")
        compare(historyIds(queue), [])
    }
}
