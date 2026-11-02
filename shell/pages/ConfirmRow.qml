import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// An inline question for something that cannot be undone: the message, a way
// out and the action. The way out has the focus when it opens, so Enter does
// not destroy anything; Escape cancels.
RowLayout {
    id: root

    property string message: ""
    property string confirmText: ""
    property string cancelText: ""

    signal confirmed()
    signal cancelled()

    Layout.fillWidth: true
    spacing: VitrailTokens.gap("sm")
    onVisibleChanged: if (root.visible) cancel.forceActiveFocus()
    Keys.onEscapePressed: root.cancelled()

    VitrailText {
        Layout.fillWidth: true
        variant: "content"
        wrapMode: Text.WordWrap
        text: root.message
    }

    VitrailButton {
        id: cancel

        variant: "outlined"
        tone: "secondary"
        text: root.cancelText
        onClicked: root.cancelled()
    }

    VitrailButton {
        variant: "flat"
        tone: "error"
        text: root.confirmText
        onClicked: root.confirmed()
    }
}
