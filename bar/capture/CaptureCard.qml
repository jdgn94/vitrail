import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "capture.js" as Capture

// The result card of a capture action that answers in place: a translation or
// the content of a QR code. It takes the toolbar's seat, shows a busy
// indicator while it waits, an error when it failed, and otherwise the text
// with buttons to copy it and, for a web link, to open it. Escape or the close
// button return to the toolbar.
Item {
    id: root

    property var t: function (key) {
        return key
    }
    // "translate" | "qr"
    property string kind: "translate"
    // "loading" | "done" | "error" (not `state`: Item already has one)
    property string phase: "loading"
    property string text: ""
    // Set for a QR code that is a web link.
    property string url: ""
    // What went wrong, already in the user's language.
    property string message: ""
    // A line under the title ("Copied" for a code, the language for a translation).
    property string note: ""

    signal copyRequested(string text)
    signal openRequested(string url)
    signal closed()

    readonly property string icon: root.kind === "qr" ? "qr_code_2" : "translate"
    readonly property bool done: root.phase === "done"

    implicitWidth: card.width
    implicitHeight: card.height

    component Tip: Item {
        id: tip

        property string icon: ""
        property string tooltip: ""

        signal clicked()

        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight

        VitrailButton {
            id: button

            anchors.fill: parent
            variant: "text"
            tone: "secondary"
            size: "sm"
            icon: tip.icon
            onClicked: tip.clicked()
        }

        VitrailTooltip {
            text: tip.tooltip
            active: button.hovered
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: VitrailTokens.gap("xs")
        }
    }

    VitrailSurface {
        id: card

        anchors.centerIn: parent
        width: VitrailTokens.capture.card.width
        height: body.implicitHeight + 2 * VitrailTokens.gap("sm")
        radius: VitrailTokens.radius

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: VitrailTokens.gap("sm")
            spacing: VitrailTokens.gap("xs")

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailIcon {
                    icon: root.icon
                    size: "md"
                    tone: "primary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.note
                }

                Tip {
                    visible: root.done
                    icon: "content_copy"
                    tooltip: root.t("capture.card.copy")
                    onClicked: root.copyRequested(root.text)
                }

                Tip {
                    visible: root.done && root.url !== ""
                    icon: "open_in_new"
                    tooltip: root.t("capture.card.open")
                    onClicked: root.openRequested(root.url)
                }

                Tip {
                    icon: "close"
                    tooltip: root.t("capture.card.close")
                    onClicked: root.closed()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.phase === "loading"
                spacing: VitrailTokens.gap("sm")

                VitrailBusy {
                    running: root.phase === "loading"
                    size: VitrailTokens.size("subtitle")
                }

                VitrailText {
                    variant: "body"
                    text: root.message
                }
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.phase === "error"
                variant: "body"
                color: VitrailTokens.color("error")
                wrapMode: Text.WordWrap
                text: root.message
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.done
                variant: "body"
                wrapMode: Text.WordWrap
                maximumLineCount: VitrailTokens.capture.card.lines
                elide: Text.ElideRight
                text: root.text
            }
        }
    }
}
