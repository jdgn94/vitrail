import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// Sample bar element popup: shows the Python snapshot state and a live
// preference. The gear opens the bar-elements settings page.
Item {
    id: root

    property var strings: ({})
    property var data: ({})

    signal settingsRequested()

    implicitWidth: layout.implicitWidth + 2 * VitrailTokens.gap("md")
    implicitHeight: layout.implicitHeight + 2 * VitrailTokens.gap("md")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    ColumnLayout {
        id: layout

        x: VitrailTokens.gap("md")
        y: VitrailTokens.gap("md")
        width: 240
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "label"
                text: root.t("bar.widget.sample")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.data.message ? String(root.data.message) : "—"
            opacity: root.data.message ? 1.0 : 0.4

            Behavior on opacity {
                NumberAnimation { duration: VitrailTokens.duration("fast") }
            }
        }

        VitrailText {
            variant: "caption"
            text: root.data.updated
                  ? new Date(root.data.updated * 1000).toLocaleTimeString(Qt.locale(), "HH:mm")
                  : ""
            opacity: 0.5
            visible: text !== ""
        }
    }
}
