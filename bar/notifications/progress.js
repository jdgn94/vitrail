// A notification that reports a long task (a download, an update, a job): the
// daemon puts the state in a hint and, when it knows the total, the percentage
// in `value`. A percentage is never invented: without `value` the bar shows an
// indeterminate bar. Tested in tests/qml/tst_download_progress.qml.
.pragma library

var STATE = "x-vitrail-state"

// "live", "cancelling", "busy", "done", "cancelled", "gone", "deleted"; "" for a
// plain notification.
function state(notification) {
    if (!notification || !notification.hints)
        return ""
    var value = notification.hints[STATE]
    return value === undefined || value === null ? "" : String(value)
}

// 0..100 when the daemon knows the total, -1 when it does not.
function percent(notification) {
    if (!notification || !notification.hints)
        return -1
    var value = notification.hints["value"]
    if (value === undefined || value === null)
        return -1
    var number = Math.round(Number(value))
    return isNaN(number) || number < 0 || number > 100 ? -1 : number
}

// The task is still going: its card stays, its bar is there.
function live(notification) {
    var found = state(notification)
    return found === "live" || found === "cancelling" || found === "busy"
}

// The action of a key ("cancel", "delete", "folder", "file"), or null.
function actionOf(actions, key) {
    if (!actions)
        return null
    for (var i = 0; i < actions.length; i++) {
        if (actions[i] && actions[i].identifier === key)
            return actions[i]
    }
    return null
}
