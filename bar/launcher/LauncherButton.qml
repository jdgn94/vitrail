import QtQuick
import "../kit"
import "../kit/base"

// The bar's main button: a left click opens the full-screen launcher (Super
// alone does the same, see hyprland.lua), a right click the compact popout.
// Both go through `vitrail-bar ipc call launcher toggle` / `popout`.
VitrailButton {
    id: root

    property var strings: ({})
    // Its launcher is open: the card says it all, the tooltip stays quiet.
    property bool opened: false

    signal menuRequested()

    // What the pointer reads: the launcher and what each click does.
    property string tooltip: root.t("tooltip.launcher")
    property string tooltipDetail: root.t("tooltip.launcherHint")

    variant: "tonal"
    icon: "apps"

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The button's own area takes the left click; this one only the right.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.menuRequested()
    }
}
