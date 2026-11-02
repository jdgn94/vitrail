import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../kit"
import "../kit/base"
import "groups.js" as Groups
import "notifications.js" as Notifications

// One notification inside an application group of the panel (the toast uses
// `NotificationCard`):
//
//   (avatar)  summary                      age   x
//   body
//   [ picture ]
//   actions, reply
//
// The notification's image shows in exactly one place (`Groups.imageSlot`): a
// square one is the avatar in the circle, any other is the picture under the
// text and the circle shows the app's icon. Clicking the picture opens the
// attachment with the file manager. A click runs the default action (focus the
// app), a middle click or the x removes it. An urgent one wears the accent
// border.
//
// `notification` is the live object; `row` is the queue's snapshot, which the
// panel still has once the toast expired: an expired entry keeps its place and
// loses only the live actions.
Item {
    id: root

    property var notification: null
    property var row: null
    property var strings: ({})
    // What a button asks the shell to do; null in a preview.
    property var act: null
    property bool snoozeEnabled: true
    property string mutedApps: ""
    // When it arrived and the current time, in ms, for "5 min".
    property real arrived: 0
    property real now: Date.now()
    property bool replying: false

    // The x, the middle click: the panel removes the row (a live notification
    // is dismissed, an expired one is forgotten).
    signal removeRequested()

    // Whichever is there: the live object, else the snapshot.
    readonly property var entry: root.notification || root.row || null
    readonly property bool isUrgent: root.entry ? root.entry.urgent === true : false
    readonly property bool mutedApp: Notifications.muted(root.appName, root.mutedApps)
    readonly property var actions: root.notification ? root.notification.actions : []
    readonly property var defaultAction: root.actions.find(function (action) {
        return action.identifier === "default"
    }) || null
    readonly property string summary: root.entry ? (root.entry.summary || "") : ""
    readonly property string body: root.entry ? (root.entry.body || "") : ""
    readonly property string icon: root.entry ? (root.entry.appIcon || root.entry.icon || "") : ""
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
    readonly property string iconSource: {
        if (root.icon.indexOf("/") === 0)
            return "file://" + root.icon
        if (root.icon.indexOf("://") > 0)
            return root.icon
        return root.icon ? Quickshell.iconPath(root.icon, true) : ""
    }
    // The size is known once the picture's image has loaded.
    readonly property string slot: Groups.imageSlot(root.image,
                                                    picture.status === Image.Ready ? picture.implicitWidth : 0,
                                                    picture.status === Image.Ready ? picture.implicitHeight : 0)
    readonly property bool avatarImage: root.slot === "avatar" && avatar.status === Image.Ready
    readonly property int pad: VitrailTokens.gap("sm")
    // A raised layer on the group's own raised layer: the foreground tint keeps
    // it apart from it, also on an opaque surface.
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

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: VitrailTokens.color("foreground")
            opacity: hover.hovered ? 0.1 : 0.06

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
        }
    }

    HoverHandler {
        id: hover
    }

    // Declared before the content: the buttons stay on top, and it takes the
    // click before the group's own.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton)
                root.removeRequested()
            else if (root.defaultAction)
                root.defaultAction.invoke()
        }
    }

    ColumnLayout {
        id: content

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: VitrailTokens.gap("xs")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            // The avatar: the notification's image when it is one, else the
            // app's icon; an "info" glyph when there is neither.
            ClippingRectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: VitrailTokens.size("display")
                implicitHeight: implicitWidth
                radius: width / 2
                color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                               VitrailTokens.color("foreground").b, 0.1)

                Image {
                    id: avatar

                    anchors.fill: parent
                    visible: root.avatarImage
                    source: root.slot === "avatar" ? root.image : ""
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                IconImage {
                    id: appIcon

                    anchors.centerIn: parent
                    visible: !root.avatarImage
                    implicitSize: parent.width * 0.62
                    source: root.iconSource
                    asynchronous: true
                }

                VitrailText {
                    anchors.centerIn: parent
                    visible: !root.avatarImage && appIcon.status !== Image.Ready
                    variant: "icon"
                    filled: true
                    text: "info"
                }
            }

            VitrailText {
                visible: root.isUrgent
                variant: "icon"
                filled: true
                color: VitrailTokens.color("error")
                text: "priority_high"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                font.weight: Font.Medium
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.summary
            }

            VitrailText {
                variant: "content"
                opacity: 0.7
                text: root.age
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "close"
                onClicked: root.removeRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: text !== ""
            variant: "content"
            text: Notifications.linkify(root.body)
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
            linkColor: VitrailTokens.color("primary")
            onLinkActivated: function (link) { Qt.openUrlExternally(link) }
        }

        // A download (or any long task): its bar and the X that cancels it.
        ProgressRow {
            Layout.fillWidth: true
            notification: root.notification
        }

        // Always loaded: its size decides the slot, and it is the picture when
        // the slot says so. A click opens the attachment.
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Groups.pictureHeight(width, picture.implicitWidth, picture.implicitHeight,
                                                         Groups.PICTURE_MAX)
            visible: root.slot === "picture"
            radius: VitrailTokens.radius * 0.6
            color: "transparent"

            Image {
                id: picture

                anchors.fill: parent
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.act) root.act("open", root.image, root.entry ? root.entry.nid : 0)
            }
        }

        // The app's own actions, copy, snooze, mute and mark as read; then reply.
        NotificationActions {
            Layout.fillWidth: true
            notification: root.notification
            strings: root.strings
            snooze: root.snoozeEnabled
            muted: root.mutedApp
            onAct: function (kind, value) {
                if (root.act)
                    root.act(kind, value, root.entry ? root.entry.nid : 0)
            }
        }

        VitrailButton {
            visible: root.canReply
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
