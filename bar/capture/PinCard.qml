import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// A pinned area: the picture on a glass surface, drawn at `zoom`. The pointer
// moves it (drag), the wheel zooms around the pointer, Ctrl+wheel changes its
// opacity, a double click or Escape closes it, and while the pointer is over
// it a small bar offers the opacity slider and a close button. It only reports
// what the user did; the window owner moves and resizes.
Item {
    id: root

    property var t: function (key) {
        return key
    }
    property string image: ""
    // The picture's size at zoom 1, in logical px.
    property real baseWidth: 100
    property real baseHeight: 100
    property real zoom: 1
    // 0.2..1: how much of the pin shows.
    property real level: 1

    // Drag: the pointer's move since the last report; wheel: a factor and where.
    signal dragged(real dx, real dy)
    signal zoomed(real factor, point anchor)
    signal faded(real delta)
    signal levelSet(real level)
    signal closed()

    readonly property real pad: VitrailTokens.gap("xs")
    readonly property bool over: hover.hovered || fade.pressed

    implicitWidth: Math.round(root.baseWidth * root.zoom) + 2 * root.pad
    implicitHeight: Math.round(root.baseHeight * root.zoom) + 2 * root.pad
    opacity: root.level
    focus: true

    Keys.onEscapePressed: root.closed()

    HoverHandler {
        id: hover
    }

    VitrailSurface {
        anchors.fill: parent
        radius: VitrailTokens.gap("sm")

        Image {
            anchors.fill: parent
            anchors.margins: root.pad
            source: root.image !== "" ? "file://" + root.image : ""
            fillMode: Image.Stretch
            smooth: root.zoom < 1
            cache: false
        }
    }

    MouseArea {
        id: grab

        property real lastX: 0
        property real lastY: 0

        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: function (mouse) {
            root.forceActiveFocus()
            grab.lastX = mouse.x
            grab.lastY = mouse.y
        }
        onPositionChanged: function (mouse) {
            if (!grab.pressed)
                return
            root.dragged(mouse.x - grab.lastX, mouse.y - grab.lastY)
        }
        onDoubleClicked: root.closed()
        onWheel: function (wheel) {
            var up = wheel.angleDelta.y > 0
            if (wheel.modifiers & Qt.ControlModifier)
                root.faded(up ? VitrailTokens.capture.pin.opacityStep : -VitrailTokens.capture.pin.opacityStep)
            else
                root.zoomed(up ? VitrailTokens.capture.pin.zoomStep : 1 / VitrailTokens.capture.pin.zoomStep,
                            Qt.point(wheel.x, wheel.y))
        }
    }

    // Opacity and close, over the top edge while the pointer is on the pin.
    VitrailSurface {
        id: bar

        visible: root.over
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: VitrailTokens.gap("xs")
        width: Math.min(row.implicitWidth + 2 * VitrailTokens.gap("xs"), root.width - 2 * VitrailTokens.gap("xs"))
        height: row.implicitHeight + VitrailTokens.gap("xs")
        radius: VitrailTokens.gap("md")

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: VitrailTokens.gap("xs")

            VitrailSlider {
                id: fade

                Layout.preferredWidth: VitrailTokens.slider.length / 2
                size: "sm"
                from: VitrailTokens.capture.pin.opacityMin
                to: 1
                stepSize: VitrailTokens.capture.pin.opacityStep
                value: root.level
                icon: "opacity"
                onMoved: function (value) { root.levelSet(value) }
            }

            VitrailButton {
                variant: "text"
                tone: "secondary"
                size: "sm"
                icon: "close"
                onClicked: root.closed()
            }
        }
    }
}
