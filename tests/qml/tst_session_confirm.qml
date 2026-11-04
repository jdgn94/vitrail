import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/session"
import "../../bar/session/actions.js" as Session

// The question before a session action: the guard's list, the countdown, and
// the two answers.
TestCase {
    id: testCase

    name: "SessionConfirm"
    when: windowShown
    visible: true
    width: 800
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
        id: dialogComponent

        SessionConfirm {
            width: 800
            height: 600
            strings: testCase.strings
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

    function dialog(extra) {
        var item = createTemporaryObject(dialogComponent, testCase, extra || ({}))
        cancelled.target = item
        cancelled.clear()
        confirmed.target = item
        confirmed.clear()
        item.forceActiveFocus()
        return item
    }

    function test_only_the_actions_that_end_the_session_ask_first() {
        for (var i = 0; i < ["suspend", "hibernate", "reboot", "poweroff"].length; i++)
            verify(Session.confirmable(["suspend", "hibernate", "reboot", "poweroff"][i]))
        verify(!Session.confirmable("lock"))
        verify(!Session.confirmable("logout"))
    }

    function test_the_guard_checks_every_action_except_a_lock() {
        for (var i = 0; i < ["suspend", "hibernate", "reboot", "poweroff", "logout"].length; i++)
            verify(Session.interrupting(["suspend", "hibernate", "reboot", "poweroff", "logout"][i]))
        verify(!Session.interrupting("lock"))
    }

    function test_the_countdown_is_rounded_up_and_finishes_at_zero() {
        compare(Session.remaining(30_000, 0), 30)
        compare(Session.remaining(30_000, 1), 30)
        compare(Session.remaining(30_000, 1_500), 29)
        compare(Session.remaining(30_000, 29_999), 1)
        compare(Session.remaining(30_000, 30_000), 0)
        verify(Session.finished(30_000, 30_000))
        verify(!Session.finished(30_000, 29_999))
    }

    function test_the_countdown_names_the_action_and_the_seconds() {
        var item = dialog({ action: "poweroff", phase: "countdown", remaining: 17, total: 30 })
        compare(item.title, "Shut down in 17 seconds")
        compare(item.buttons.length, 2)
        compare(item.buttons[0].label, "Cancel")
        compare(item.buttons[1].label, "Do it now")
        item.remaining = 5
        compare(item.title, "Shut down in 5 seconds")
    }

    function test_the_problem_says_what_is_running_and_offers_going_ahead() {
        var item = dialog({ action: "poweroff", phase: "problem",
                            jobs: [{ kind: "download", label: "big.iso.part" },
                                   { kind: "update", label: "pacman" },
                                   { kind: "job", label: "Backup" }] })
        compare(item.title, "Something is still running")
        compare(item.label(item.jobs[0]), "Downloading big.iso.part")
        compare(item.label(item.jobs[1]), "Updating packages (pacman)")
        compare(item.label(item.jobs[2]), "Backup is running")
        compare(item.buttons[1].label, "Go ahead")
    }

    function test_escape_cancels_and_enter_confirms() {
        var item = dialog({ action: "poweroff", phase: "countdown", remaining: 20, total: 30 })
        keyClick(Qt.Key_Escape)
        compare(cancelled.count, 1)
        compare(confirmed.count, 0)
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 1)
    }

    function test_the_problem_confirms_with_enter_too() {
        dialog({ action: "reboot", phase: "problem", jobs: [{ kind: "job", label: "Copy" }] })
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 1)
    }
}
