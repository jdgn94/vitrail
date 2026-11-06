import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// One connection: icon, name and detail, and its connect button (without an
// `action`, the whole row is the button). The active one is tinted; the others
// light up under the pointer.
Item {
    id: entry

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string action: ""
    // Optional connection quality (good / fair / poor / unknown) and its
    // measurement; "" leaves the slot out.
    property string quality: ""
    property string qualityText: ""
    property bool active: false
    property bool busy: false

    signal triggered()

    Layout.fillWidth: true
    implicitHeight: line.implicitHeight + 2 * VitrailTokens.gap("xs")

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        visible: entry.active || hover.hovered
        color: entry.active ? VitrailTokens.solid("primary", 0.14) : VitrailTokens.solid("foreground", 0.06)

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
    }

    HoverHandler {
        id: hover
    }

    // Keyboard: a row that is a choice is reached with Tab and picked with
    // Enter or Space; a row with a button leaves that to the button.
    activeFocusOnTab: entry.action === "" && !entry.busy
    Keys.onReturnPressed: if (entry.action === "") entry.triggered()
    Keys.onSpacePressed: if (entry.action === "") entry.triggered()

    // A row without a button is a choice: the whole row picks it.
    MouseArea {
        anchors.fill: parent
        enabled: entry.action === ""
        cursorShape: Qt.PointingHandCursor
        onClicked: entry.triggered()
    }

    // Where the keyboard is.
    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: "transparent"
        border.width: entry.activeFocus ? 2 : 0
        border.color: VitrailTokens.color("primary")
        visible: entry.activeFocus
    }

    RowLayout {
        id: line

        anchors.verticalCenter: parent.verticalCenter
        x: VitrailTokens.gap("sm")
        width: parent.width - 2 * VitrailTokens.gap("sm")
        spacing: VitrailTokens.gap("sm")

        VitrailIcon {
            // Glyphs differ in width; a fixed slot keeps the names aligned.
            Layout.preferredWidth: VitrailTokens.size("display")
            icon: entry.icon
            color: entry.active ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                font.weight: entry.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                text: entry.title
            }

            VitrailText {
                Layout.fillWidth: true
                visible: entry.subtitle !== ""
                variant: "label"
                elide: Text.ElideRight
                text: entry.subtitle
            }
        }

        VitrailQuality {
            visible: entry.quality !== ""
            level: entry.quality
            text: entry.qualityText
        }

        VitrailButton {
            visible: entry.action !== ""
            busy: entry.busy
            variant: entry.active ? "outlined" : "tonal"
            tone: entry.active ? "secondary" : "primary"
            text: entry.action
            onClicked: entry.triggered()
        }
    }
}
