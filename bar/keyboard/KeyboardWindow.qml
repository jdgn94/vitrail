import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../kit"

// The on-screen keyboard as a floating window: an overlay layer centred at the
// bottom of the focused screen. It is not focusable and asks for no keyboard,
// so `wtype` keeps typing into the active application. The whole layer takes
// the pointer only to notice a click outside; the card itself is the only
// visible part.
PanelWindow {
    id: root

    property var strings: ({})
    // The language code of the active layout (an unsupported one falls to en).
    property string language: "en"
    property bool shown: false

    signal keyPressed(var argv)
    signal dismissed()

    screen: Quickshell.screens[0] || null
    visible: root.shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-keyboard"
    WlrLayershell.layer: WlrLayer.Overlay
    // No keyboard: the focused app keeps it and `wtype` types there.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    focusable: false

    // The layer is full screen so a click outside the card can close it. The
    // card is above this catcher and its buttons take their own clicks.
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Item {
        id: card

        readonly property real pad: VitrailTokens.gap("lg")

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: VitrailTokens.gap("lg")
        width: osk.implicitWidth + 2 * pad
        height: osk.implicitHeight + 2 * pad

        RectangularShadow {
            anchors.fill: surface
            radius: surface.radius
            blur: VitrailTokens.blur * 2
            offset.y: VitrailTokens.gap("xs")
            color: Qt.rgba(0, 0, 0, 0.4)
        }

        VitrailSurface {
            id: surface

            anchors.fill: parent
            radius: VitrailTokens.radius
        }

        KeyboardOSK {
            id: osk

            anchors.fill: parent
            anchors.margins: card.pad
            strings: root.strings
            language: root.language
            onKeyPressed: function (argv) { root.keyPressed(argv) }
            onDismissed: root.dismissed()
        }
    }
}
