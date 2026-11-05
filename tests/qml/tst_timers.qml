import QtQuick
import QtTest
import "../../bar/dashboard/timers.js" as Timers

// The pomodoro and the timer: formatting, the remaining time, the phases and
// what misc.ini keeps across a reload.
TestCase {
    name: "Timers"

    function test_the_time_is_formatted_for_a_person() {
        compare(Timers.format(0), "00:00")
        compare(Timers.format(9), "00:09")
        compare(Timers.format(65), "01:05")
        compare(Timers.format(25 * 60), "25:00")
        compare(Timers.format(3600), "1:00:00")
        compare(Timers.format(3661), "1:01:01")
        compare(Timers.format(-4), "00:00")
        compare(Timers.format(undefined), "00:00")
    }

    function test_the_remaining_time_is_rounded_up_and_never_negative() {
        compare(Timers.remaining(10000, 1000), 9)
        compare(Timers.remaining(10000, 9500), 1)
        compare(Timers.remaining(10000, 10000), 0)
        compare(Timers.remaining(10000, 20000), 0)
        compare(Timers.remaining(0, 20000), 0)
    }

    function test_a_timer_starts_pauses_and_resumes() {
        var timer = Timers.timer(10)
        compare(timer.duration, 600)
        compare(timer.left, 600)
        compare(timer.running, false)

        var running = Timers.start(timer, 1000)
        compare(running.running, true)
        compare(running.end, 601000)
        compare(Timers.remaining(running.end, 31000), 570)

        var paused = Timers.pause(running, 31000)
        compare(paused.running, false)
        compare(paused.end, 0)
        compare(paused.left, 570)
        compare(Timers.remaining(paused.end, 99999), 0)

        var resumed = Timers.start(paused, 60000)
        compare(resumed.running, true)
        compare(resumed.end, 630000)
    }

    function test_a_timer_finishes_once() {
        var running = Timers.start(Timers.timer(1), 0)
        var result = Timers.update(running, 59000)
        compare(result.finished, "")
        compare(result.state.running, true)
        result = Timers.update(running, 60000)
        compare(result.finished, "timer")
        compare(result.state.running, false)
        compare(result.state.done, true)
        compare(result.state.left, 0)
        compare(Timers.update(result.state, 90000).finished, "")
    }

    function test_a_finished_timer_starts_over() {
        var finished = Timers.update(Timers.start(Timers.timer(5), 0), 300000).state
        compare(finished.done, true)
        var again = Timers.start(finished, 400000)
        compare(again.done, false)
        compare(again.running, true)
        compare(again.left, 300)
        compare(again.end, 700000)
    }

    function test_a_pomodoro_goes_from_work_to_rest() {
        var session = Timers.pomodoro(25, 5, 4)
        compare(session.phase, "work")
        compare(session.left, 1500)

        var working = Timers.start(session, 0)
        var result = Timers.update(working, 1500000)
        compare(result.finished, "work")
        compare(result.state.phase, "rest")
        compare(result.state.completed, 1)
        compare(result.state.duration, 300)
        compare(result.state.running, true)
        // The break starts where the work ended, not when the tick noticed.
        compare(result.state.end, 1800000)
    }

    function test_the_last_round_ends_the_session() {
        var session = Timers.pomodoro(25, 5, 1)
        var result = Timers.update(Timers.start(session, 0), 1500000)
        compare(result.finished, "work")
        compare(result.state.phase, "work")
        compare(result.state.running, false)
        compare(result.state.done, true)
        compare(result.state.completed, 1)
    }

    function test_a_break_returns_to_work() {
        var session = Timers.pomodoro(25, 5, 4)
        session = Timers.update(Timers.start(session, 0), 1500000).state
        compare(session.phase, "rest")
        var result = Timers.update(session, 1800000)
        compare(result.finished, "rest")
        compare(result.state.phase, "work")
        compare(result.state.running, true)
        compare(result.state.duration, 1500)
        compare(result.state.end, 3300000)
    }

    function test_a_reload_catches_up_with_every_phase_it_missed() {
        var session = Timers.start(Timers.pomodoro(25, 5, 4), 0)
        // Two full rounds and a work period later.
        var caught = Timers.catchUp(session, 2 * 1800000 + 1500000)
        compare(caught.finished, "work")
        compare(caught.state.phase, "rest")
        compare(caught.state.completed, 3)
        compare(caught.state.running, true)
    }

    function test_the_progress_follows_the_phase() {
        var session = Timers.start(Timers.pomodoro(10, 5, 4), 0)
        compare(Timers.progress(session, 0), 0)
        compare(Timers.progress(session, 300000), 0.5)
        compare(Timers.progress(session, 600000), 1)
        var paused = Timers.pause(session, 300000)
        compare(Timers.progress(paused, 900000), 0.5)
    }

    function test_the_round_is_the_one_on_screen() {
        var session = Timers.pomodoro(25, 5, 4)
        compare(Timers.round(session), 1)
        session = Timers.update(Timers.start(session, 0), 1500000).state
        compare(Timers.round(session), 1)
        session = Timers.update(session, session.end).state
        compare(Timers.round(session), 2)
    }

    function test_a_running_state_survives_a_reload() {
        var running = Timers.start(Timers.pomodoro(25, 5, 4), 1000)
        var kept = Timers.parse(Timers.text(running), "pomodoro", 25)
        compare(kept.running, true)
        compare(kept.end, running.end)
        compare(kept.work, 25)
        compare(kept.rest, 5)
        compare(kept.cycles, 4)
        compare(Timers.remaining(kept.end, 61000), 1440)

        var timer = Timers.start(Timers.timer(12), 1000)
        var keptTimer = Timers.parse(Timers.text(timer), "timer", 10)
        compare(keptTimer.running, true)
        compare(keptTimer.duration, 720)
        compare(keptTimer.end, timer.end)
    }

    function test_a_paused_state_survives_a_reload() {
        var paused = Timers.pause(Timers.start(Timers.timer(10), 0), 60000)
        var kept = Timers.parse(Timers.text(paused), "timer", 10)
        compare(kept.running, false)
        compare(kept.end, 0)
        compare(kept.left, 540)
        compare(Timers.format(kept.left), "09:00")
    }

    function test_a_broken_or_mismatched_state_starts_fresh() {
        var fresh = Timers.parse("not json", "timer", 7)
        compare(fresh.kind, "timer")
        compare(fresh.minutes, 7)
        compare(fresh.running, false)

        compare(Timers.parse("", "pomodoro", 25).left, 1500)
        compare(Timers.parse('{"kind":"pomodoro"}', "timer", 10).kind, "timer")
        compare(Timers.parse('{"kind":"timer","minutes":999}', "timer", 10).minutes, 180)
        compare(Timers.parse('{"kind":"timer","running":true,"end":0}', "timer", 10).running, false)
    }

    function test_the_clamped_settings_stay_in_their_range() {
        compare(Timers.clamp(0, Timers.BOUNDS.work, 25), 1)
        compare(Timers.clamp(500, Timers.BOUNDS.work, 25), 120)
        compare(Timers.clamp("nope", Timers.BOUNDS.rest, 5), 5)
        compare(Timers.timer(0).minutes, 1)
        compare(Timers.pomodoro(999, 0, 99).cycles, 12)
    }
}
