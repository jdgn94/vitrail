import QtQuick
import QtQuick.Layouts
import "base"

// Horizontal subcategory tabs. One underline marks the current tab and
// slides to the new one when it changes. A tab is { key, label, icon }: `icon`
// is an optional Material Symbol before the label, drawn in the label's colour
// and opacity (accent when the tab is current, never filled); the underline
// spans both.
//
// When the tabs do not fit the width the control was given, the row scrolls
// sideways under the underline (wheel, drag or touch): the underline keeps its
// size and nothing is cut off.
//
// Keyboard: one stop for the group; Left / Right move the current tab.
Item {
    id: root

    property var tabs: []
    property string current: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")

    signal selected(string key)

    readonly property int currentIndex: root.tabs.findIndex(function (tab) {
        return tab.key === root.current
    })
    readonly property Item currentItem: items.count > 0 && root.currentIndex >= 0
                                        ? items.itemAt(root.currentIndex) : null
    property bool settled: false

    implicitHeight: 40
    // What the tabs need; the row scrolls when the control is narrower.
    implicitWidth: row.implicitWidth
    // The scroll position, for a caller that draws its own affordance.
    readonly property real contentX: flick.contentX
    readonly property real contentWidth: row.width

    Component.onCompleted: Qt.callLater(function () { root.settled = true })
    // The chosen tab is always brought into view, however far the row was
    // scrolled.
    onCurrentChanged: revealing.restart()
    // The chosen item is shown again once the control has a width (a tab set
    // before the row was laid out).
    onWidthChanged: revealing.restart()

    // One tick after the change, so the items have their new positions. A timer
    // of our own, not Qt.callLater: a delayed call outlives the object it was
    // meant for and throws when the bar reloads.
    Timer {
        id: revealing

        interval: 0
        onTriggered: root.reveal(root.currentItem)
    }

    function reveal(item) {
        // Before the first layout there is no view to scroll in: the row would
        // end up scrolled past its own first item.
        if (!item || flick.width <= 0)
            return
        // Everything fits: there is nothing to reveal, and a row that was
        // scrolled while the control was narrower goes back to its start.
        if (flick.contentWidth <= flick.width) {
            flick.contentX = 0
            return
        }
        var left = item.x
        var right = item.x + item.width
        if (left < flick.contentX)
            flick.contentX = left
        else if (right > flick.contentX + flick.width)
            flick.contentX = right - flick.width
    }

    function step(delta) {
        if (root.tabs.length === 0)
            return
        var index = root.currentIndex < 0 ? 0
                                           : (root.currentIndex + delta + root.tabs.length) % root.tabs.length
        root.selected(root.tabs[index].key)
    }

    activeFocusOnTab: root.enabled
    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)

    Flickable {
        id: flick

        anchors.fill: parent
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

        RowLayout {
            id: row

            width: Math.max(implicitWidth, flick.width)
            height: flick.height
            spacing: 22

            Repeater {
                id: items

                model: root.tabs

                delegate: Item {
                    objectName: "tab" + index
                    id: tab

                    required property var modelData
                    required property int index

                    readonly property bool chosen: root.current === tab.modelData.key

                    Layout.fillHeight: true
                    implicitWidth: content.implicitWidth

                    Row {
                        id: content

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: VitrailTokens.gap("sm")
                        opacity: tab.chosen ? 1 : 0.6

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }

                        VitrailIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: (tab.modelData.icon || "") !== ""
                            icon: tab.modelData.icon || ""
                            color: tab.chosen ? root.accent : root.foreground
                            pixelSize: 18

                            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.label
                            color: tab.chosen ? root.accent : root.foreground
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.family: VitrailTokens.fontFamily

                            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(tab.modelData.key)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            x: root.currentItem ? root.currentItem.x : 0
            y: flick.height - height
            width: root.currentItem ? root.currentItem.width : 0
            height: 3
            radius: height / 2
            visible: root.currentItem !== null
            color: root.accent

            Behavior on x { enabled: root.settled; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on width { enabled: root.settled; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
        }

        // Where the keyboard is.
        Rectangle {
            x: (root.currentItem ? root.currentItem.x : 0) - VitrailTokens.gap("sm")
            y: 2
            width: (root.currentItem ? root.currentItem.width : 0) + 2 * VitrailTokens.gap("sm")
            height: flick.height - 4
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: root.accent
            visible: root.activeFocus && root.currentItem !== null
        }
    }
}
