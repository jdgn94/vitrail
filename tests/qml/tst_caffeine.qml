import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/caffeine"
import "../../bar/caffeine/caffeine.js" as Caffeine

// The caffeine element: the cup's on state, the remaining time, the duration
// buttons, the inhibitor's report and the clicks it hands to the shell.
TestCase {
    id: testCase

    name: "Caffeine"
    when: windowShown
    visible: true
    width: 460
    height: 760

    readonly property var strings: ({
        "bar.widget.caffeine": "Caffeine",
        "bar.caffeine.off": "Caffeine is off",
        "bar.caffeine.remaining": "Caffeine · %1 left",
        "bar.caffeine.untilOff": "Until turned off",
        "bar.caffeine.inhibitorOn": "The inhibitor is active: the screen stays on and the session does not suspend.",
        "bar.caffeine.inhibitorOff": "The inhibitor is not active.",
        "bar.caffeine.duration": "Duration",
        "bar.caffeine.15m": "15 minutes",
        "bar.caffeine.30m": "30 minutes",
        "bar.caffeine.1h": "1 hour",
        "bar.caffeine.state": "Inhibitor",
        "bar.duration.minutes": "%1 min",
        "bar.duration.hours": "%1 h",
        "bar.duration.hoursMinutes": "%1 h %2 min"
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    Component {
        id: buttonComponent

        CaffeineButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        CaffeinePanel {
            width: 380
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: toggles; signalName: "toggleRequested" }
    SignalSpy { id: menus; signalName: "menuRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function build(component, props) {
        var item = createTemporaryObject(component, testCase)
        for (var key in props)
            item[key] = props[key]
        return item
    }

    function find(item, name) {
        var out = []
        function walk(node) {
            if (node.objectName === name)
                out.push(node)
            var kids = node.children || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i])
        }
        walk(item)
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_durations_are_the_four_the_plan_names() {
        compare(Caffeine.DURATIONS, [15, 30, 60, 0])
        compare(Caffeine.minutesOf(undefined), 30)
        compare(Caffeine.minutesOf(15), 15)
        compare(Caffeine.minutesOf(30), 30)
        compare(Caffeine.minutesOf(60), 60)
        compare(Caffeine.minutesOf(0), 0)
        compare(Caffeine.minutesOf(45), 30)
        compare(Caffeine.minutesOf("nope"), 30)
    }

    function test_a_timed_inhibitor_ends_and_an_untimed_one_does_not() {
        var now = 1763730000000
        compare(Caffeine.untilFor(15, now), now + 15 * 60000)
        compare(Caffeine.untilFor(0, now), 0)
        var state = Caffeine.state(true, now + 30 * 60000, now)
        compare(state.on, true)
        compare(state.minutes, 30)
        compare(state.timed, true)
        compare(Caffeine.state(true, now - 1, now).on, false)
        compare(Caffeine.state(true, 0, now).on, true)
        compare(Caffeine.state(true, 0, now).timed, false)
        compare(Caffeine.state(false, now + 60000, now).on, false)
    }

    function test_the_tooltip_names_the_state_and_the_time_left() {
        var now = 1763730000000
        compare(Caffeine.summary(false, 0, now, t), "Caffeine is off")
        compare(Caffeine.summary(true, now + 25 * 60000, now, t), "Caffeine · 25 min left")
        compare(Caffeine.summary(true, now + 90 * 60000, now, t), "Caffeine · 1 h 30 min left")
        compare(Caffeine.summary(true, 0, now, t), "Until turned off")
        compare(Caffeine.detail(true, t), "The inhibitor is active: the screen stays on and the session does not suspend.")
        compare(Caffeine.detail(false, t), "The inhibitor is not active.")
    }

    // --- the button ----------------------------------------------------------

    function test_the_cup_fills_while_the_inhibitor_is_on() {
        var now = 1763730000000
        var button = build(buttonComponent, {
            caffeineOn: true,
            until: now + 30 * 60000,
            inhibiting: true,
            now: now
        })
        verify(button.active)
        verify(button.shown)
        compare(button.tooltip, "Caffeine · 30 min left")
        compare(button.tooltipDetail, "The inhibitor is active: the screen stays on and the session does not suspend.")
        var cup = find(button, "cup")[0]
        compare(cup.container, true)
        compare(cup.icon, "coffee")

        button.caffeineOn = false
        verify(!button.active)
        compare(button.tooltip, "Caffeine is off")
        compare(find(button, "cup")[0].container, false)
    }

    function test_left_and_middle_click_toggle_and_right_click_opens_the_menu() {
        var button = build(buttonComponent, {})
        toggles.target = button
        menus.target = button
        toggles.clear()
        menus.clear()
        mouseClick(button, 20, 20, Qt.LeftButton)
        compare(toggles.count, 1)
        mouseClick(button, 20, 20, Qt.MiddleButton)
        compare(toggles.count, 2)
        mouseClick(button, 20, 20, Qt.RightButton)
        compare(menus.count, 1)
    }

    // --- the panel -----------------------------------------------------------

    function test_the_four_duration_buttons_report_their_minutes() {
        var panel = build(panelComponent, { defaultMinutes: 30 })
        var wanted = []
        panel.durationRequested.connect(function (minutes) { wanted.push(minutes) })
        find(panel, "duration-15")[0].clicked()
        find(panel, "duration-30")[0].clicked()
        find(panel, "duration-60")[0].clicked()
        find(panel, "duration-0")[0].clicked()
        compare(wanted, [15, 30, 60, 0])
        compare(find(panel, "duration-0")[0].text, "Until turned off")
        compare(find(panel, "duration-60")[0].text, "1 hour")
    }

    function test_the_switch_and_the_gear_ask_for_their_actions() {
        var panel = build(panelComponent, { caffeineOn: false })
        var toggled = 0
        var asked = 0
        panel.toggleRequested.connect(function () { toggled++ })
        panel.settingsRequested.connect(function () { asked++ })
        var control = find(panel, "caffeineSwitch")[0]
        mouseClick(control, control.width / 2, control.height / 2)
        find(panel, "popupSettings")[0].clicked()
        compare(toggled, 1)
        compare(asked, 1)
    }

    function test_the_panel_shows_what_the_inhibitor_reports() {
        var panel = build(panelComponent, { caffeineOn: true, until: 0, inhibiting: true })
        compare(find(panel, "caffeineState")[0].text, "Until turned off")
        compare(find(panel, "inhibitorState")[0].text,
                "Inhibitor: The inhibitor is active: the screen stays on and the session does not suspend.")
        panel.inhibiting = false
        compare(find(panel, "inhibitorState")[0].text, "Inhibitor: The inhibitor is not active.")
    }
}
