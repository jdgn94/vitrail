import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/session"
import "../../bar/session/actions.js" as Session

// The session menu: which actions it offers, how the keyboard drives it.
TestCase {
    id: testCase

    name: "SessionMenu"
    when: windowShown
    visible: true
    width: 900
    height: 600

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
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
        id: chosen

        signalName: "chosen"
    }

    SignalSpy {
        id: dismissed

        signalName: "dismissed"
    }

    function menu(canHibernate) {
        var item = createTemporaryObject(menuComponent, testCase, { canHibernate: canHibernate })
        chosen.target = item
        chosen.clear()
        dismissed.target = item
        dismissed.clear()
        item.forceActiveFocus()
        return item
    }

    function test_hibernate_is_offered_only_when_possible() {
        compare(Session.available(true).map(function (a) { return a.key }),
                ["lock", "logout", "suspend", "hibernate", "reboot", "poweroff"])
        compare(Session.available(false).map(function (a) { return a.key }),
                ["lock", "logout", "suspend", "reboot", "poweroff"])
    }

    function test_each_action_runs_its_command() {
        compare(Session.find("lock").command, ["hyprlock"])
        compare(Session.find("logout").command, ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"])
        compare(Session.find("reboot").command, ["systemctl", "reboot"])
        compare(Session.find("poweroff").command, ["systemctl", "poweroff"])
        compare(Session.find("poweroff").tone, "error")
        compare(Session.find("nothing"), null)
    }

    function test_the_focus_ring_wraps() {
        compare(Session.step(0, 5, -1), 4)
        compare(Session.step(4, 5, 1), 0)
        compare(Session.step(2, 5, 1), 3)
    }

    function test_arrow_keys_move_the_focus_and_enter_runs() {
        var m = menu(false)
        compare(m.current, 0)
        keyClick(Qt.Key_Right)
        keyClick(Qt.Key_Right)
        compare(m.current, 2)
        keyClick(Qt.Key_Left)
        compare(m.current, 1)
        keyClick(Qt.Key_Return)
        compare(chosen.count, 1)
        compare(chosen.signalArguments[0][0], "logout")
    }

    function test_left_on_the_first_action_wraps_to_the_last() {
        var m = menu(true)
        keyClick(Qt.Key_Left)
        compare(m.current, 5)
        keyClick(Qt.Key_Space)
        compare(chosen.signalArguments[0][0], "poweroff")
    }

    function test_a_letter_runs_its_action() {
        menu(true)
        keyClick("h")
        compare(chosen.signalArguments[0][0], "hibernate")
    }

    function test_a_letter_of_a_hidden_action_does_nothing() {
        menu(false)
        keyClick("h")
        compare(chosen.count, 0)
    }

    function test_escape_dismisses() {
        menu(false)
        keyClick(Qt.Key_Escape)
        compare(dismissed.count, 1)
        compare(chosen.count, 0)
    }

    function test_opening_resets_the_focus_ring() {
        var m = menu(false)
        keyClick(Qt.Key_End)
        compare(m.current, 4)
        m.open = false
        m.open = true
        compare(m.current, 0)
    }
}
