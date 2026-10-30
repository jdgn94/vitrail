import QtQuick
import QtQuick.Layouts
import "kit"
import "network"

// The bar's buttons, grouped and laid out along the bar direction.
GridLayout {
    id: root

    property bool vertical: false
    property string openKind: ""
    property bool open: false

    signal networkClicked()
    signal barHovered(string kind)

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: VitrailTokens.gap("xs")
    columnSpacing: VitrailTokens.gap("xs")

    NetworkButton {
        id: network

        vertical: root.vertical
        opened: root.open && root.openKind === "network"
        onClicked: root.networkClicked()
        onHoveredChanged: if (hovered && root.open) root.barHovered("network")
    }
}
