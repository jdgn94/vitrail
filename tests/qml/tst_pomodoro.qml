import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/dashboard"
import "../../bar/pomodoro"
import "../../bar/dashboard/timers.js" as Timers
import "../../bar/pomodoro/pomodoro.js" as Pomodoro

// The pomodoro / timer bar element: the countdown it writes, what "active"
// means, the phase and the round, the quick timers, and the panel driving the
// shell's one TimerEngine.
TestCase {
    id: testCase

    name: "Pomodoro"
    when: windowShown
    visible: true
    width: 420
    height: 640

    readonly property var strings: ({
        "bar.widget.pomodoro": "Pomodoro",
        "bar.pomodoro.tooltip": "%1 left · %2",
        "bar.pomodoro.phase.work": "Work",
        "bar.pomodoro.phase.rest": "Break",
        "bar.pomodoro.phase.timer": "Quick timer",
        "bar.pomodoro.cycles": "Round %1 of %2",
        "bar.pomodoro.timer.detail": "%1 min timer",
        "bar.pomodoro.none": "No timer running",
        "bar.pomodoro.ready": "Ready when you are",
        "bar.pomodoro.lengths": "Work %1 min · Break %2 min · %3 rounds",
        "bar.pomodoro.quick": "Quick timers",
        "bar.pomodoro.minutes": "%1 min",
        "dashboard.focus.pomodoro": "Pomodoro",
        "dashboard.focus.timer": "Timer",
        "dashboard.focus.work": "Work",
        "dashboard.focus.rest": "Break",
        "dashboard.focus.round": "Round",
        "dashboard.focus.done": "Done",
        "dashboard.focus.ready": "Ready",
        "dashboard.focus.paused": "Paused",
        "dashboard.focus.start": "Start",
        "dashboard.focus.pause": "Pause",
        "dashboard.focus.reset": "Reset",
        "dashboard.focus.minutes": "Minutes"
    })

    Component {
        id: engineComponent

        TimerEngine {}
    }

    Component {
        id: buttonComponent

        PomodoroButton {
            width: 80
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        PomodoroPanel {
            width: 360
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    function test_a_fresh_session_is_not_active() {
        var fresh = Timers.pomodoro(25, 5, 4)
        compare(Pomodoro.active(fresh, 0), false)
        compare(Pomodoro.face(fresh, Timers.timer(10), 0).active, false)
    }

    function test_a_running_countdown_is_the_bar_text() {
        var started = Timers.start(Timers.pomodoro(25, 5, 4), 1000000)
        var face = Pomodoro.face(started, Timers.timer(10), 1060000)
        compare(face.active, true)
        compare(face.text, "24:00")
        compare(face.phase, "work")
        compare(Pomodoro.tooltipText(face, testCase.strings), "24:00 left · Work")
    }

    function test_a_paused_countdown_keeps_its_time_and_stays_active() {
        var started = Timers.start(Timers.pomodoro(25, 5, 4), 1000000)
        var paused = Timers.pause(started, 1060000)
        var face = Pomodoro.face(paused, Timers.timer(10), 5000000)
        compare(face.active, true)
        compare(face.text, "24:00")
        compare(Pomodoro.tooltipText(face, testCase.strings), "24:00 left · Work")
    }

    function test_a_finished_timer_is_not_active() {
        var state = Timers.timer(5)
        state.done = true
        state.left = 0
        compare(Pomodoro.active(state, 0), false)
    }

    function test_the_round_is_the_second_tooltip_line() {
        var state = Timers.pomodoro(25, 5, 4)
        state.completed = 1
        state = Timers.start(state, 0)
        var face = Pomodoro.face(state, Timers.timer(10), 0)
        compare(face.round, 2)
        compare(Pomodoro.detailText(face, testCase.strings), "Round 2 of 4")
        state.phase = "rest"
        compare(Pomodoro.face(state, Timers.timer(10), 0).round, 1)
    }

    function test_the_quick_timers_are_five_ten_and_twentyfive() {
        compare(Pomodoro.QUICK, [5, 10, 25])
        var quick = Timers.start(Timers.timer(5), 0)
        var face = Pomodoro.face(null, quick, 0)
        compare(face.kind, "timer")
        compare(face.text, "05:00")
        compare(Pomodoro.detailText(face, testCase.strings), "5 min timer")
        compare(Pomodoro.tooltipText(face, testCase.strings), "05:00 left · Quick timer")
    }

    function test_the_running_timer_wins_over_a_paused_pomodoro() {
        var paused = Timers.pause(Timers.start(Timers.pomodoro(25, 5, 4), 0), 1000)
        var quick = Timers.start(Timers.timer(10), 0)
        compare(Pomodoro.face(paused, quick, 0).kind, "timer")
        compare(Pomodoro.face(paused, Timers.timer(10), 0).kind, "pomodoro")
    }

    function test_the_button_writes_the_countdown() {
        var engine = make(engineComponent)
        var button = createTemporaryObject(buttonComponent, testCase, { engine: engine })
        verify(button !== null)
        compare(button.active, false)
        compare(button.text, "")

        engine.pomodoro = Timers.start(Timers.pomodoro(25, 5, 4), 1000000)
        engine.now = 1060000
        compare(button.active, true)
        compare(button.text, "24:00")
        compare(button.tooltip, "24:00 left · Work")
        compare(button.tooltipDetail, "Round 1 of 4")
    }

    function test_the_panel_quick_timer_starts_the_shared_engine() {
        var engine = make(engineComponent)
        var panel = createTemporaryObject(panelComponent, testCase, { engine: engine })
        verify(panel !== null)
        var quick = findChild(panel, "pomodoroQuick5")
        verify(quick !== null)
        mouseClick(quick, quick.width / 2, quick.height / 2)
        compare(engine.timer.running, true)
        compare(engine.timer.minutes, 5)
    }

    function test_the_panel_gear_asks_for_settings() {
        var engine = make(engineComponent)
        var panel = createTemporaryObject(panelComponent, testCase, { engine: engine })
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }
}
