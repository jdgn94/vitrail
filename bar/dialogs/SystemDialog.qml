import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// A request from the system, in Vitrail's design: an icon, a title, the
// message, an optional secret field and the answers. Polkit asks for a
// password here; Hyprland asks about a frozen app or a permission.
//
// buttons: [{ key, label, variant, tone }]; the last one is the default and
// answers Enter. Escape picks the button whose key is `cancelKey`.
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string message: ""
    // A line under the message; `error` paints it in the error tone.
    property string detail: ""
    property bool error: false
    property bool secret: false
    property bool reveal: false
    property string prompt: ""
    property bool busy: false
    property var buttons: []
    property string cancelKey: ""

    signal answered(string key, string response)

    readonly property alias response: field.text

    implicitWidth: 420
    implicitHeight: body.implicitHeight + 2 * VitrailTokens.gap("lg")

    function answer(key) {
        root.answered(key, field.text)
        field.text = ""
    }

    function focusInput() {
        if (root.secret)
            field.forceActiveFocus()
        else
            root.forceActiveFocus()
    }

    // A wrong answer or a new error message shakes the field.
    onErrorChanged: if (root.error && root.secret) Qt.callLater(field.shake)
    onDetailChanged: if (root.error && root.secret) Qt.callLater(field.shake)

    Keys.onEscapePressed: if (root.cancelKey !== "") root.answer(root.cancelKey)
    Keys.onReturnPressed: if (root.buttons.length > 0) root.answer(root.buttons[root.buttons.length - 1].key)

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
        width: root.width - 2 * VitrailTokens.gap("lg")
        spacing: VitrailTokens.gap("md")

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: VitrailTokens.size("display") * 1.6
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.rgba(VitrailTokens.color(root.error ? "error" : "primary").r,
                           VitrailTokens.color(root.error ? "error" : "primary").g,
                           VitrailTokens.color(root.error ? "error" : "primary").b, 0.18)

            VitrailText {
                anchors.centerIn: parent
                variant: "icon"
                font.pixelSize: VitrailTokens.size("display")
                icon: root.icon
                color: VitrailTokens.color(root.error ? "error" : "primary")
            }
        }

        VitrailText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            variant: "subtitle"
            wrapMode: Text.Wrap
            text: root.title
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.message !== ""
            horizontalAlignment: Text.AlignHCenter
            variant: "content"
            wrapMode: Text.Wrap
            text: root.message
        }

        VitrailField {
            id: field

            Layout.fillWidth: true
            visible: root.secret
            enabled: !root.busy
            type: root.reveal ? "text" : "password"
            label: root.prompt
            error: root.error
            errorText: root.detail
            onAccepted: if (root.buttons.length > 0) root.answer(root.buttons[root.buttons.length - 1].key)
            onEscaped: if (root.cancelKey !== "") root.answer(root.cancelKey)
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.detail !== "" && !(root.error && root.secret)
            horizontalAlignment: Text.AlignHCenter
            variant: "label"
            wrapMode: Text.Wrap
            color: root.error ? VitrailTokens.color("error") : VitrailTokens.color("muted")
            text: root.detail
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: VitrailTokens.gap("xs")
            spacing: VitrailTokens.gap("sm")

            Repeater {
                model: root.buttons

                delegate: VitrailButton {
                    required property var modelData
                    required property int index
                    // The default button shows the wait; the others are off.
                    readonly property bool isDefault: index === root.buttons.length - 1

                    busy: root.busy && isDefault
                    enabled: !root.busy || isDefault
                    variant: modelData.variant || "flat"
                    tone: modelData.tone || "primary"
                    text: modelData.label
                    onClicked: root.answer(modelData.key)
                }
            }
        }
    }
}
