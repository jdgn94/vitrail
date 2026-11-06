import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "actions.js" as Session

// The question before a session action runs. Two phases:
//
//   problem    something is still working (a download, a package update, a
//              job): it says what, and offers Cancel or Go ahead. No countdown
//              runs until the user accepts.
//   countdown  "Shut down in 30 seconds": Cancel or Do it now, and the action
//              runs by itself when the number reaches zero.
//
// Escape cancels, Enter confirms (the last button). The shell owns the
// countdown and the command; this only draws it and reports the answer.
Item {
    id: root

    property var strings: ({})
    // The action key ("poweroff"…) and the phase ("problem" | "countdown").
    property string action: ""
    property string phase: "countdown"
    // True on the monitor whose session layer this is.
    property bool allowed: true
    // What would be interrupted: [{ kind: "download"|"update"|"job", label }].
    property var jobs: []
    // Seconds left and the whole wait, for the ring and the number.
    property int remaining: 0
    property int total: Session.SECONDS

    signal cancelled()
    signal confirmed()

    readonly property var entry: Session.find(root.action)
    readonly property string actionLabel: root.entry ? root.t(root.entry.label) : ""
    readonly property string title: root.phase === "problem" ? root.t("session.confirm.problem")
                                                             : root.t("session.confirm.in")
                                                                   .replace("%1", root.actionLabel)
                                                                   .replace("%2", root.remaining)
    readonly property string tone: root.entry ? root.entry.tone : "primary"
    readonly property var buttons: root.phase === "problem"
        ? [{ key: "cancel", label: root.t("dialog.cancel"), variant: "outlined", tone: "secondary" },
           { key: "go", label: root.t("session.confirm.go"), variant: "flat", tone: root.tone }]
        : [{ key: "cancel", label: root.t("dialog.cancel"), variant: "outlined", tone: "secondary" },
           { key: "now", label: root.t("session.confirm.now"), variant: "flat", tone: root.tone }]

    implicitWidth: 420
    implicitHeight: card.height

    focus: true
    visible: root.allowed && root.action !== "" && root.phase !== "check"
    onVisibleChanged: if (root.visible) root.forceActiveFocus()

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // What one running thing is, in the user's words.
    function label(job) {
        if (!job)
            return ""
        if (job.kind === "download")
            return root.t("session.confirm.download").replace("%1", job.label || "")
        if (job.kind === "update")
            return root.t("session.confirm.update").replace("%1", job.label || "")
        return root.t("session.confirm.job").replace("%1", job.label || "")
    }

    function iconFor(kind) {
        return kind === "download" ? "download" : kind === "update" ? "system_update" : "sync"
    }

    Keys.onEscapePressed: root.cancelled()
    Keys.onReturnPressed: root.confirmed()

    // The menu behind it dims; the card is the only thing to read.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.4
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: root.implicitWidth
        height: body.implicitHeight + 2 * VitrailTokens.gap("lg")

        VitrailSurface {
            anchors.fill: parent
            style: VitrailTokens.surfaceMode
            radius: VitrailTokens.radius * 1.5
            tint: VitrailTokens.color("surface")
            opacityLevel: VitrailTokens.opacity
        }

        ColumnLayout {
            id: body

            x: VitrailTokens.gap("lg")
            y: VitrailTokens.gap("lg")
            width: card.width - 2 * VitrailTokens.gap("lg")
            spacing: VitrailTokens.gap("md")

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: VitrailTokens.size("display") * 1.6
                implicitHeight: implicitWidth
                radius: width / 2
                color: Qt.rgba(VitrailTokens.color(root.phase === "problem" ? "error" : root.tone).r,
                               VitrailTokens.color(root.phase === "problem" ? "error" : root.tone).g,
                               VitrailTokens.color(root.phase === "problem" ? "error" : root.tone).b, 0.18)

                VitrailIcon {
                    anchors.centerIn: parent
                    pixelSize: VitrailTokens.size("display")
                    icon: root.phase === "problem" ? "pending_actions" : (root.entry ? root.entry.icon : "power_settings_new")
                    color: VitrailTokens.color(root.phase === "problem" ? "error" : root.tone)
                }
            }

            VitrailText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                variant: "subtitle"
                wrapMode: Text.Wrap
                text: root.title
            }

            // The countdown: a number (in the title) and a bar that empties.
            Item {
                Layout.fillWidth: true
                Layout.topMargin: VitrailTokens.gap("xs")
                implicitHeight: VitrailTokens.gap("xs") + 2
                visible: root.phase !== "problem"

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                   VitrailTokens.color("foreground").b, 0.15)
                }

                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: root.total > 0 ? parent.width * Math.min(1, root.remaining / root.total) : 0
                    color: VitrailTokens.color(root.tone)

                    Behavior on width { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                }
            }

            // What is still running, one line each.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.phase === "problem"
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    text: root.t("session.confirm.problem.help")
                }

                Repeater {
                    model: root.jobs

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        VitrailIcon {
                            color: VitrailTokens.color("primary")
                            icon: root.iconFor(modelData.kind)
                        }

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "content"
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: root.label(modelData)
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: VitrailTokens.gap("xs")
                spacing: VitrailTokens.gap("sm")

                Repeater {
                    model: root.buttons

                    delegate: VitrailButton {
                        required property var modelData

                        variant: modelData.variant
                        tone: modelData.tone
                        text: modelData.label
                        onClicked: modelData.key === "cancel" ? root.cancelled() : root.confirmed()
                    }
                }
            }
        }
    }
}
