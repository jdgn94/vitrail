import QtQuick
import QtQuick.Layouts
import Quickshell
import "../kit"
import "../kit/base"

// One incoming notification: app image, title and a two-line HTML body.
// Clicking it runs the app's default action (usually "focus the app"); the
// dots open the rest: mark as read, reply and the app's own actions.
// It expires after five seconds unless the pointer rests on it.
Item {
    id: root

    property var notification: null
    property var strings: ({})
    // Floating bars give each toast its own card; docked ones share the
    // frame tab and only draw a divider between toasts.
    property bool card: false
    property bool divider: false
    property bool dividerBelow: false

    property bool menuOpen: false
    property bool replying: false
    readonly property bool held: hover.hovered || root.menuOpen || root.replying

    readonly property var actions: root.notification ? root.notification.actions : []
    readonly property var defaultAction: {
        for (var i = 0; i < root.actions.length; i++) {
            if (root.actions[i].identifier === "default")
                return root.actions[i]
        }
        return null
    }
    readonly property var extraActions: root.actions.filter(function (action) {
        return action.identifier !== "default"
    })
    readonly property string appName: root.notification ? root.notification.appName : ""
    // The app's own icon first; a notification image (an avatar, a cover)
    // stands in when the app has none.
    readonly property string imageSource: {
        if (!root.notification)
            return ""
        var icon = root.notification.appIcon || root.notification.desktopEntry
        if (icon.indexOf("/") === 0)
            return "file://" + icon
        if (icon.indexOf("://") > 0)
            return icon
        var themed = icon ? Quickshell.iconPath(icon, true) : ""
        return themed || root.notification.image || ""
    }
    readonly property int pad: VitrailTokens.gap(root.card ? "md" : "sm")

    implicitHeight: content.implicitHeight + 2 * root.pad

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function sendReply() {
        if (reply.text.trim() === "")
            return
        root.notification.sendInlineReply(reply.text)
        reply.text = ""
        root.replying = false
    }

    VitrailSurface {
        anchors.fill: parent
        visible: root.card
        style: VitrailTokens.surfaceMode
        radius: VitrailTokens.radius
        tint: VitrailTokens.color("surface")
        opacityLevel: 0.95
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        y: root.dividerBelow ? parent.height - height : 0
        visible: root.divider
        height: 1
        color: VitrailTokens.color("foreground")
        opacity: 0.08
    }

    HoverHandler {
        id: hover
    }

    // The whole toast is the default action; the dots and buttons sit above.
    MouseArea {
        anchors.fill: parent
        enabled: root.defaultAction !== null
        cursorShape: Qt.PointingHandCursor
        onClicked: root.defaultAction.invoke()
    }

    ColumnLayout {
        id: content

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: VitrailTokens.size("display")
                implicitHeight: VitrailTokens.size("display")

                Image {
                    id: image

                    anchors.fill: parent
                    source: root.imageSource
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                // No image at all: the app's initial on a tinted disc.
                Rectangle {
                    anchors.fill: parent
                    visible: image.status !== Image.Ready
                    radius: width / 2
                    color: Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                                   VitrailTokens.color("primary").b, 0.18)

                    VitrailText {
                        anchors.centerIn: parent
                        variant: "subtitle"
                        text: root.appName.charAt(0).toUpperCase()
                        color: VitrailTokens.color("primary")
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("xs")

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "body"
                        font.weight: Font.DemiBold
                        text: root.notification ? root.notification.summary : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }

                    VitrailText {
                        variant: "label"
                        text: root.appName
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.width / 3
                    }

                    VitrailButton {
                        variant: "text"
                        tone: "secondary"
                        icon: "more_vert"
                        onClicked: {
                            root.menuOpen = !root.menuOpen
                            if (!root.menuOpen)
                                root.replying = false
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    variant: "content"
                    text: root.notification ? root.notification.body : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    linkColor: VitrailTokens.color("primary")
                    onLinkActivated: function (link) { Qt.openUrlExternally(link) }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: root.menuOpen
            spacing: VitrailTokens.gap("xs")

            VitrailButton {
                variant: "tonal"
                icon: "done_all"
                text: root.t("notifications.markRead")
                onClicked: root.notification.dismiss()
            }

            VitrailButton {
                visible: root.notification ? root.notification.hasInlineReply : false
                variant: "tonal"
                icon: "reply"
                text: root.t("notifications.reply")
                onClicked: {
                    root.replying = true
                    reply.forceActiveFocus()
                }
            }

            Repeater {
                model: root.extraActions

                delegate: VitrailButton {
                    required property var modelData

                    variant: "outlined"
                    tone: "secondary"
                    text: modelData.text
                    onClicked: modelData.invoke()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.replying
            spacing: VitrailTokens.gap("xs")

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: reply.implicitHeight + 2 * VitrailTokens.gap("xs")
                radius: Math.min(height / 2, VitrailTokens.radius)
                color: Qt.rgba(VitrailTokens.color("surfaceHigh").r, VitrailTokens.color("surfaceHigh").g,
                               VitrailTokens.color("surfaceHigh").b, 0.85)
                border.width: 1
                border.color: reply.activeFocus ? VitrailTokens.color("primary")
                                                : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: reply

                    anchors.verticalCenter: parent.verticalCenter
                    x: VitrailTokens.gap("sm")
                    width: parent.width - 2 * VitrailTokens.gap("sm")
                    color: VitrailTokens.color("foreground")
                    selectionColor: VitrailTokens.color("primary")
                    font.pixelSize: VitrailTokens.size("content")
                    font.family: VitrailTokens.fontFamily
                    clip: true
                    onAccepted: root.sendReply()
                    Keys.onEscapePressed: root.replying = false

                    VitrailText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: reply.text === ""
                        variant: "content"
                        opacity: 0.6
                        text: root.notification && root.notification.inlineReplyPlaceholder
                              ? root.notification.inlineReplyPlaceholder : root.t("notifications.replyPlaceholder")
                    }
                }
            }

            VitrailButton {
                variant: "flat"
                icon: "send"
                onClicked: root.sendReply()
            }
        }
    }

    // Restarts from zero whenever the pointer leaves or the menu closes.
    Timer {
        interval: 5000
        running: root.notification !== null && !root.held
        onTriggered: root.notification.expire()
    }
}
