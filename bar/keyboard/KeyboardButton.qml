import QtQuick
import "../kit"
import "../kit/base"
import "keyboard.js" as Keyboard

// The keyboard chip: the live layout(s) on the focused keyboard. Left click
// opens the switcher, right click the on-screen keyboard.
Item {
    id: root

    property bool opened: false
    property var strings: ({})
    // What `hyprctl devices -j` printed, parsed by the shell.
    property var keyboards: []

    signal clicked()
    signal rightClicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    // What the pointer reads: the layout(s) of each keyboard configuration,
    // then the combination that changes them and what each click opens.
    property string tooltip: Keyboard.tooltip(root.keyboards) || root.t("keyboard.chip")
    property string tooltipDetail: {
        var combination = Keyboard.mainSwitch(root.keyboards)
        return combination !== "" ? combination + " · " + root.t("keyboard.chip.hint")
                                  : root.t("keyboard.chip.hint")
    }

    implicitWidth: row.implicitWidth + 2 * VitrailTokens.gap("sm")
    implicitHeight: row.implicitHeight + 2 * VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: root.opened || root.hovered
        color: VitrailTokens.solid("primary", root.opened ? 0.16 : 0.08)

        Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: VitrailTokens.gap("xs")

        VitrailText {
            anchors.verticalCenter: parent.verticalCenter
            variant: "icon"
            text: "keyboard"
            color: root.opened ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
        }

        VitrailText {
            anchors.verticalCenter: parent.verticalCenter
            variant: "content"
            font.weight: Font.DemiBold
            text: Keyboard.chipText(root.keyboards)
            color: root.opened ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }
}
