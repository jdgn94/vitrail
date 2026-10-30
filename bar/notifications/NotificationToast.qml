import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../kit"
import "../kit/base"

// One incoming notification as a card: the app icon in a circle, then
//   collapsed  title • age, and one line of the body;
//   expanded   app • age, the title, the whole body and the actions.
// The newest one opens expanded; the chevron overrides it. A click runs the
// default action (focus the app), a middle click or a sideways flick marks
// it read. It expires after five seconds unless the pointer rests on it.
Item {
    id: root

    property var notification: null
    property var strings: ({})
    // When it arrived and the current time, in ms, for "5 min".
    property real arrived: 0
    property real now: Date.now()
    property bool newest: false

    // undefined until the user picks; then their choice wins.
    property var userExpanded: undefined
    property bool replying: false

    readonly property bool expanded: root.userExpanded !== undefined ? root.userExpanded : root.newest
    readonly property bool held: hover.hovered || root.replying || swipe.active
    readonly property var actions: root.notification ? root.notification.actions : []
    readonly property var defaultAction: root.actions.find(function (action) {
        return action.identifier === "default"
    }) || null
    readonly property var extraActions: root.actions.filter(function (action) {
        return action.identifier !== "default"
    })
    readonly property string appName: root.notification ? root.notification.appName : ""
    readonly property string summary: root.notification ? root.notification.summary : ""
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
        if (reply.text.trim() === "")
            return
        root.notification.sendInlineReply(reply.text)
        reply.text = ""
        root.replying = false
    }

    Item {
        id: card

        width: parent.width
        height: parent.height
        opacity: 1 - Math.min(1, Math.abs(card.x) / root.width)

        Behavior on x {
            enabled: !swipe.active
            NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: VitrailTokens.radius * 0.85
            color: Qt.rgba(VitrailTokens.color("surfaceHigh").r, VitrailTokens.color("surfaceHigh").g,
                           VitrailTokens.color("surfaceHigh").b,
                           hover.hovered ? root.surface.raisedHover : root.surface.raised)

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

        // A sideways flick past a third of the width marks it read.
        DragHandler {
            id: swipe

            target: card
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    return
                if (Math.abs(card.x) > root.width / 3) {
                    card.x = card.x > 0 ? root.width : -root.width
                    dismissal.start()
                } else {
                    card.x = 0
                }
            }
        }

        Timer {
            id: dismissal

            interval: VitrailTokens.duration("base")
            onTriggered: root.notification.dismiss()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: function (mouse) {
                if (mouse.button === Qt.MiddleButton)
                    root.notification.dismiss()
                else if (root.defaultAction)
                    root.defaultAction.invoke()
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
                    filled: true
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
                    text: root.notification ? root.notification.body : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? 6 : 1
                    elide: Text.ElideRight
                    linkColor: VitrailTokens.color("primary")
                    onLinkActivated: function (link) { Qt.openUrlExternally(link) }
                }

                // The app's actions, then reply and mark as read.
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: VitrailTokens.gap("xs")
                    visible: root.expanded
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
                        visible: root.notification ? root.notification.hasInlineReply : false
                        variant: "text"
                        tone: "secondary"
                        icon: "reply"
                        text: root.t("notifications.reply")
                        onClicked: {
                            root.replying = true
                            reply.forceActiveFocus()
                        }
                    }

                    VitrailButton {
                        variant: "text"
                        tone: "secondary"
                        icon: "done_all"
                        text: root.t("notifications.markRead")
                        onClicked: root.notification.dismiss()
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
                        placeholder: root.notification && root.notification.inlineReplyPlaceholder
                                     ? root.notification.inlineReplyPlaceholder : root.t("notifications.replyPlaceholder")
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
    }

    // Restarts from zero whenever the pointer leaves or the reply closes.
    Timer {
        interval: 5000
        running: root.notification !== null && !root.held
        onTriggered: root.notification.expire()
    }
}
