// The pomodoro bar element's plain logic: which countdown the bar shows, when
// it is active, and the words of its tooltip. The clock itself is the shell's
// TimerEngine and timers.js (never a second timer here), so this file only
// reads the states the dashboard already keeps. Pure, tested in
// tests/qml/tst_pomodoro.qml.
.pragma library
.import "../dashboard/timers.js" as Timers

// The quick timers the popup offers, in minutes.
var QUICK = [5, 10, 25]

function remaining(state, now) {
    if (!state)
        return 0
    return state.running ? Timers.remaining(state.end, now)
                         : Math.max(0, Number(state.left) || 0)
}

// "A timer is running or paused with time left": a fresh session (still at its
// full duration) and a finished one (done) are not active.
function active(state, now) {
    if (!state)
        return false
    if (state.running)
        return remaining(state, now) > 0
    return state.done !== true && state.left > 0 && state.left < state.duration
}

// The countdown the bar shows: a running one wins, then the pomodoro, then a
// paused quick timer. Null when neither has time left.
function pick(pomodoro, timer, now) {
    if (timer && timer.running && active(timer, now))
        return { kind: "timer", state: timer }
    if (pomodoro && pomodoro.running && active(pomodoro, now))
        return { kind: "pomodoro", state: pomodoro }
    if (active(pomodoro, now))
        return { kind: "pomodoro", state: pomodoro }
    if (active(timer, now))
        return { kind: "timer", state: timer }
    return null
}

// What the button draws: the seconds left as mm:ss, the phase ("work", "rest"
// or "timer") and, for the pomodoro, the round the phase belongs to.
function face(pomodoro, timer, now) {
    var chosen = pick(pomodoro, timer, now)
    if (!chosen) {
        return { active: false, kind: "", text: "", progress: 0,
                 phase: "", round: 0, cycles: 0, minutes: 0 }
    }
    var state = chosen.state
    var left = remaining(state, now)
    return {
        active: left > 0,
        kind: chosen.kind,
        text: Timers.format(left),
        progress: Timers.progress(state, now),
        phase: chosen.kind === "timer" ? "timer" : (state.phase === "rest" ? "rest" : "work"),
        round: chosen.kind === "pomodoro" ? Timers.round(state) : 0,
        cycles: chosen.kind === "pomodoro" ? state.cycles : 0,
        minutes: chosen.kind === "timer" ? state.minutes : 0
    }
}

// The button's second tooltip line: the cycle count for a pomodoro, the length
// of a quick timer.
function detailText(face, strings) {
    if (!face || !face.active)
        return ""
    var words = strings || ({})
    if (face.kind === "timer")
        return (words["bar.pomodoro.timer.detail"] || "%1 min timer").replace("%1", face.minutes)
    return (words["bar.pomodoro.cycles"] || "Round %1 of %2")
        .replace("%1", face.round).replace("%2", face.cycles)
}

// The tooltip: the remaining time and the phase.
function tooltipText(face, strings) {
    var words = strings || ({})
    if (!face || !face.active)
        return words["bar.pomodoro.none"] || "No timer running"
    return (words["bar.pomodoro.tooltip"] || "%1 left · %2")
        .replace("%1", face.text)
        .replace("%2", words["bar.pomodoro.phase." + face.phase] || face.phase)
}
