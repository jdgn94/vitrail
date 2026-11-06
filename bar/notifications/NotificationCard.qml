import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../kit"
import "../kit/base"
import "notifications.js" as Notifications

// One notification as a card: the app icon in a circle, then
//   collapsed  title • age, and one line of the body;
//   expanded   app • age, the title, the whole body and the actions.
// The newest one opens expanded; the chevron overrides it. A click runs the
// default action (focus the app), a middle click marks it read. An urgent one
// wears the accent border. `act(kind, value, id)` hands copy, snooze, mute and
// opening an attachment to the shell.
//
// The toast wraps it with the swipe and the expiry; the panel has its own
// (`NotificationEntry`).
Item {
    id: root

    property var notification: null
    property var strings: ({})
    // What a button asks the shell to do; null in a preview.
    property var act: null
    // The settings' switches: snooze offered, and the apps muted.
    property bool snoozeEnabled: true
    property string mutedApps: ""
    // When it arrived and the current time, in ms, for "5 min".
    property real arrived: 0
    property real now: Date.now()
    property bool newest: false
    property bool replying: false

    // undefined until the user picks; then their choice wins.
    property var userExpanded: undefined

    readonly property var entry: root.notification
    readonly property bool expanded: root.userExpanded !== undefined ? root.userExpanded : root.newest
    readonly property bool hovered: hover.hovered
    readonly property bool held: hover.hovered || root.replying
    readonly property bool isUrgent: root.entry ? root.entry.urgent === true : false
    readonly property bool mutedApp: Notifications.muted(root.appName, root.mutedApps)
    readonly property var actions: root.notification ? root.notification.actions : []
    readonly property var defaultAction: root.actions.find(function (action) {
        return action.identifier === "default"
    }) || null
    readonly property string appName: root.entry ? (root.entry.appName || "") : ""
    readonly property string summary: root.entry ? (root.entry.summary || "") : ""
    readonly property string body: root.entry ? (root.entry.body || "") : ""
    readonly property string icon: root.entry ? (root.entry.appIcon || "") : ""
    readonly property string image: root.entry ? (root.entry.image || "") : ""
    readonly property bool canReply: root.notification ? root.notification.hasInlineReply : false
    readonly property string replyPlaceholder: root.notification && root.notification.inlineReplyPlaceholder
                                               ? root.notification.inlineReplyPlaceholder
                                               : root.t("notifications.replyPlaceholder")
    readonly property string age: {
        var minutes = Math.floor((root.now - root.arrived) / 60000)
        if (minutes < 1)
            return root.t("notifications.now")
        if (minutes < 60)
            return root.t("notifications.minutes").arg(minutes)
        return root.t("notifications.hours").arg(Math.floor(minutes / 60))
    }
    // The app's own icon first; a notification image stands in when the
    // app has none.
    readonly property string imageSource: {
        if (!root.entry)
            return ""
        if (root.icon.indexOf("/") === 0)
            return "file://" + root.icon
        if (root.icon.indexOf("://") > 0)
            return root.icon
        var themed = root.icon ? Quickshell.iconPath(root.icon, true) : ""
        return themed || root.image
    }
    readonly property int pad: VitrailTokens.gap("sm")
    // The card is a raised layer of the surface style (glass: translucent,
    // solid: opaque); the pointer lifts it.
    readonly property var surface: VitrailStyle.resolve("surface", VitrailTokens.surfaceMode)

    implicitHeight: content.implicitHeight + 2 * root.pad

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function sendReply() {
        if (reply.text.trim() === "" || !root.notification)
            return
        root.notification.sendInlineReply(reply.text)
        reply.text = ""
        root.replying = false
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius * 0.85
        color: Qt.rgba(VitrailTokens.color("surfaceHigh").r, VitrailTokens.color("surfaceHigh").g,
                       VitrailTokens.color("surfaceHigh").b,
                       hover.hovered ? root.surface.raisedHover : root.surface.raised)
        // An urgent notification (a message, a call) is marked, not shouted.
        border.width: root.isUrgent ? 1 : 0
        border.color: VitrailTokens.color("error")

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }

        // An opaque card cannot get any more opaque: it takes a tint.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: VitrailTokens.color("foreground")
            opacity: hover.hovered && root.surface.raisedHover <= root.surface.raised ? 0.06 : 0

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
        }
    }

    HoverHandler {
        id: hover
    }

    // Declared before the content: the buttons and the chevron stay on top.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (root.notification)
                    root.notification.dismiss()
            } else if (root.defaultAction) {
                root.defaultAction.invoke()
            }
        }
    }

    RowLayout {
        id: content

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: VitrailTokens.gap("sm")

        // App icon in a circle; an "info" glyph when there is none.
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: VitrailTokens.size("display") + VitrailTokens.gap("xs")
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                           VitrailTokens.color("foreground").b, 0.1)

            IconImage {
                id: image

                anchors.centerIn: parent
                implicitSize: parent.width * 0.62
                source: root.imageSource
                asynchronous: true
            }

            VitrailText {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                variant: "icon"
                text: "info"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                id: heading

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    visible: root.isUrgent
                    variant: "icon"
                    color: VitrailTokens.color("error")
                    text: "priority_high"
                }

                // Takes what it needs; the age follows it and the
                // chevron keeps the right edge.
                VitrailText {
                    Layout.maximumWidth: heading.width - ageLabel.implicitWidth - chevron.implicitWidth
                                         - 2 * heading.spacing
                    variant: root.expanded ? "content" : "body"
                    font.weight: root.expanded ? Font.Normal : Font.Medium
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.expanded ? root.appName : root.summary
                }

                VitrailText {
                    id: ageLabel

                    Layout.fillWidth: true
                    variant: "content"
                    opacity: 0.7
                    text: "• " + root.age
                }

                VitrailButton {
                    id: chevron

                    variant: "plain"
                    tone: "secondary"
                    size: "sm"
                    icon: root.expanded ? "expand_less" : "expand_more"
                    onClicked: root.userExpanded = !root.expanded
                }
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.expanded
                variant: "body"
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: root.summary
            }

            VitrailText {
                Layout.fillWidth: true
                visible: text !== ""
                variant: "content"
                text: Notifications.linkify(root.body)
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? 6 : 1
                elide: Text.ElideRight
                linkColor: VitrailTokens.color("primary")
                onLinkActivated: function (link) { Qt.openUrlExternally(link) }
            }

            // A download (or any long task): its bar and the X that cancels it.
            ProgressRow {
                Layout.fillWidth: true
                Layout.topMargin: VitrailTokens.gap("xs")
                notification: root.notification
            }

            // The app's actions, copy, snooze, mute and mark as read; then reply.
            NotificationActions {
                Layout.fillWidth: true
                Layout.topMargin: VitrailTokens.gap("xs")
                visible: root.expanded
                notification: root.notification
                strings: root.strings
                snooze: root.snoozeEnabled
                muted: root.mutedApp
                onAct: function (kind, value) {
                    if (root.act)
                        root.act(kind, value, root.notification ? root.notification.id : 0)
                }
            }

            VitrailButton {
                visible: root.expanded && root.canReply
                Layout.topMargin: VitrailTokens.gap("xs")
                variant: "text"
                tone: "secondary"
                icon: "reply"
                text: root.t("notifications.reply")
                onClicked: {
                    root.replying = true
                    reply.forceActiveFocus()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.replying
                spacing: VitrailTokens.gap("xs")

                VitrailField {
                    id: reply

                    Layout.fillWidth: true
                    size: "sm"
                    placeholder: root.replyPlaceholder
                    onAccepted: root.sendReply()
                    onEscaped: root.replying = false
                }

                VitrailButton {
                    variant: "flat"
                    icon: "send"
                    onClicked: root.sendReply()
                }
            }
        }
    }

    // Keyboard: Tab reaches the card, Enter or Space runs its default action
    // (focus the app). Its buttons stay reachable on their own.
    activeFocusOnTab: root.defaultAction !== null && root.defaultAction !== undefined
    Keys.onReturnPressed: if (root.defaultAction) root.defaultAction.invoke()
    Keys.onSpacePressed: if (root.defaultAction) root.defaultAction.invoke()

    // Where the keyboard is.
    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius * 0.85
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: VitrailTokens.color("primary")
        visible: root.activeFocus
    }
}
