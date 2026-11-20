import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/base"

// Every output is marked while the settings window is open: a card at the top
// centre with the output's name, so the canvas and the physical screens meet.
//
// `output` is the Quickshell screen this layer belongs to. The PanelWindow's
// own `screen` is bound to it below: a property named `screen` on this type
// would shadow the window's, and every layer would end up on the default
// output.
//
// The window takes no input (an empty mask) and appears on every output while
// the Monitors page is open, named by ~/.cache/vitrail/system/monitor-edit.ini
// (the small file the page writes).
PanelWindow {
    id: root

    required property var output
    property var state: ({})
    property real opacityLevel: VitrailTokens.opacity

    readonly property bool active: root.state && root.state.active === true
    readonly property color accent: VitrailTokens.color("muted", "#c4c6d0")

    visible: root.active
    screen: root.output
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    VitrailSurface {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: VitrailTokens.gap(VitrailTokens.monitorEdit.top)
        width: Math.min(root.width - 2 * VitrailTokens.gap("lg"),
                        VitrailTokens.monitorEdit.label)
        height: body.implicitHeight + 2 * VitrailTokens.gap("md")
        radius: VitrailTokens.radius
        tint: VitrailTokens.color("surfaceHigh", "#282a2f")
        opacityLevel: root.opacityLevel

        RowLayout {
            id: body

            anchors.centerIn: parent
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "monitor"
                size: "md"
                color: root.accent
            }

            VitrailText {
                variant: "body"
                text: root.output ? root.output.name : ""
                color: VitrailTokens.color("foreground", "#e2e2e9")
            }
        }
    }
}
