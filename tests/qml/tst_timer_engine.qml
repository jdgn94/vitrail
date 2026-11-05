import QtQuick
import QtTest
import "../../bar/dashboard"
import "../../bar/dashboard/timers.js" as Timers

// The engine the bar keeps running: it ticks while the popup is closed, says
// when a phase ends and hands the state to misc.ini.
TestCase {
    id: testCase

    name: "TimerEngine"
    when: windowShown

    Component {
        id: control

        TimerEngine {}
    }

    SignalSpy {
        id: finished

        signalName: "finished"
    }

    SignalSpy {
        id: persisted

        signalName: "persist"
    }

    function make(props) {
        var engine = createTemporaryObject(control, testCase, props || {})
        verify(engine)
        finished.target = engine
        finished.clear()
        persisted.target = engine
        persisted.clear()
        return engine
    }

    function test_a_fresh_engine_has_the_two_idle_sessions() {
        var engine = make({ workMinutes: 25, restMinutes: 5, cycles: 4, timerMinutes: 10 })
        compare(engine.pomodoro.phase, "work")
        compare(engine.pomodoro.left, 1500)
        compare(engine.pomodoro.running, false)
        compare(engine.timer.left, 600)
        compare(engine.timer.running, false)
    }

    function test_it_starts_pauses_and_resets_the_pomodoro() {
        var engine = make()
        engine.startPomodoro()
        compare(engine.pomodoro.running, true)
        compare(persisted.count, 2)

        var started = Timers.parse(persisted.signalArguments[0][1], "pomodoro", 25)
        compare(started.running, true)
        compare(started.end, engine.pomodoro.end)

        engine.pausePomodoro()
        compare(engine.pomodoro.running, false)
        compare(engine.pomodoro.end, 0)
        engine.resetPomodoro()
        compare(engine.pomodoro.left, 1500)
        compare(engine.pomodoro.completed, 0)
    }

    function test_a_finished_phase_is_announced_and_stored() {
        var engine = make({ now: 0 })
        engine.startTimer(1)
        finished.clear()
        persisted.clear()
        engine.tick(engine.timer.end)
        compare(finished.count, 1)
        compare(finished.signalArguments[0][0], "timer")
        compare(finished.signalArguments[0][1], "timer")
        compare(engine.timer.done, true)
        compare(persisted.count, 2)
        var kept = Timers.parse(persisted.signalArguments[1][1], "timer", 10)
        compare(kept.done, true)
        compare(kept.running, false)
    }

    function test_a_pomodoro_awards_a_break_and_announces_it() {
        var engine = make({ now: 0 })
        engine.startPomodoro()
        finished.clear()
        engine.tick(engine.pomodoro.end)
        compare(finished.count, 1)
        compare(finished.signalArguments[0][0], "pomodoro")
        compare(finished.signalArguments[0][1], "work")
        compare(engine.pomodoro.phase, "rest")
        compare(engine.pomodoro.completed, 1)
        compare(engine.pomodoro.running, true)
    }

    function test_a_saved_running_timer_continues_after_a_reload() {
        var running = Timers.start(Timers.timer(10), 1000)
        var engine = make({ now: 61000, savedTimer: Timers.text(running) })
        engine.restore()
        compare(engine.timer.running, true)
        compare(engine.timer.end, running.end)
        compare(Timers.remaining(engine.timer.end, 61000), 540)
    }

    function test_a_saved_timer_that_ended_meanwhile_is_finished_once() {
        var running = Timers.start(Timers.timer(1), 1000)
        var engine = make({ now: 120000, savedTimer: Timers.text(running) })
        finished.clear()
        engine.restore()
        compare(engine.timer.done, true)
        compare(engine.timer.running, false)
        compare(finished.count, 1)
        compare(finished.signalArguments[0][0], "timer")
    }

    function test_a_paused_session_survives_the_reload() {
        var paused = Timers.pause(Timers.start(Timers.timer(10), 0), 60000)
        var engine = make({ now: 900000, savedTimer: Timers.text(paused) })
        engine.restore()
        compare(engine.timer.running, false)
        compare(engine.timer.left, 540)
        compare(engine.timer.done, false)
    }

    function test_the_timer_field_sets_and_stores_the_length() {
        var engine = make()
        engine.setTimerMinutes(0)
        compare(engine.timerMinutes, 1)
        compare(persisted.signalArguments[0][0], "timerMinutes")
        compare(persisted.signalArguments[0][1], "1")
        engine.setTimerMinutes(42)
        compare(engine.timer.minutes, 42)
        compare(engine.timer.left, 42 * 60)
        compare(engine.timer.running, false)
    }

    function test_the_timer_button_resumes_before_it_restarts() {
        var engine = make()
        engine.startTimer(5)
        engine.pauseTimer()
        var kept = engine.timer.left
        engine.toggleTimer(5)
        compare(engine.timer.running, true)
        compare(Timers.remaining(engine.timer.end, Date.now()) <= kept, true)
    }

    function test_a_finished_timer_starts_over_from_the_button() {
        var engine = make({ now: 0 })
        engine.startTimer(1)
        engine.tick(engine.timer.end)
        compare(engine.timer.done, true)
        engine.toggleTimer(2)
        compare(engine.timer.done, false)
        compare(engine.timer.running, true)
        compare(engine.timer.duration, 120)
    }
}
