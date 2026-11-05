// The pomodoro and the timer: their clock arithmetic, their phases and what a
// reload must remember. Pure, so they are tested without a window or a process
// (tests/qml/tst_timers.qml).
//
// A state is one JSON object, which is also what misc.ini keeps:
//
//   pomodoro: { kind, phase: "work"|"rest", running, end, left, duration,
//               completed, work, rest, cycles, done }
//   timer:    { kind: "timer", running, end, left, duration, minutes, done }
//
// `end` is when the running phase ends (epoch ms; 0 while paused), `left` the
// seconds it still had when it was paused, `duration` how long the phase lasts
// and `completed` how many work rounds are done. Seconds everywhere, except
// `end`.
.pragma library

var BOUNDS = {
    work: { min: 1, max: 120, value: 25 },
    rest: { min: 1, max: 60, value: 5 },
    cycles: { min: 1, max: 12, value: 4 },
    minutes: { min: 1, max: 180, value: 10 }
}

function clamp(value, bounds, fallback) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        number = fallback
    return Math.max(bounds.min, Math.min(bounds.max, number))
}

function pad(number) {
    return (number < 10 ? "0" : "") + number
}

// Seconds a person reads: 65 -> "01:05", 3661 -> "1:01:01".
function format(total) {
    var value = Number(total)
    if (!isFinite(value) || value < 0)
        value = 0
    var seconds = Math.floor(value)
    var hours = Math.floor(seconds / 3600)
    var minutes = Math.floor((seconds % 3600) / 60)
    var rest = seconds % 60
    return (hours > 0 ? hours + ":" + pad(minutes) : pad(minutes)) + ":" + pad(rest)
}

// The seconds still to go until `end`, rounded up so the last one shows "00:01".
function remaining(end, now) {
    var until = Number(end)
    var moment = Number(now)
    if (!isFinite(until) || !isFinite(moment) || until <= 0)
        return 0
    return Math.max(0, Math.ceil((until - moment) / 1000))
}

function copy(state) {
    var next = {}
    for (var key in state)
        next[key] = state[key]
    return next
}

function pomodoro(work, rest, cycles) {
    var workMinutes = clamp(work, BOUNDS.work, BOUNDS.work.value)
    var restMinutes = clamp(rest, BOUNDS.rest, BOUNDS.rest.value)
    var rounds = clamp(cycles, BOUNDS.cycles, BOUNDS.cycles.value)
    return {
        kind: "pomodoro",
        phase: "work",
        running: false,
        end: 0,
        left: workMinutes * 60,
        duration: workMinutes * 60,
        completed: 0,
        work: workMinutes,
        rest: restMinutes,
        cycles: rounds,
        done: false
    }
}

function timer(minutes) {
    var length = clamp(minutes, BOUNDS.minutes, BOUNDS.minutes.value)
    return {
        kind: "timer",
        running: false,
        end: 0,
        left: length * 60,
        duration: length * 60,
        minutes: length,
        done: false
    }
}

function reset(state) {
    if (!state || state.kind === "timer")
        return timer(state ? state.minutes : BOUNDS.minutes.value)
    return pomodoro(state.work, state.rest, state.cycles)
}

// Start, or resume from what a pause left. A finished session starts over.
function start(state, now) {
    var next = state && state.done ? reset(state) : copy(state || {})
    if (next.running)
        return next
    if (!(next.left > 0))
        next.left = next.duration
    if (!(next.left > 0))
        return next
    next.end = Math.round(Number(now) || 0) + next.left * 1000
    next.running = true
    next.done = false
    return next
}

function pause(state, now) {
    var next = copy(state)
    if (!next.running)
        return next
    next.left = remaining(next.end, now)
    next.end = 0
    next.running = false
    return next
}

// The phase that just ended, if it did: `{ state, finished }`, where
// `finished` is "work", "rest" or "timer" ("" when nothing ended).
function update(state, now) {
    if (!state || !state.running)
        return { state: state, finished: "" }
    if (remaining(state.end, now) > 0)
        return { state: state, finished: "" }

    var next = copy(state)
    var at = Number(state.end) || Number(now) || 0

    if (next.kind === "timer") {
        next.left = 0
        next.end = 0
        next.running = false
        next.done = true
        return { state: next, finished: "timer" }
    }

    if (next.phase === "work") {
        next.completed = Math.min(next.cycles, next.completed + 1)
        if (next.completed >= next.cycles) {
            next.left = 0
            next.end = 0
            next.running = false
            next.done = true
            return { state: next, finished: "work" }
        }
        next.phase = "rest"
        next.duration = next.rest * 60
        next.left = next.duration
        next.end = at + next.duration * 1000
        return { state: next, finished: "work" }
    }

    next.phase = "work"
    next.duration = next.work * 60
    next.left = next.duration
    next.end = at + next.duration * 1000
    return { state: next, finished: "rest" }
}

// Every phase the clock crossed, for a bar that was away: the state after them
// and the last phase that ended. Bounded, so a broken end cannot spin.
function catchUp(state, now, limit) {
    var steps = limit || 500
    var last = ""
    var current = state
    while (steps-- > 0) {
        var result = update(current, now)
        if (result.finished === "") {
            current = result.state
            break
        }
        current = result.state
        last = result.finished
    }
    return { state: current, finished: last }
}

// How much of the phase is gone: 0 at its start, 1 at its end.
function progress(state, now) {
    if (!state || !(state.duration > 0))
        return 0
    var left = state.running ? remaining(state.end, now) : state.left
    return Math.max(0, Math.min(1, 1 - left / state.duration))
}

// The round on screen: the one just finished during the break, the one running
// during work.
function round(state) {
    if (!state || state.kind !== "pomodoro")
        return 0
    var number = state.phase === "work" && !state.done ? state.completed + 1 : state.completed
    return Math.max(1, Math.min(state.cycles, number))
}

function text(state) {
    return JSON.stringify(state)
}

// What misc.ini kept, made safe to run again. Anything unreadable becomes a
// fresh session of that kind.
function parse(value, kind, fallback) {
    var document = null
    try {
        document = JSON.parse(String(value || ""))
    } catch (error) {
        return kind === "timer" ? timer(fallback) : pomodoro(fallback)
    }
    if (!document || typeof document !== "object" || document.kind !== kind)
        return kind === "timer" ? timer(fallback) : pomodoro(fallback)

    if (kind === "timer") {
        var length = clamp(document.minutes, BOUNDS.minutes, BOUNDS.minutes.value)
        var state = timer(length)
        state.running = document.running === true
        state.done = document.done === true
        state.end = state.running ? Math.max(0, Number(document.end) || 0) : 0
        state.duration = Math.max(0, Math.min(BOUNDS.minutes.max * 60, Number(document.duration) || state.duration))
        state.left = Math.max(0, Math.min(state.duration, Number(document.left) || 0))
        if (state.running && state.end <= 0)
            state.running = false
        if (!state.running && !state.done && state.left <= 0)
            state.left = state.duration
        return state
    }

    var next = pomodoro(document.work, document.rest, document.cycles)
    next.phase = document.phase === "rest" ? "rest" : "work"
    next.completed = clamp(document.completed, { min: 0, max: next.cycles, value: 0 }, 0)
    next.done = document.done === true
    next.running = document.running === true
    next.duration = Math.max(0, Math.min(BOUNDS.work.max * 60,
                                         Number(document.duration) || (next.phase === "work" ? next.work * 60 : next.rest * 60)))
    next.left = Math.max(0, Math.min(next.duration, Number(document.left) || 0))
    next.end = next.running ? Math.max(0, Number(document.end) || 0) : 0
    if (next.running && next.end <= 0)
        next.running = false
    if (!next.running && !next.done && next.left <= 0)
        next.left = next.duration
    return next
}
