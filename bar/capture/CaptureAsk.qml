import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "capture.js" as Capture

// The question card of "Ask AI": a glass pill with the text field and the
// submit button, shown in the toolbar's seat once the user chose the action.
// Enter or the button submits (an empty question sends just the picture),
// Escape goes back to the toolbar. The overlay sends nothing before that.
Item {
    id: root

    property var t: function (key) {
        return key
    }

    signal submitted(string text)
    signal back()

    implicitWidth: card.width
    implicitHeight: card.height

    // Takes the keyboard, with an empty field.
    function open() {
        field.text = ""
        field.forceActiveFocus()
    }

    function submit() {
        root.submitted(Capture.question(field.text))
    }

    VitrailSurface {
        id: card

        anchors.centerIn: parent
        width: body.implicitWidth + 2 * VitrailTokens.gap("sm")
        height: body.implicitHeight + 2 * VitrailTokens.gap("xs")
        radius: VitrailTokens.radius

        RowLayout {
            id: body

            anchors.centerIn: parent
            spacing: VitrailTokens.gap("xs")

            VitrailField {
                id: field

                Layout.preferredWidth: VitrailTokens.capture.ask.width
                size: "sm"
                leadingIcon: "auto_awesome"
                placeholder: root.t("capture.ask.placeholder")
                onAccepted: root.submit()
                onEscaped: root.back()
            }

            Item {
                implicitWidth: send.implicitWidth
                implicitHeight: send.implicitHeight

                VitrailButton {
                    id: send

                    anchors.fill: parent
                    variant: "filled"
                    size: "sm"
                    icon: "arrow_upward"
                    onClicked: root.submit()
                }

                VitrailTooltip {
                    text: root.t("capture.ask.submit")
                    detail: root.t("capture.ask.submit.detail")
                    active: send.hovered
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: VitrailTokens.gap("xs")
                }
            }
        }
    }
}
