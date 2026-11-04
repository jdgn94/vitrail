import QtQuick
import QtQuick.Layouts

// Horizontal subcategory tabs. One underline marks the current tab and
// slides to the new one when it changes. A tab is { key, label, icon }: `icon`
// is an optional Material Symbol before the label, drawn in the label's colour
// and opacity and filled when the tab is current; the underline spans both.
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
    // What the tabs need; a caller with many tabs scrolls them.
    implicitWidth: row.implicitWidth

    Component.onCompleted: Qt.callLater(function () { root.settled = true })

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

    RowLayout {
        id: row

        anchors.fill: parent
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

                Layout.preferredHeight: parent.height
                implicitWidth: content.implicitWidth

                Row {
                    id: content

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: VitrailTokens.gap("sm")
                    opacity: tab.chosen ? 1 : 0.6

                    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: tab.modelData.icon || ""
                        color: tab.chosen ? root.accent : root.foreground
                        font.family: VitrailTokens.iconFamily
                        font.variableAxes: ({ "FILL": tab.chosen ? 1 : 0 })
                        font.pixelSize: 18

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
        anchors.bottom: parent.bottom
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
        height: root.height - 4
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: root.accent
        visible: root.activeFocus && root.currentItem !== null
    }
}
