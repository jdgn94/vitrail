import QtQuick
import "timers.js" as Timers

// The clock behind the dashboard's two widgets. It lives in the shell, not in
// the popup, so a running session keeps counting while the popup is closed and
// comes back after a reload from the state misc.ini kept (end time included).
// The arithmetic itself is in timers.js; this only ticks, remembers and says
// when a phase is over.
Item {
    id: root

    // The settings the settings window writes (bar.ini).
    property int workMinutes: 25
    property int restMinutes: 5
    property int cycles: 4
    property int timerMinutes: 10
    // What misc.ini kept, as the JSON text timers.js writes.
    property string savedPomodoro: ""
    property string savedTimer: ""
    // The moment the last tick ran; a test sets it to a fixed time.
    property real now: Date.now()

    property var pomodoro: Timers.pomodoro(root.workMinutes, root.restMinutes, root.cycles)
    property var timer: Timers.timer(root.timerMinutes)
    // The saved state was read, or the user has taken the engine over.
    property bool restored: false

    // A phase ended: "work"/"rest" for the pomodoro, "timer" for the timer.
    signal finished(string kind, string phase)
    // A preference to write: the state after every change, or the length the
    // timer field just asked for.
    signal persist(string key, string value)

    implicitWidth: 0
    implicitHeight: 0

    Component.onCompleted: restoreSoon.start()
    onSavedPomodoroChanged: if (!root.restored) restoreSoon.start()
    onSavedTimerChanged: if (!root.restored) restoreSoon.start()

    // Both saved values arrive with the preference files; one short delay lets
    // the last of them land before either is read.
    Timer {
        id: restoreSoon

        interval: 0
        onTriggered: root.restore()
    }

    // One second while anything runs; the end times carry the rest.
    Timer {
        interval: 1000
        repeat: true
        running: root.pomodoro.running || root.timer.running
        onTriggered: root.tick()
    }

    onWorkMinutesChanged: root.refreshPomodoro()
    onRestMinutesChanged: root.refreshPomodoro()
    onCyclesChanged: root.refreshPomodoro()
    onTimerMinutesChanged: root.refreshTimer()

    function restore() {
        if (root.restored)
            return
        if (root.savedPomodoro === "" && root.savedTimer === "")
            return
        root.restored = true
        if (root.savedPomodoro !== "")
            root.pomodoro = Timers.parse(root.savedPomodoro, "pomodoro", root.workMinutes)
        if (root.savedTimer !== "")
            root.timer = Timers.parse(root.savedTimer, "timer", root.timerMinutes)
        root.catchUp()
    }

    // The bar was away: finish every phase the clock crossed, and say once
    // which one ended. A session that is over stays over.
    function catchUp() {
        var moment = root.now > 0 ? root.now : Date.now()
        var work = Timers.catchUp(root.pomodoro, moment)
        if (work.finished !== "") {
            root.pomodoro = work.state
            root.persistState()
            root.finished("pomodoro", work.finished)
        }
        var free = Timers.catchUp(root.timer, moment)
        if (free.finished !== "") {
            root.timer = free.state
            root.persistState()
            root.finished("timer", free.finished)
        }
    }

    function tick(at) {
        root.now = at === undefined ? Date.now() : at
        var last = ""
        var steps = 0
        while (steps++ < 500) {
            var result = Timers.update(root.pomodoro, root.now)
            if (result.finished === "")
                break
            root.pomodoro = result.state
            last = result.finished
        }
        if (last !== "") {
            root.persistState()
            root.finished("pomodoro", last)
        }

        var free = Timers.update(root.timer, root.now)
        if (free.finished !== "") {
            root.timer = free.state
            root.persistState()
            root.finished("timer", free.finished)
        }
    }

    function persistState() {
        root.persist("pomodoroState", Timers.text(root.pomodoro))
        root.persist("timerState", Timers.text(root.timer))
    }

    // A change the user made means the saved state has been taken over.
    function claim() {
        root.restored = true
    }

    function refreshPomodoro() {
        if (root.pomodoro && !root.pomodoro.running && !root.pomodoro.done
                && root.pomodoro.left === root.pomodoro.duration)
            root.pomodoro = Timers.pomodoro(root.workMinutes, root.restMinutes, root.cycles)
    }

    function refreshTimer() {
        if (root.timer && !root.timer.running && !root.timer.done)
            root.timer = Timers.timer(root.timerMinutes)
    }

    function startPomodoro() {
        root.claim()
        root.pomodoro = Timers.start(root.pomodoro, Date.now())
        root.persistState()
    }

    function pausePomodoro() {
        root.claim()
        root.pomodoro = Timers.pause(root.pomodoro, Date.now())
        root.persistState()
    }

    function togglePomodoro() {
        if (root.pomodoro.running)
            root.pausePomodoro()
        else
            root.startPomodoro()
    }

    function resetPomodoro() {
        root.claim()
        root.pomodoro = Timers.pomodoro(root.workMinutes, root.restMinutes, root.cycles)
        root.persistState()
    }

    function setTimerMinutes(value) {
        root.claim()
        root.timerMinutes = Timers.clamp(value, Timers.BOUNDS.minutes, Timers.BOUNDS.minutes.value)
        root.persist("timerMinutes", String(root.timerMinutes))
    }

    function startTimer(minutes) {
        root.claim()
        if (minutes !== undefined)
            root.setTimerMinutes(minutes)
        root.timer = Timers.start(Timers.timer(root.timerMinutes), Date.now())
        root.persistState()
    }

    function resumeTimer() {
        root.claim()
        root.timer = Timers.start(root.timer, Date.now())
        root.persistState()
    }

    function pauseTimer() {
        root.claim()
        root.timer = Timers.pause(root.timer, Date.now())
        root.persistState()
    }

    function resetTimer() {
        root.claim()
        root.timer = Timers.timer(root.timerMinutes)
        root.persistState()
    }

    // Start a fresh timer, resume a paused one, or pause a running one.
    function toggleTimer(minutes) {
        if (root.timer.running)
            root.pauseTimer()
        else if (!root.timer.done && root.timer.left > 0 && root.timer.left < root.timer.duration)
            root.resumeTimer()
        else
            root.startTimer(minutes)
    }
}
