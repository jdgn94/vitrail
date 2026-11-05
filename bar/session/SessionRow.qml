import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "actions.js" as Session

// The session actions as a compact row of icons, for the panel's widgets slot.
// The commands belong to the shell (`runSession`); this only reports the
// choice. Lock, log out, reboot and power off: the four the panel offers.
RowLayout {
    id: root

    readonly property var offered: ["lock", "logout", "reboot", "poweroff"].map(function (key) {
        return Session.find(key)
    }).filter(function (action) { return action !== null })

    signal chosen(string key)

    // sm / md / lg: the buttons grow with the panel widget's size.
    property string size: "md"

    spacing: VitrailTokens.gap("xs")

    Repeater {
        model: root.offered

        delegate: VitrailButton {
            required property var modelData

            Layout.fillWidth: true
            variant: "text"
            size: root.size
            tone: modelData.tone
            icon: modelData.icon
            onClicked: root.chosen(modelData.key)
        }
    }
}
