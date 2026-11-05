import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../kit"
import "../kit/base"
import "../kit/composed"
import "keyboard.js" as Keyboard

// The on-screen keyboard as a floating window: an overlay layer centred at the
// bottom of the focused screen. It is not focusable and asks for no keyboard,
// so the bar's typed/key signals can keep sending `wtype` to the active
// application. The whole layer takes the pointer only to notice a click
// outside; the card itself is the only visible part.
PanelWindow {
    id: root

    property var strings: ({})
    // The language code of the active layout (an unsupported one falls to en).
    property string language: "en"
    property bool shown: false
    // The layout the keyboard is drawing; the language button cycles it
    // without stealing the system layout.
    property string shownLanguage: "en"

    signal typed(string text)
    signal key(string name)
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
    // No keyboard: the focused app keeps it and the bar's `wtype` types there.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    focusable: false

    onLanguageChanged: root.shownLanguage = Keyboard.language(root.language)
    Component.onCompleted: root.shownLanguage = Keyboard.language(root.language)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

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
        width: content.implicitWidth + 2 * pad
        height: content.implicitHeight + 2 * pad

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

        // A click on the card itself, between the keys, must not close it.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: card.pad
            spacing: VitrailTokens.gap("sm")

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    Layout.fillWidth: true
                    variant: "subtitle"
                    text: root.t("keyboard.osk")
                }

                VitrailButton {
                    size: "sm"
                    variant: "plain"
                    tone: "secondary"
                    icon: "close"
                    onClicked: root.dismissed()
                }
            }

            VitrailKeyboard {
                Layout.fillWidth: true
                layout: root.shownLanguage
                onTyped: function (text) { root.typed(text) }
                onKey: function (name) { root.key(name) }
                onLayoutRequested: function (layout) { root.shownLanguage = layout }
            }
        }
    }
}
