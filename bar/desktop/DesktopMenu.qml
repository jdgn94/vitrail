import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The desktop's right-click menu: one card with the entry that opens the
// in-place editor. The layer around it closes the menu on an outside click.
Item {
    id: root

    property var strings: ({})

    signal editRequested()
    signal dismissed()

    implicitWidth: VitrailTokens.desktopEdit.menu
    implicitHeight: card.implicitHeight + 2 * VitrailTokens.gap("xs")
    width: implicitWidth
    height: implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }


    VitrailSurface {
        anchors.fill: parent
        radius: VitrailTokens.radius
        tint: VitrailTokens.color("surfaceHigh", "#282a2f")
    }

    ColumnLayout {
        id: card

        anchors.fill: parent
        anchors.margins: VitrailTokens.gap("xs")
        spacing: VitrailTokens.gap("xs")

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VitrailTokens.gap("sm")
            Layout.rightMargin: VitrailTokens.gap("sm")
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "desktop_windows"
                size: "sm"
                tone: "secondary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "label"
                elide: Text.ElideRight
                text: root.t("desktop.menu.title")
            }
        }

        VitrailButton {
            objectName: "desktopMenuEdit"

            Layout.fillWidth: true
            variant: "text"
            icon: "tune"
            text: root.t("desktop.menu.edit")
            onClicked: root.editRequested()
        }
    }
}
