import QtQuick
import "kit"
import "kit/base"

// Base for a new-style bar element: standard icon button, visibility mode,
// tooltip/opened/hovered interface. The shell wires tooltip.hover() and
// shell.togglePopup() from outside; this component owns the shown logic.
//
// Use as a root type in an element's Button.qml:
//     BarElementBase { icon: "widgets"; tooltip: "My element"; ... }
Item {
    id: root

    property string icon: ""
    property string tooltip: ""
    property string tooltipDetail: ""
    // "always": visible regardless. "active": hidden when `active` is false.
    property string showMode: "always"
    property bool active: true
    property bool opened: false

    signal clicked()

    // BarEntry reads this to collapse the element and remove its spacing.
    readonly property bool shown: root.showMode !== "active" || root.active
    readonly property alias hovered: hover.hovered

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    VitrailButton {
        id: button

        anchors.fill: parent
        variant: "plain"
        icon: root.icon
        tone: root.opened ? "primary" : "secondary"
        onClicked: root.clicked()
    }

    HoverHandler {
        id: hover
    }
}
