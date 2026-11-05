import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../kit"
import "../kit/base"
import "../kit/composed"
import "keyboard.js" as Keyboard

// The on-screen keyboard as a floating window: an overlay layer over the
// focused screen, its card draggable and kept on screen. It is not focusable
// and asks for no keyboard, so the bar's typed/key signals can keep sending
// `wtype` to the active application. Only its close button or Escape puts it
// away; a click outside is not its business and goes through to the app.
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
    // Only the card takes the pointer; the rest of the screen is the app's.
    mask: Region {
        item: card
    }

    onLanguageChanged: root.shownLanguage = Keyboard.language(root.language)
    Component.onCompleted: root.shownLanguage = Keyboard.language(root.language)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Item {
        id: card

        property bool moved: false
        readonly property real pad: VitrailTokens.gap("lg")

        width: content.implicitWidth + 2 * pad
        height: content.implicitHeight + 2 * pad

        function place() {
            x = Math.max(0, (root.width - width) / 2)
            y = Math.max(0, root.height - height - VitrailTokens.gap("lg"))
        }

        onWidthChanged: if (!card.moved) card.place()
        onHeightChanged: if (!card.moved) card.place()
        Component.onCompleted: card.place()

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

        // Dragging on the card background; keys and the header sit above it.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            drag.target: card
            drag.minimumX: 0
            drag.maximumX: Math.max(0, root.width - card.width)
            drag.minimumY: 0
            drag.maximumY: Math.max(0, root.height - card.height)
            onPressed: card.moved = true
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: card.pad
            spacing: VitrailTokens.gap("sm")

            RowLayout {
                id: header

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

    onShownChanged: {
        if (root.shown) {
            card.moved = false
            Qt.callLater(function () { card.place() })
        }
    }

    // The window is created before it has a size; place the card once it does,
    // and reset it to the bottom centre on every opening.
    onWidthChanged: if (root.shown && !card.moved) card.place()
    onHeightChanged: if (root.shown && !card.moved) card.place()
}
