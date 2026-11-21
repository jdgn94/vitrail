import QtQuick
import "kit"
import "kit/base"

// Base for a bar element: the icon (or label) button every new element draws,
// its tooltip, the popup's open state, the "only while active" switch and the
// four inputs a bar element reads (click, middle click, right click, wheel).
// The shell wires `tooltips.hover()` and `shell.togglePopup()` from outside;
// docs/bar-elements.md has the recipe.
//
//     BarElementBase { icon: "widgets"; tooltip: "My element"; ... }
//
// An element whose face is not a button (a coloured dot, a pair of bars) sets
// `content` and keeps everything else.
Item {
    id: root

    property var strings: ({})
    property string icon: ""
    // A label after the icon; empty keeps the button icon-only.
    property string text: ""
    property string tone: "secondary"
    property string size: "sm"
    // What the pointer reads: the title, and an optional second line. Both are
    // live bindings to real data, never constants (AGENTS.md).
    property string tooltip: ""
    property string tooltipDetail: ""
    // "always": drawn regardless. "active": drawn only while `active` is true.
    // The shell binds it from the `barActiveOnly` preference (bar/elements.js).
    property string showMode: "always"
    // Whether the element has something to say; the element binds it.
    property bool active: true
    // This element's popup is the open one.
    property bool opened: false
    // Replaces the button as the element's face. The root keeps its size from
    // it, and a left click on it still emits `clicked`.
    property Component content: null

    signal clicked()
    signal middleClicked()
    signal rightClicked()
    // The wheel moved `delta` (Qt's angleDelta.y: 120 is one notch, up is positive).
    signal wheeled(int delta)

    // BarEntry reads this to collapse the element and remove its spacing.
    readonly property bool shown: root.showMode !== "active" || root.active
    readonly property alias hovered: hover.hovered

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: root.content !== null ? (face.item ? face.item.implicitWidth : 0) : button.implicitWidth
    implicitHeight: root.content !== null ? (face.item ? face.item.implicitHeight : 0) : button.implicitHeight

    VitrailButton {
        id: button

        anchors.fill: parent
        visible: root.content === null
        variant: root.opened ? "tonal" : "plain"
        tone: root.tone
        size: root.size
        icon: root.icon
        text: root.text
        onClicked: root.clicked()
    }

    Loader {
        id: face

        anchors.fill: parent
        sourceComponent: root.content
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        // The button owns the left click; a custom face has no MouseArea.
        enabled: root.content !== null
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.middleClicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (event) { root.wheeled(event.angleDelta.y) }
    }
}
