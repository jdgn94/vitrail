import QtQuick
import QtTest
import "../../bar/notifications/progress.js" as Progress

// The hints a live task puts on its notification, and the actions it offers.
TestCase {
    name: "DownloadProgress"

    function note(state, percent) {
        var hints = {}
        if (state !== undefined)
            hints["x-vitrail-state"] = state
        if (percent !== undefined)
            hints["value"] = percent
        return { hints: hints }
    }

    function test_a_plain_notification_has_no_state() {
        compare(Progress.state(null), "")
        compare(Progress.state({}), "")
        compare(Progress.state({ hints: {} }), "")
        compare(Progress.live(null), false)
        compare(Progress.percent(null), -1)
    }

    function test_the_state_is_the_daemons_hint() {
        compare(Progress.state(note("live")), "live")
        compare(Progress.state(note("done")), "done")
        compare(Progress.state(note("busy")), "busy")
    }

    function test_a_live_task_stays_until_it_ends() {
        compare(Progress.live(note("live")), true)
        compare(Progress.live(note("cancelling")), true)
        compare(Progress.live(note("busy")), true)
        compare(Progress.live(note("done")), false)
        compare(Progress.live(note("cancelled")), false)
    }

    function test_the_percentage_is_only_what_was_sent() {
        compare(Progress.percent(note("live")), -1)
        compare(Progress.percent(note("live", 0)), 0)
        compare(Progress.percent(note("live", 42)), 42)
        compare(Progress.percent(note("live", 100)), 100)
        compare(Progress.percent(note("live", -5)), -1)
        compare(Progress.percent(note("live", 140)), -1)
        compare(Progress.percent(note("live", "not a number")), -1)
    }

    function test_the_cancel_action_is_found_by_its_key() {
        var actions = [{ identifier: "delete", text: "Delete" }, { identifier: "cancel", text: "Cancel" }]
        compare(Progress.actionOf(actions, "cancel").text, "Cancel")
        compare(Progress.actionOf(actions, "folder"), null)
        compare(Progress.actionOf(null, "cancel"), null)
    }
}
