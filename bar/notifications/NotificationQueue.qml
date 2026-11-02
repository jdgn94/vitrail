import QtQuick
import "groups.js" as Groups
import "notifications.js" as Notifications

// The notification centre and the cards on screen.
//
// `history` is the panel's list: every notification that arrived, newest
// first, up to `limit`. Each row is a snapshot (summary, body, app, time), so
// it outlives the notification object when its toast expires — and the file
// `vitrail/notify.py` writes keeps it across a reload. `shown` is what the
// stack draws: at most `maximum` cards, the rest wait in `waiting` and take
// the first slot that frees up.
//
// While the panel is open (`panelOpen`) an arrival joins `history` only. Do Not
// Disturb (`dnd`) does the same, unless the notification is urgent and the
// bypass is on; a muted app is never toasted, whatever Do Not Disturb says.
//
// `stats` counts arrivals and acts per app and day: it outlives the row, so
// muting a noisy app can rely on what it did, not on what is on screen.
//
// Closing a notification has two meanings: Expired (0) only ran out of time on
// screen, so the row stays in the list; Dismissed (1) or CloseRequested (2)
// means the user or the app is done with it, so the row goes (and counts as
// acted on).
QtObject {
    id: root

    property int maximum: 5
    // How many notifications the panel keeps; the oldest falls off.
    property int limit: 300
    // The panel is open: arrivals are listed, not toasted.
    property bool panelOpen: false
    // Do Not Disturb, and whether an urgent notification still toasts.
    property bool dnd: false
    property bool urgentBypass: true
    // Comma-separated app names (see notifications.js).
    property string muted: ""
    property string urgent: ""

    // { nid, summary, body, appName, icon, image, arrived, expired,
    //   conversation, urgent, acted } rows.
    property ListModel history: ListModel {}
    // { nid } rows; `byId` resolves the live notifications.
    property ListModel shown: ListModel {}
    property var waiting: []
    property var byId: ({})
    // When each one arrived (ms), for the "5 min" next to its title.
    property var arrived: ({})
    // Ids whose card ran out of time (see expire()).
    property var expiring: ({})
    // {day: {app: [seen, acted]}} — the panel's summary and what the store keeps.
    property var stats: ({})
    // Bumped whenever what the store keeps changes (the shell writes it).
    property int revision: 0

    // A card was snoozed: the shell remembers it and wakes it at `until`.
    signal snoozed(var row, real until)

    function push(notification) {
        if (root.byId[notification.id])
            return
        var app = notification.appName || ""
        var isUrgent = Notifications.urgent(notification, root.urgent)
        root.byId[notification.id] = notification
        root.arrived[notification.id] = Date.now()
        notification.closed.connect(function (reason) { root.closed(notification.id, reason) })
        root.removeFrom(root.history, notification.id)
        root.history.insert(0, {
            nid: notification.id,
            summary: notification.summary || "",
            body: notification.body || "",
            appName: app,
            // The icon the card resolves: the app's own, else its entry, and a
            // notification image as the last resort.
            icon: notification.appIcon || notification.desktopEntry || "",
            image: notification.image || "",
            arrived: root.arrived[notification.id],
            expired: false,
            conversation: Notifications.conversation(notification),
            urgent: isUrgent,
            acted: false
        })
        while (root.history.count > root.limit)
            root.history.remove(root.history.count - 1)
        root.count(app, 0)
        root.revision++
        if (root.panelOpen || Notifications.muted(app, root.muted)
                || (root.dnd && !(isUrgent && root.urgentBypass)))
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
        if (ranOut) {
            root.markExpired(id)
        } else {
            var row = root.row(id)
            root.removeFrom(root.history, id)
            if (row)
                root.count(row.appName, 1)
        }
        root.revision++
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
        root.revision++
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

    // A row as the panel still has it, or null once it is gone.
    function row(id) {
        for (var i = 0; i < root.history.count; i++) {
            var row = root.history.get(i)
            if (row.nid === id)
                return {
                    nid: row.nid, summary: row.summary, body: row.body, appName: row.appName,
                    icon: row.icon, image: row.image, arrived: row.arrived, expired: row.expired,
                    conversation: row.conversation, urgent: row.urgent, acted: row.acted
                }
        }
        return null
    }

    // Copying or snoozing is acting on it, even though the row may stay.
    function markActed(id) {
        for (var i = 0; i < root.history.count; i++) {
            if (root.history.get(i).nid !== id)
                continue
            var row = root.history.get(i)
            if (row.acted === true)
                return
            root.history.setProperty(i, "acted", true)
            root.count(row.appName, 1)
            root.revision++
            return
        }
    }

    // Postpones one: it leaves the list and the shell brings it back at `until`.
    function snooze(id, kind) {
        var row = root.row(id)
        if (!row)
            return null
        var until = Notifications.wakeTime(kind, Date.now())
        root.snoozed(row, until)
        root.dismiss(id)
        return until
    }

    function count(app, index) {
        if (!app)
            return
        var day = Notifications.dayOf(Date.now())
        var copy = JSON.parse(JSON.stringify(root.stats || {}))
        if (!copy[day])
            copy[day] = {}
        if (!copy[day][app])
            copy[day][app] = [0, 0]
        copy[day][app][index] += 1
        root.stats = copy
    }

    // What the store keeps, in the order it reads it back.
    function snapshot() {
        var rows = []
        for (var i = 0; i < root.history.count; i++) {
            var row = root.history.get(i)
            rows.push({
                arrived: row.arrived, summary: row.summary, body: row.body, appName: row.appName,
                icon: row.icon, image: row.image, conversation: row.conversation,
                urgent: row.urgent, acted: row.acted
            })
        }
        return { history: rows, stats: root.stats || {} }
    }

    // The history of an earlier session: no live notifications, only rows.
    function restore(document) {
        var rows = (document && document.history) || []
        root.history.clear()
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            root.history.append({
                nid: -(i + 1),
                summary: row.summary || "",
                body: row.body || "",
                appName: row.appName || "",
                icon: row.icon || "",
                image: row.image || "",
                arrived: row.arrived || Date.now(),
                expired: true,
                conversation: row.conversation || "",
                urgent: row.urgent === true,
                acted: row.acted === true
            })
        }
        root.stats = (document && document.stats) || ({})
        root.revision++
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

    onPanelOpenChanged: if (root.panelOpen) {
        root.shown.clear()
        root.waiting = []
    }

    onMaximumChanged: root.pump()
}
