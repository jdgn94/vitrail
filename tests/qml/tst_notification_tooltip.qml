import QtQuick
import QtTest
import "../../bar/notifications/tooltip.js" as Tooltip

// The bell: why it is quiet, for how long, and how many the badge may show.
TestCase {
    name: "NotificationTooltip"

    readonly property var strings: ({
        "tooltip.notifications": "Notifications",
        "tooltip.notificationsHint": "Left click: the centre · right click: silence for an hour",
        "tooltip.notificationsCount": "%1 in the centre · right click: silence for an hour",
        "tooltip.notificationsMuted": "Do Not Disturb · right click to turn them back on",
        "tooltip.notificationsSilentUntil": "Silent until %1 (%2 min left) · right click to turn them back on"
    })

    // A local wall clock, so the formatted HH:MM matches in every timezone.
    function at(hour, minute) {
        return new Date(2026, 10, 1, hour, minute, 0, 0).getTime()
    }

    function test_without_silence_the_plain_tooltip_stays() {
        var now = at(12, 0)
        var state = Tooltip.reason({}, now)
        compare(state.muted, false)
        compare(state.kind, "none")
        var tip = Tooltip.describe({}, now, strings, 0)
        compare(tip.muted, false)
        compare(tip.title, "Notifications")
        compare(tip.text, "Left click: the centre · right click: silence for an hour")
    }

    function test_a_count_without_silence_names_it() {
        var tip = Tooltip.describe({}, at(12, 0), strings, 3)
        compare(tip.text, "3 in the centre · right click: silence for an hour")
    }

    function test_do_not_disturb_is_the_reason_without_an_end() {
        var now = at(12, 0)
        var state = Tooltip.reason({ notificationDnd: "true", notificationMuteUntil: "0" }, now)
        compare(state.muted, true)
        compare(state.kind, "dnd")
        compare(Tooltip.describe({ notificationDnd: true }, now, strings, 0).text,
                "Do Not Disturb · right click to turn them back on")
    }

    function test_a_silence_with_an_end_says_until_and_how_long() {
        var now = at(12, 0)
        var prefs = { notificationDnd: "true",
                      notificationMuteUntil: String(at(12, 42)) }
        var state = Tooltip.reason(prefs, now)
        compare(state.muted, true)
        compare(state.kind, "until")
        compare(state.minutes, 42)
        compare(Tooltip.describe(prefs, now, strings, 7).text,
                "Silent until 12:42 (42 min left) · right click to turn them back on")
    }

    function test_the_last_partial_minute_still_counts() {
        var now = at(12, 0)
        var prefs = { notificationDnd: "true",
                      notificationMuteUntil: String(now + 30000) }
        compare(Tooltip.reason(prefs, now).minutes, 1)
    }

    function test_an_expired_silence_is_over() {
        var now = at(12, 0)
        var prefs = { notificationDnd: "true",
                      notificationMuteUntil: String(now - 1) }
        var state = Tooltip.reason(prefs, now)
        compare(state.muted, false)
        compare(state.kind, "none")
        compare(Tooltip.describe(prefs, now, strings, 0).text,
                "Left click: the centre · right click: silence for an hour")
    }

    function test_the_badge_counts_up_to_nine_then_caps() {
        compare(Tooltip.badge(0), "")
        compare(Tooltip.badge(1), "1")
        compare(Tooltip.badge(9), "9")
        compare(Tooltip.badge(12), "9+")
        compare(Tooltip.badge(12, 5), "5+")
        compare(Tooltip.badge(-3), "")
    }

    function test_a_missing_translation_keeps_its_key() {
        var tip = Tooltip.describe({ notificationDnd: true }, at(12, 0), {}, 0)
        compare(tip.title, "tooltip.notifications")
        compare(tip.text, "tooltip.notificationsMuted")
    }
}
