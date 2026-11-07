import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/session"
import "../../bar/session/actions.js" as Session

// The alert surface: it shows while an action waits for an answer, with the
// menu and the popup closed as much as with the menu open, takes the focus,
// answers Escape/Enter and holds exactly one confirm. The menu no longer
// carries one.
TestCase {
    id: testCase

    name: "SessionAlert"
    when: windowShown
    visible: true
    width: 900
    height: 600

    VitrailPalette {
        id: palette
    }

    readonly property var strings: ({
        "session.poweroff": "Shut down",
        "session.reboot": "Restart",
        "session.lock": "Lock",
        "session.logout": "Log out",
        "dialog.cancel": "Cancel",
        "session.confirm.in": "%1 in %2 seconds",
        "session.confirm.now": "Do it now",
        "session.confirm.problem": "Something is still running",
        "session.confirm.problem.help": "This action would interrupt it.",
        "session.confirm.go": "Go ahead",
        "session.confirm.download": "Downloading %1",
        "session.confirm.update": "Updating packages (%1)",
        "session.confirm.job": "%1 is running"
    })

    Component {
        id: alertComponent

        SessionAlert {
            width: 900
            height: 600
            strings: testCase.strings
        }
    }

    Component {
        id: menuComponent

        SessionMenu {
            width: 900
            height: 600
            open: true
        }
    }

    SignalSpy {
        id: cancelled

        signalName: "cancelled"
    }

    SignalSpy {
        id: confirmed

        signalName: "confirmed"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function alert(extra) {
        var item = createTemporaryObject(alertComponent, testCase, extra || ({}))
        cancelled.target = item
        cancelled.clear()
        confirmed.target = item
        confirmed.clear()
        return item
    }

    // Every descendant with `name` as its objectName, under `root`.
    function named(root, name) {
        var found = []
        if (!root)
            return found
        if (root.objectName === name)
            found.push(root)
        var kids = root.children
        for (var i = 0; i < kids.length; i++)
            found = found.concat(named(kids[i], name))
        return found
    }

    function confirm() {
        return named(testCase, "sessionConfirm")
    }

    function test_the_check_phase_does_not_show_the_alert() {
        verify(!Session.alertVisible(null))
        verify(!Session.alertVisible({ phase: "check" }))
        verify(Session.alertVisible({ phase: "problem" }))
        verify(Session.alertVisible({ phase: "countdown" }))
    }

    // The popup is closed and the menu was never opened: the alert still shows.
    function test_the_alert_shows_with_the_popup_and_menu_closed() {
        var item = alert({ shown: Session.alertVisible({ key: "poweroff", phase: "countdown" }),
                           action: "poweroff", phase: "countdown", remaining: 20 })
        verify(item.visible)
        compare(named(item, "sessionConfirm").length, 1)
        verify(named(item, "sessionConfirm")[0].visible)
    }

    // The menu is open on the screen: the alert is its own surface and shows
    // too (the window above it, see AlertLayer).
    function test_the_alert_shows_while_the_menu_is_open() {
        var menu = createTemporaryObject(menuComponent, testCase, {})
        var item = alert({ shown: Session.alertVisible({ key: "reboot", phase: "problem", jobs: [] }),
                           action: "reboot", phase: "problem" })
        verify(menu.visible)
        verify(item.visible)
    }

    function test_the_alert_takes_the_keyboard_focus() {
        var item = alert({ shown: true, action: "poweroff", phase: "countdown", remaining: 20 })
        tryVerify(function () { return named(item, "sessionConfirm")[0].activeFocus }, 1000)
    }

    function test_escape_cancels_and_enter_confirms() {
        var item = alert({ shown: true, action: "poweroff", phase: "countdown", remaining: 20 })
        tryVerify(function () { return named(item, "sessionConfirm")[0].activeFocus }, 1000)
        keyClick(Qt.Key_Escape)
        compare(cancelled.count, 1)
        compare(confirmed.count, 0)
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 1)
    }

    // One alert, one confirm: the menu no longer carries a second copy.
    function test_there_is_a_single_confirm_and_the_menu_has_none() {
        var menu = createTemporaryObject(menuComponent, testCase, {})
        alert({ shown: true, action: "poweroff", phase: "countdown", remaining: 20 })
        compare(named(menu, "sessionConfirm").length, 0)
        compare(confirm().length, 1)
    }

    function test_a_hidden_alert_has_no_visible_card() {
        var item = alert({ shown: false, action: "poweroff", phase: "countdown", remaining: 20 })
        verify(!item.visible)
        verify(!named(item, "sessionConfirm")[0].visible)
    }
}
