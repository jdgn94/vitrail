import QtQuick
import "groups.js" as Groups

// The notification centre and the cards on screen.
//
// `history` is the panel's list: every notification that arrived, newest
// first, up to `limit`. Each row is a snapshot (summary, body, app, time), so
// it outlives the notification object when its toast expires. `shown` is what
// the stack draws: at most `maximum` cards, the rest wait in `waiting` and take
// the first slot that frees up.
//
// While the panel is open (`quiet`) an arrival joins `history` only: the list
// animates it in and it is never raised as a toast, now or when the panel
// closes. Opening the panel also clears the cards on screen, so nothing pops
// up behind it.
//
// Closing a notification has two meanings: Expired (0) only ran out of time on
// screen, so the row stays in the list; Dismissed (1) or CloseRequested (2)
// means the user or the app is done with it, so the row goes.
QtObject {
    id: root

    property int maximum: 5
    // How many notifications the panel keeps; the oldest falls off.
    property int limit: 50
    // The panel is open: arrivals are listed, not toasted.
    property bool quiet: false

    // { nid, summary, body, appName, icon, image, arrived, expired } rows.
    property ListModel history: ListModel {}
    // { nid } rows; `byId` resolves the live notifications.
    property ListModel shown: ListModel {}
    property var waiting: []
    property var byId: ({})
    // When each one arrived (ms), for the "5 min" next to its title.
    property var arrived: ({})
    // Ids whose card ran out of time (see expire()).
    property var expiring: ({})

    onMaximumChanged: root.pump()

    // The panel takes over: the cards on screen go away, their rows stay.
    onQuietChanged: if (root.quiet) {
        root.shown.clear()
        root.waiting = []
    }

    function push(notification) {
        if (root.byId[notification.id])
            return
        root.byId[notification.id] = notification
        root.arrived[notification.id] = Date.now()
        notification.closed.connect(function (reason) { root.closed(notification.id, reason) })
        root.removeFrom(root.history, notification.id)
        root.history.insert(0, {
            nid: notification.id,
            summary: notification.summary || "",
            body: notification.body || "",
            appName: notification.appName || "",
            // The icon the card resolves: the app's own, else its entry, and a
            // notification image as the last resort.
            icon: notification.appIcon || notification.desktopEntry || "",
            image: notification.image || "",
            arrived: root.arrived[notification.id],
            expired: false
        })
        while (root.history.count > root.limit)
            root.history.remove(root.history.count - 1)
        if (root.quiet)
            return
        root.waiting.push(notification.id)
        root.pump()
    }

    function closed(id, reason) {
        // expire() reports the same reason as a dismiss, so the intent is
        // remembered here: only a card that ran out of time keeps its row.
        var ranOut = root.expiring[id] === true
        delete root.expiring[id]
        delete root.byId[id]
        delete root.arrived[id]
        var at = root.waiting.indexOf(id)
        if (at >= 0)
            root.waiting.splice(at, 1)
        root.removeFrom(root.shown, id)
        if (ranOut)
            root.markExpired(id)
        else
            root.removeFrom(root.history, id)
        root.pump()
    }

    function markExpired(id) {
        for (var i = 0; i < root.history.count; i++) {
            if (root.history.get(i).nid === id) {
                root.history.setProperty(i, "expired", true)
                return
            }
        }
    }

    // The panel's close button: a live notification is dismissed (which
    // removes its row), an expired one only loses the row.
    function dismiss(id) {
        var note = root.byId[id]
        if (note)
            note.dismiss()
        else
            root.forget(id)
    }

    // The card of `id` ran out of time on screen: the notification is expired
    // but its row stays in the panel.
    function expire(id) {
        if (!root.byId[id])
            return
        root.expiring[id] = true
        root.byId[id].expire()
    }

    function forget(id) {
        delete root.expiring[id]
        delete root.byId[id]
        delete root.arrived[id]
        var at = root.waiting.indexOf(id)
        if (at >= 0)
            root.waiting.splice(at, 1)
        root.removeFrom(root.shown, id)
        root.removeFrom(root.history, id)
        root.pump()
    }

    function clear() {
        var ids = []
        for (var i = 0; i < root.history.count; i++)
            ids.push(root.history.get(i).nid)
        for (var j = 0; j < ids.length; j++)
            root.dismiss(ids[j])
    }

    // The group's clear button: every notification of one app, live or expired.
    function clearGroup(key) {
        var ids = []
        for (var i = 0; i < root.history.count; i++) {
            var row = root.history.get(i)
            if (Groups.groupKey(row) === key)
                ids.push(row.nid)
        }
        for (var j = 0; j < ids.length; j++)
            root.dismiss(ids[j])
    }

    function removeFrom(model, id) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).nid === id) {
                model.remove(i)
                return
            }
        }
    }

    function pump() {
        while (root.shown.count < root.maximum && root.waiting.length > 0)
            root.shown.insert(0, { nid: root.waiting.shift() })
    }
}
