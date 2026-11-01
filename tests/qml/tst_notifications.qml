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

    function test_a_notification_is_silent_with_the_panel_open() {
        verify(Notifications.silent(true, false))
        verify(!Notifications.silent(false, false))
    }

    function test_do_not_disturb_silences_them_too() {
        verify(Notifications.silent(false, true))
        verify(Notifications.silent(true, true))
    }

    function test_the_preference_booleans_are_read_as_they_come() {
        verify(Notifications.silent(false, "true"))
        verify(!Notifications.silent(false, "false"))
        verify(!Notifications.silent("false", "false"))
    }
}
