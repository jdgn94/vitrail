import QtQuick
import QtQuick.Layouts
import "base"

// Single-choice segmented control. One pill marks the choice and slides to
// the new one when it changes. An option is { key, label, icon }: `icon` is an
// optional Material Symbol before the label (alone when the label is empty),
// drawn in the label's colour — the accent ink on the pill, never filled.
//
// When the options do not fit the width the control was given, the row scrolls
// sideways under the pill (wheel, drag or touch): the pill keeps its size and
// nothing is cut off.
Rectangle {
    id: root

    property var options: []
    property string current: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")
    property color onAccent: VitrailTokens.color("accentForeground", Qt.darker(root.accent, 2.6))

    signal selected(string key)

    readonly property int currentIndex: root.options.findIndex(function (option) {
        return option.key === root.current
    })
    readonly property Item currentItem: segments.count > 0 && root.currentIndex >= 0
                                        ? segments.itemAt(root.currentIndex) : null
    // The first placement does not slide in from the left edge.
    property bool settled: false

    implicitHeight: 36
    implicitWidth: row.implicitWidth + 8
    radius: height / 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

    Component.onCompleted: Qt.callLater(function () { root.settled = true })

    // The chosen option is always brought into view, however far the row was
    // scrolled.
    onCurrentChanged: Qt.callLater(function () { root.reveal(root.currentItem) })

    function reveal(item) {
        if (!item)
            return
        var left = item.x
        var right = item.x + item.width
        if (left < flick.contentX)
            flick.contentX = left
        else if (right > flick.contentX + flick.width)
            flick.contentX = right - flick.width
    }

    // Keyboard: one stop for the group; Left / Right move the choice.
    function step(delta) {
        if (root.options.length === 0)
            return
        var index = root.currentIndex < 0 ? 0
                                           : (root.currentIndex + delta + root.options.length) % root.options.length
        root.selected(root.options[index].key)
    }

    activeFocusOnTab: root.enabled
    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: 4
        clip: true
        contentWidth: row.width
        contentHeight: height
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentX { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

        WheelHandler {
            onWheel: function (event) {
                flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width,
                                                      flick.contentX - event.angleDelta.y - event.angleDelta.x))
            }
        }

        Rectangle {
            id: indicator

            x: row.x + (root.currentItem ? root.currentItem.x : 0)
            y: row.y
            width: root.currentItem ? root.currentItem.width : 0
            height: row.height
            radius: height / 2
            visible: root.currentItem !== null
            color: root.accent

            Behavior on x { enabled: root.settled; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on width { enabled: root.settled; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        }

        RowLayout {
            id: row

            y: 0
            width: Math.max(implicitWidth, flick.width)
            height: flick.height
            spacing: 4

            Repeater {
                id: segments

                model: root.options

                delegate: Item {
                    id: segment

                    required property var modelData

                    readonly property bool chosen: root.current === segment.modelData.key
                    readonly property color ink: segment.chosen ? root.onAccent : root.foreground

                    Layout.fillHeight: true
                    implicitWidth: content.implicitWidth + (label.text === "" ? 20 : 28)

                    Row {
                        id: content

                        anchors.centerIn: parent
                        spacing: 6

                        VitrailIcon {
                            id: glyph

                            anchors.verticalCenter: parent.verticalCenter
                            visible: (segment.modelData.icon || "") !== ""
                            icon: segment.modelData.icon || ""
                            color: segment.ink
                            pixelSize: 18

                            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
                        }

                        Text {
                            id: label

                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== ""
                            text: segment.modelData.label || ""
                            color: segment.ink
                            font.pixelSize: 13
                            font.family: VitrailTokens.fontFamily

                            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(segment.modelData.key)
                    }
                }
            }
        }
    }

    // Where the keyboard is.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: root.accent
        visible: root.activeFocus
    }
}
