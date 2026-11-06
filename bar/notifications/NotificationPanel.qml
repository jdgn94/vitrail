import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../kit"
import "../kit/base"
import "groups.js" as Groups
import "notifications.js" as Notifications

// Full-height notification panel on one side of the screen.
//
// The list is grouped by application, the app with the newest notification
// first: one card per app, holding a header (icon, name, how many it holds,
// clear and open/close buttons) over the notifications of that app, newest
// first, each one a smaller card inside it (`NotificationEntry`). A chat is
// grouped by conversation (sender / thread), so two threads of one app are two
// groups. A group starts closed and shows only its newest notification; open,
// all of them in a body that scrolls past `Groups.BODY_MAX`. A click on the
// group card outside a notification or a button toggles it. An expired
// notification keeps its row and loses only the live actions.
//
// The header lists the muted apps and shows today's counts per app (how many
// arrived, how many were acted on). Both lists belong to the shell, so the IPC
// can open them too.
Item {
    id: root

    property var queue
    property var strings: ({})
    property string side: "right"
    // The panel has been opened: until then it builds no group and no card,
    // so a closed bar does not reconstruct the whole history at start-up.
    property bool active: false
    // Do Not Disturb: arrivals are listed, not toasted.
    property bool dnd: false
    // What a button asks the shell to do, and the settings' switches.
    property var act: null
    property bool snoozeEnabled: true
    property string mutedApps: ""
    // The queue's per-app counts today.
    property var stats: ({})
    // The shell's: which of the two lists is open.
    property bool mutedShown: false
    property bool statsShown: false
    // How far the panel has come in from its edge (0 closed .. 1 in place):
    // the list slides in from that side with it.
    property real enter: 1
    // "Clear all" runs the cards out towards the panel's edge before it
    // empties the list.
    property bool clearing: false

    signal closeRequested()
    signal dndToggled()
    signal mutedToggled()
    signal statsToggled()

    default property alias widgets: widgetsColumn.data

    // appKey -> expanded. Groups start closed (the newest notification shows);
    // only one the user opened is true.
    property var opened: ({})

    readonly property int pad: VitrailTokens.gap("sm")
    readonly property var surface: VitrailStyle.resolve("surface", VitrailTokens.surfaceMode)

    // One row per app: { key, appName, icon, rows, count, expanded }.
    ListModel {
        id: groups
    }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function clearAll() {
        if (root.clearing || !root.queue)
            return
        root.clearing = true
        clearTimer.restart()
    }

    function groupIndex(key) {
        for (var i = 0; i < groups.count; i++) {
            if (groups.get(i).key === key)
                return i
        }
        return -1
    }

    // Rebuild the groups from the queue's history (see groups.js for the
    // order). Expansion survives, and groups and rows are inserted, moved and
    // removed in place, so the cards that stay keep their state and only the
    // new one animates in.
    function sync() {
        if (!root.queue || !root.active)
            return

        var rows = []
        for (var i = 0; i < root.queue.history.count; i++) {
            var row = root.queue.history.get(i)
            rows.push({
                nid: row.nid,
                summary: row.summary,
                body: row.body,
                appName: row.appName,
                icon: row.icon,
                image: row.image,
                arrived: row.arrived,
                expired: row.expired,
                conversation: row.conversation,
                urgent: row.urgent
            })
        }
        var list = Groups.groupRows(rows, root.t("notifications.unknownApp"))

        // The apps that are gone.
        var present = ({})
        for (var p = 0; p < list.length; p++)
            present[list[p].key] = true
        for (var g = groups.count - 1; g >= 0; g--) {
            if (!present[groups.get(g).key])
                groups.remove(g)
        }

        for (var k = 0; k < list.length; k++) {
            var group = list[k]
            var at = root.groupIndex(group.key)
            if (at < 0) {
                groups.insert(k, {
                    key: group.key,
                    appName: group.appName,
                    conversation: group.conversation,
                    icon: group.icon,
                    rows: group.rows,
                    count: group.rows.length,
                    expanded: root.opened[group.key] === true
                })
                continue
            }
            if (at !== k)
                groups.move(at, k, 1)
            groups.setProperty(k, "appName", group.appName)
            groups.setProperty(k, "conversation", group.conversation)
            groups.setProperty(k, "icon", group.icon)
            groups.setProperty(k, "count", group.rows.length)
            root.syncRows(groups.get(k).rows, group.rows)
        }
    }

    // The group's rows are a nested ListModel (the engine turns the array into
    // one), so they are updated in place: the cards keep their state and only
    // the new one animates in.
    function syncRows(model, rows) {
        for (var i = model.count - 1; i >= 0; i--) {
            var keep = false
            for (var j = 0; j < rows.length; j++) {
                if (rows[j].nid === model.get(i).nid) {
                    keep = true
                    break
                }
            }
            if (!keep)
                model.remove(i)
        }
        for (var k = 0; k < rows.length; k++) {
            var at = -1
            for (var m = 0; m < model.count; m++) {
                if (model.get(m).nid === rows[k].nid) {
                    at = m
                    break
                }
            }
            if (at < 0) {
                model.insert(k, rows[k])
                continue
            }
            if (at !== k)
                model.move(at, k, 1)
            if (model.get(k).expired !== rows[k].expired)
                model.setProperty(k, "expired", rows[k].expired)
        }
    }

    function toggle(key, index) {
        var expanded = !groups.get(index).expanded
        root.opened[key] = expanded
        groups.setProperty(index, "expanded", expanded)
    }

    // False while the first batch of cards is built, so opening the panel does
    // not animate the whole list; an arrival after that slides in.
    property bool settled: false

    Timer {
        interval: VitrailTokens.duration("fast")
        running: root.visible && !root.settled
        onTriggered: root.settled = true
    }

    // Ticks so every card's "5 min" stays true.
    property real now: Date.now()

    Timer {
        id: clearTimer

        interval: VitrailTokens.duration("base")
        onTriggered: {
            if (root.queue)
                root.queue.clear()
            root.clearing = false
        }
    }

    Timer {
        interval: 30000
        running: groups.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    onQueueChanged: root.sync()
    onMutedAppsChanged: if (root.mutedShown && Notifications.list(root.mutedApps).length === 0)
        root.mutedToggled()

    Connections {
        target: root.queue ? root.queue.history : null

        function onCountChanged() { root.sync() }
        function onDataChanged() { root.sync() }
        function onModelReset() { root.sync() }
    }

    Component.onCompleted: root.sync()
    onActiveChanged: if (root.active) root.sync()

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "title"
                text: root.t("notifications.title")
            }

            VitrailButton {
                visible: Notifications.list(root.mutedApps).length > 0
                icon: root.mutedShown ? "notifications_active" : "notifications_off"
                variant: "text"
                tone: root.mutedShown ? "primary" : "secondary"
                size: "sm"
                onClicked: root.mutedToggled()
            }

            VitrailButton {
                icon: "bar_chart"
                variant: "text"
                tone: root.statsShown ? "primary" : "secondary"
                size: "sm"
                onClicked: root.statsToggled()
            }

            VitrailButton {
                icon: root.dnd ? "notifications_off" : "notifications"
                variant: "text"
                tone: root.dnd ? "primary" : "secondary"
                size: "sm"
                onClicked: root.dndToggled()
            }

            VitrailButton {
                text: root.t("notifications.clear")
                variant: "text"
                size: "sm"
                enabled: root.queue && root.queue.history.count > 0 && !root.clearing
                onClicked: root.clearAll()
            }

            VitrailButton {
                icon: "close"
                variant: "text"
                size: "sm"
                onClicked: root.closeRequested()
            }
        }

        // The apps that will not be toasted, each one a click away from it.
        Flow {
            Layout.fillWidth: true
            visible: root.mutedShown
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: Notifications.list(root.mutedApps)

                delegate: VitrailButton {
                    required property var modelData

                    variant: "tonal"
                    tone: "secondary"
                    size: "sm"
                    icon: "notifications_active"
                    text: modelData
                    onClicked: if (root.act) root.act("unmute", modelData, 0)
                }
            }
        }

        // Today's counts: what arrives and what was acted on, per app.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.statsShown
            spacing: VitrailTokens.gap("xs")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.t("notifications.stats")
            }

            VitrailText {
                Layout.fillWidth: true
                visible: Notifications.statsList(root.stats, root.now).length === 0
                variant: "content"
                text: root.t("notifications.stats.empty")
            }

            Repeater {
                model: Notifications.statsList(root.stats, root.now)

                delegate: VitrailSettingRow {
                    required property var modelData

                    label: modelData.app
                    description: root.t("notifications.stats.counts")
                                     .replace("%1", modelData.seen).replace("%2", modelData.acted)
                }
            }
        }

        // Nothing to read: a container with the icon and the line.
        Rectangle {
            id: emptyCard

            Layout.fillWidth: true
            visible: groups.count === 0
            // The card arrives as the cleared list leaves.
            opacity: visible ? 1 : 0
            implicitHeight: emptyColumn.implicitHeight + 2 * VitrailTokens.gap("lg")
            radius: VitrailTokens.radius * 0.85
            color: Qt.rgba(VitrailTokens.color("surfaceHigh").r, VitrailTokens.color("surfaceHigh").g,
                           VitrailTokens.color("surfaceHigh").b, root.surface.raised)

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: emptyColumn

                anchors.centerIn: parent
                width: parent.width - 2 * VitrailTokens.gap("lg")
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "notifications_off"
                    size: "xl"
                    tone: "secondary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.t("notifications.empty")
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: VitrailTokens.gap("sm")
            model: groups

            // The list comes in from the panel's edge as it opens; "clear all"
            // runs it back out the same side while it fades.
            readonly property real fromEdge: root.side === "left" ? -1 : 1
            opacity: root.clearing ? 0 : 1
            transform: Translate {
                x: (1 - root.enter) * list.fromEdge * VitrailTokens.gap("xl")
                   + (root.clearing ? list.fromEdge * list.width * 0.55 : 0)

                Behavior on x { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

            // One app: a card that holds a header and its notifications, each
            // of them a smaller card of its own.
            delegate: Item {
                id: group

                required property var model
                required property int index

                readonly property bool expanded: model.expanded
                // Each group arrives just after the one above it, from the
                // panel's edge.
                property bool entered: false

                width: ListView.view.width
                implicitHeight: inner.implicitHeight + 2 * root.pad
                height: implicitHeight
                opacity: group.entered ? 1 : 0
                transform: Translate {
                    x: group.entered ? 0 : (root.side === "left" ? -VitrailTokens.gap("md") : VitrailTokens.gap("md"))

                    Behavior on x { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
                }

                Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

                Timer {
                    interval: Math.min(group.index, 8) * 35
                    running: !group.entered
                    onTriggered: group.entered = true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: VitrailTokens.radius * 0.85
                    color: Qt.rgba(VitrailTokens.color("surfaceHigh").r, VitrailTokens.color("surfaceHigh").g,
                                   VitrailTokens.color("surfaceHigh").b,
                                   cardHover.hovered ? root.surface.raisedHover : root.surface.raised)

                    Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
                }

                HoverHandler {
                    id: cardHover
                }

                // Under the content: whatever is not a notification or a
                // button opens and closes the group; those keep their clicks.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(group.model.key, group.index)
                }

                ColumnLayout {
                    id: inner

                    x: root.pad
                    y: root.pad
                    width: parent.width - 2 * root.pad
                    spacing: VitrailTokens.gap("sm")

                    RowLayout {
                        id: head

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        Rectangle {
                            implicitWidth: VitrailTokens.size("display")
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                           VitrailTokens.color("foreground").b, 0.1)

                            IconImage {
                                id: groupIcon

                                anchors.centerIn: parent
                                implicitSize: parent.width * 0.62
                                source: {
                                    var icon = group.model.icon
                                    if (icon.indexOf("/") === 0)
                                        return "file://" + icon
                                    if (icon.indexOf("://") > 0)
                                        return icon
                                    return icon ? Quickshell.iconPath(icon, true) : ""
                                }
                                asynchronous: true
                            }

                            VitrailText {
                                anchors.centerIn: parent
                                visible: groupIcon.status !== Image.Ready
                                variant: "icon"
                                text: "info"
                            }
                        }

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "body"
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            text: group.model.conversation !== ""
                                  ? group.model.appName + " · " + group.model.conversation
                                  : group.model.appName
                        }

                        VitrailText {
                            visible: group.model.count > 1
                            variant: "label"
                            text: group.model.count
                        }

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            size: "sm"
                            icon: "clear_all"
                            onClicked: if (root.queue) root.queue.clearGroup(group.model.key)
                        }

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            size: "sm"
                            icon: group.expanded ? "expand_less" : "expand_more"
                            onClicked: root.toggle(group.model.key, group.index)
                        }
                    }

                    // The notifications. One Repeater over the group's rows that
                    // is never reset: closed, only the newest is visible; open,
                    // all of them, and the body scrolls past its cap. Its height
                    // follows the content with a short animation.
                    Flickable {
                        id: body

                        // What the body shows right now; `shownHeight` glides to it.
                        readonly property real wanted: Groups.bodyHeight(cards.implicitHeight, Groups.BODY_MAX)
                        property real shownHeight: wanted

                        Layout.fillWidth: true
                        Layout.preferredHeight: shownHeight
                        clip: true
                        contentWidth: width
                        contentHeight: cards.implicitHeight
                        interactive: Groups.scrolls(cards.implicitHeight, Groups.BODY_MAX)
                        boundsBehavior: Flickable.StopAtBounds

                        Behavior on shownHeight {
                            NumberAnimation {
                                duration: VitrailTokens.duration("base")
                                easing.type: Easing.OutCubic
                            }
                        }

                        Column {
                            id: cards

                            width: body.width
                            spacing: VitrailTokens.gap("xs")

                            Repeater {
                                model: group.model.rows

                                delegate: NotificationEntry {
                                    id: card

                                    required property var model
                                    required property int index

                                    // The queue's snapshot of this row.
                                    readonly property var snapshot: ({
                                        nid: model.nid,
                                        summary: model.summary,
                                        body: model.body,
                                        appName: model.appName,
                                        icon: model.icon,
                                        image: model.image,
                                        arrived: model.arrived,
                                        expired: model.expired,
                                        conversation: model.conversation,
                                        urgent: model.urgent
                                    })
                                    // Slide in from above by one small gap.
                                    readonly property int rise: VitrailTokens.gap("sm")

                                    width: cards.width
                                    visible: group.expanded || index === 0
                                    notification: root.queue ? root.queue.byId[model.nid] || null : null
                                    row: snapshot
                                    strings: root.strings
                                    act: root.act
                                    snoozeEnabled: root.snoozeEnabled
                                    mutedApps: root.mutedApps
                                    arrived: model.arrived
                                    now: root.now
                                    opacity: root.settled ? 0 : 1
                                    transform: Translate {
                                        id: slide

                                        y: root.settled ? -card.rise : 0

                                        Behavior on y { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
                                    }

                                    // Rows are never rebuilt, so only a new one gets here.
                                    Component.onCompleted: {
                                        opacity = 1
                                        slide.y = 0
                                    }
                                    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

                                    onRemoveRequested: if (root.queue) root.queue.dismiss(model.nid)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Widgets live here once they exist.
        ColumnLayout {
            id: widgetsColumn
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")
        }
    }
}
