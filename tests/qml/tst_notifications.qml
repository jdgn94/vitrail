import QtQuick
import QtTest
import "../../bar/notifications/notifications.js" as Notifications

TestCase {
    name: "Notifications"

    function test_configured_side_is_kept_when_free() {
        compare(Notifications.sideFor("right", "left"), "right")
        compare(Notifications.sideFor("left", "right"), "left")
    }

    function test_the_bar_side_is_never_used() {
        compare(Notifications.sideFor("left", "left"), "right")
        compare(Notifications.sideFor("right", "right"), "left")
    }

    function test_legacy_values_still_resolve() {
        compare(Notifications.sideFor("top-left", "right"), "left")
        compare(Notifications.sideFor("bottom-right", "left"), "right")
    }

    function test_an_empty_preference_defaults_to_the_right() {
        compare(Notifications.sideFor("", "left"), "right")
        compare(Notifications.sideFor("", "right"), "left")
    }

    function test_toasts_hang_from_the_top_of_that_side() {
        compare(Notifications.stackPosition("left", "right"), "top-left")
        compare(Notifications.stackPosition("left", "left"), "top-right")
    }

    function test_the_preference_booleans_are_read_as_they_come() {
        verify(Notifications.enabled("true"))
        verify(!Notifications.enabled("false"))
        verify(!Notifications.enabled(undefined))
    }

    function test_an_app_list_is_one_comma_separated_preference() {
        compare(Notifications.list(""), [])
        compare(Notifications.list(" A , B,,A "), ["A", "B"])
        compare(Notifications.joined(["A", " B ", "A", ""]), "A,B")
    }

    function test_a_muted_app_is_listed_but_never_toasted() {
        verify(Notifications.muted("Discord", "Discord,Telegram"))
        verify(!Notifications.muted("Slack", "Discord,Telegram"))
        verify(!Notifications.muted("", ""))
    }

    function test_urgent_comes_from_the_app_or_the_user() {
        verify(Notifications.urgent({ urgency: 2, appName: "Calls" }, ""))
        verify(!Notifications.urgent({ urgency: 1, appName: "Calls" }, ""))
        verify(Notifications.urgent({ urgency: 1, appName: "Telegram Desktop" }, "Telegram Desktop"))
        verify(!Notifications.urgent(null, "Telegram Desktop"))
    }

    function test_a_chat_is_grouped_by_its_conversation() {
        verify(Notifications.messaging({ appName: "Telegram Desktop", hints: {} }))
        verify(Notifications.messaging({ appName: "Other", hints: { category: "im.received" } }))
        verify(!Notifications.messaging({ appName: "Correo", hints: {} }))
        compare(Notifications.conversation({ appName: "Telegram Desktop", summary: "Juan", hints: {} }), "Juan")
        compare(Notifications.conversation({ appName: "Correo", summary: "Invoice", hints: {} }), "")
        compare(Notifications.conversation({ appName: "X", summary: "s",
                                             hints: { "x-vitrail-conversation": "thread 4" } }), "thread 4")
    }

    function test_a_notification_image_survives_a_restart() {
        compare(Notifications.persistedImage("file:///tmp/a.png"), "file:///tmp/a.png")
        compare(Notifications.persistedImage("image://icon/telegram"), "image://icon/telegram")
        compare(Notifications.persistedImage("image://qsimage/75/1"), "")
        compare(Notifications.persistedImage(""), "")
    }

    function test_a_bare_url_becomes_a_link() {
        compare(Notifications.linkify("see https://example.com/x now"),
                'see <a href="https://example.com/x">https://example.com/x</a> now')
        compare(Notifications.linkify('<a href="https://a.b">https://a.b</a>'),
                '<a href="https://a.b">https://a.b</a>')
        compare(Notifications.linkify(""), "")
    }

    function test_a_snooze_wakes_at_its_time() {
        var now = new Date(2026, 10, 1, 22, 0, 0).getTime()
        compare(Notifications.wakeTime("15m", now), now + 15 * 60000)
        compare(Notifications.wakeTime("1h", now), now + 60 * 60000)
        var tomorrow = new Date(Notifications.wakeTime("tomorrow", now))
        compare(tomorrow.getDate(), 2)
        compare(tomorrow.getHours(), 8)
        compare(tomorrow.getMinutes(), 0)
    }

    function test_a_snoozed_notification_survives_as_json() {
        var row = { summary: "Ana", body: "hola", appName: "Discord", icon: "discord" }
        var text = Notifications.addSnooze("", row, 5000)
        var found = Notifications.parseSnoozes(text)
        compare(found.length, 1)
        compare(found[0].summary, "Ana")
        var due = Notifications.dueSnoozes(text, 5000)
        compare(due.due.length, 1)
        compare(JSON.parse(due.rest).length, 0)
        var later = Notifications.dueSnoozes(text, 4999)
        compare(later.due.length, 0)
        compare(Notifications.parseSnoozes("not json"), [])
        compare(Notifications.parseSnoozes('[{"until": 1}]').length, 1)
    }

    function test_the_stats_are_todays_counts_per_app() {
        var now = new Date(2026, 10, 1, 12, 0, 0).getTime()
        var stats = { "2026-11-01": { "Discord": [12, 3], "Correo": [2, 2] }, "2026-10-31": { "Discord": [9, 9] } }
        var list = Notifications.statsList(stats, now)
        compare(list.length, 2)
        compare(list[0].app, "Discord")
        compare(list[0].seen, 12)
        compare(list[0].acted, 3)
        compare(Notifications.dayOf(now), "2026-11-01")
    }
}
