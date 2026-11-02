import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// What can be done with a notification, under its text: the app's own actions,
// copy, snooze (15 min / 1 h / tomorrow), mute that app, and mark as read.
// Both the toast and the panel's card use it; `act(kind, value)` goes up to
// the shell, which knows the notification id.
ColumnLayout {
    id: root

    // The live notification (its actions) and the strings to draw.
    property var notification: null
    property var strings: ({})
    // Whether the cards offer snooze (the settings switch).
    property bool snooze: true
    // Whether this app is muted, so the button offers the way back.
    property bool muted: false

    signal act(string kind, string value)

    spacing: VitrailTokens.gap("xs")

    readonly property var extraActions: root.notification
        ? root.notification.actions.filter(function (action) { return action.identifier !== "default" })
        : []

    // The three delays are open: the card asks which one.
    property bool choosing: false

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Flow {
        Layout.fillWidth: true
        // A Positioner inside a Layout does not report the height of the rows
        // it wrapped in time: its content rectangle does.
        Layout.preferredHeight: childrenRect.height
        spacing: VitrailTokens.gap("xs")

        Repeater {
            model: root.extraActions

            delegate: VitrailButton {
                required property var modelData

                variant: "text"
                tone: "secondary"
                text: modelData.text
                onClicked: modelData.invoke()
            }
        }

        VitrailButton {
            variant: "text"
            tone: "secondary"
            icon: "content_copy"
            text: root.t("notifications.copy")
            onClicked: root.act("copy", "")
        }

        VitrailButton {
            visible: root.snooze && root.notification !== null
            variant: "text"
            tone: "secondary"
            icon: "snooze"
            text: root.t("notifications.snooze")
            onClicked: root.choosing = !root.choosing
        }

        VitrailButton {
            variant: "text"
            tone: "secondary"
            icon: root.muted ? "notifications_active" : "notifications_off"
            text: root.muted ? root.t("notifications.unmute") : root.t("notifications.mute")
            onClicked: root.act("mute", root.muted ? "off" : "on")
        }

        VitrailButton {
            variant: "text"
            tone: "secondary"
            icon: "done_all"
            text: root.t("notifications.markRead")
            onClicked: root.act("read", "")
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.choosing
        spacing: VitrailTokens.gap("xs")

        Item { Layout.fillWidth: true }

        VitrailButton {
            variant: "tonal"
            size: "sm"
            text: root.t("notifications.snooze.15m")
            onClicked: {
                root.choosing = false
                root.act("snooze", "15m")
            }
        }

        VitrailButton {
            variant: "tonal"
            size: "sm"
            text: root.t("notifications.snooze.1h")
            onClicked: {
                root.choosing = false
                root.act("snooze", "1h")
            }
        }

        VitrailButton {
            variant: "tonal"
            size: "sm"
            text: root.t("notifications.snooze.tomorrow")
            onClicked: {
                root.choosing = false
                root.act("snooze", "tomorrow")
            }
        }

        VitrailButton {
            variant: "plain"
            tone: "secondary"
            size: "sm"
            icon: "close"
            onClicked: root.choosing = false
        }
    }
}
