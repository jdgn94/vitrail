import QtQuick
import "../kit"
import "../kit/base"

// One workspace pill: the app icon when the workspace holds a window, the
// workspace number otherwise, an accent fill while it is active and a dot
// while it is occupied. A click asks the shell to switch to it.
Item {
    id: root

    property string label: ""
    property bool active: false
    property bool occupied: false
    // The theme icon the caller resolved from the window's class ("" shows
    // the number instead).
    property string iconSource: ""
    // What the pointer reads (see references/tooltips.md).
    property string tooltip: ""
    property string tooltipDetail: ""

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed
    readonly property real artSize: VitrailTokens.size("subtitle")
    readonly property real pad: VitrailTokens.gap("xs")
    readonly property real horizontalPad: VitrailTokens.gap("sm")

    implicitWidth: Math.max(root.artSize, number.implicitWidth) + 2 * root.horizontalPad
    implicitHeight: root.artSize + 2 * root.pad

    // The accent fill: the active workspace stays lit, the others only under
    // the pointer.
    VitrailSurface {
        anchors.fill: parent
        radius: height / 2
        tint: VitrailTokens.color("primary", "#a8c7fa")
        opacityLevel: root.active ? 0.24 : root.hovered ? 0.12 : 0
        visible: root.active || root.hovered
    }

    Image {
        id: appIcon

        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.artSize, root.artSize)
        source: root.iconSource
        visible: source !== "" && status === Image.Ready
    }

    VitrailText {
        id: number

        anchors.centerIn: parent
        visible: !appIcon.visible
        variant: "label"
        font.weight: Font.DemiBold
        color: root.active ? VitrailTokens.color("primary", "#a8c7fa")
                           : VitrailTokens.color("foreground", "#e3e3e3")
        text: root.label
    }

    // Occupied: a dot under the number (or the app icon), lighter on the
    // active fill so it stays visible.
    Rectangle {
        width: VitrailTokens.gap("xs")
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        visible: root.occupied
        color: root.active ? VitrailTokens.color("accentForeground", "#002f65")
                           : VitrailTokens.color("primary", "#a8c7fa")
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
