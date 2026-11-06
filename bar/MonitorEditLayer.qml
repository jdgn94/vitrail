import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/base"

// The monitor the settings window is editing, marked on its own screen: a
// thin accent frame and a card with the output's name and "Configuring".
//
// The window takes no input (an empty mask) and appears only on the output
// named by ~/.cache/vitrail/system/monitor-edit.ini, the small file the
// Monitors page writes while it is open.
PanelWindow {
    id: root

    required property var screen
    property var state: ({})
    property var strings: ({})
    property real opacityLevel: VitrailTokens.opacity

    readonly property bool active: root.state && root.state.active === true
                                   && root.state.name === root.screen.name
    readonly property color accent: VitrailTokens.color("primary", "#a8c7fa")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    visible: root.active
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

    // The frame: an accent line just inside the screen's edge.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: VitrailTokens.monitorEdit.frame
        border.color: root.accent
        opacity: root.opacityLevel
    }

    VitrailSurface {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: VitrailTokens.gap(VitrailTokens.monitorEdit.labelGap)
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

            Column {
                spacing: 0

                VitrailText {
                    variant: "body"
                    text: root.screen.name
                    color: VitrailTokens.color("foreground", "#e2e2e9")
                }

                VitrailText {
                    variant: "label"
                    text: root.t("monitors.editing")
                    color: root.accent
                }
            }
        }
    }
}
