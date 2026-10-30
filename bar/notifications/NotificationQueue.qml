import QtQuick

// Notifications on screen and the ones waiting their turn: at most
// `maximum` are shown, newest first; the rest queue in arrival order and
// take the first slot that frees up.
QtObject {
    id: root

    property int maximum: 5
    // { nid } rows; `byId` resolves them to the notification objects.
    property ListModel shown: ListModel {}
    property var waiting: []
    property var byId: ({})

    onMaximumChanged: root.pump()

    function push(notification) {
        if (root.byId[notification.id])
            return
        root.byId[notification.id] = notification
        notification.closed.connect(function () { root.drop(notification.id) })
        root.waiting.push(notification.id)
        root.pump()
    }

    function drop(id) {
        delete root.byId[id]
        var at = root.waiting.indexOf(id)
        if (at >= 0)
            root.waiting.splice(at, 1)
        for (var i = 0; i < root.shown.count; i++) {
            if (root.shown.get(i).nid === id) {
                root.shown.remove(i)
                break
            }
        }
        root.pump()
    }

    function pump() {
        while (root.shown.count < root.maximum && root.waiting.length > 0)
            root.shown.insert(0, { nid: root.waiting.shift() })
    }
}
