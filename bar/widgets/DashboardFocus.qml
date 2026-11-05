import QtQuick
import "../dashboard/timers.js" as Timers

// One of the dashboard's two clock widgets (the pomodoro or the free timer).
// It owns the wording and the arithmetic and draws the shared FocusWidget, so
// the desktop uses exactly the same card; the shell's TimerEngine holds the
// running state.
FocusWidget {
    id: root

    property var engine: null
    // "pomodoro" or "timer".
    property string kind: "pomodoro"
    property var strings: ({})
    property real now: Date.now()

    readonly property var timerState: root.engine
                                      ? (root.kind === "pomodoro" ? root.engine.pomodoro : root.engine.timer)
                                      : null
    readonly property real remainingSeconds: {
        if (!root.timerState)
            return 0
        return root.timerState.running ? Timers.remaining(root.timerState.end, root.now)
                                       : root.timerState.left
    }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function phaseText() {
        if (!root.timerState)
            return ""
        if (root.timerState.done)
            return root.t("dashboard.focus.done")
        if (root.kind === "timer") {
            if (root.timerState.running)
                return root.t("dashboard.focus.timer")
            if (root.timerState.left > 0 && root.timerState.left < root.timerState.duration)
                return root.t("dashboard.focus.paused")
            return root.t("dashboard.focus.ready")
        }
        var phase = root.timerState.phase === "work" ? root.t("dashboard.focus.work")
                                                     : root.t("dashboard.focus.rest")
        return phase + " · " + root.t("dashboard.focus.round") + " "
               + Timers.round(root.timerState) + "/" + root.timerState.cycles
    }

    title: root.kind === "pomodoro" ? root.t("dashboard.focus.pomodoro")
                                    : root.t("dashboard.focus.timer")
    name: root.kind
    phase: root.phaseText()
    remaining: Timers.format(root.remainingSeconds)
    progress: root.timerState ? Timers.progress(root.timerState, root.now) : 0
    running: root.timerState ? root.timerState.running : false
    done: root.timerState ? root.timerState.done : false
    startText: root.t("dashboard.focus.start")
    pauseText: root.t("dashboard.focus.pause")
    resetText: root.t("dashboard.focus.reset")
    editableMinutes: root.kind === "timer"
    minutes: root.timerState && root.timerState.minutes !== undefined
             ? root.timerState.minutes
             : (root.engine ? root.engine.timerMinutes : 10)
    minutesLabel: root.t("dashboard.focus.minutes")

    onStartRequested: {
        if (!root.engine)
            return
        if (root.kind === "pomodoro")
            root.engine.togglePomodoro()
        else
            root.engine.toggleTimer(root.timerState ? root.timerState.minutes : root.engine.timerMinutes)
    }
    onPauseRequested: {
        if (!root.engine)
            return
        if (root.kind === "pomodoro")
            root.engine.pausePomodoro()
        else
            root.engine.pauseTimer()
    }
    onResetRequested: {
        if (!root.engine)
            return
        if (root.kind === "pomodoro")
            root.engine.resetPomodoro()
        else
            root.engine.resetTimer()
    }
    onMinutesEdited: function (value) {
        if (root.engine)
            root.engine.setTimerMinutes(value)
    }
}
