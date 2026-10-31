import QtQuick
import QtQuick.Layouts

// Horizontal subcategory tabs. One underline marks the current tab and
// slides to the new one when it changes.
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

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 22

        Repeater {
            id: items

            model: root.tabs

            delegate: Item {
                id: tab

                required property var modelData

                Layout.preferredHeight: parent.height
                implicitWidth: label.implicitWidth

                Text {
                    id: label

                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.label
                    color: root.current === tab.modelData.key ? root.accent : root.foreground
                    opacity: root.current === tab.modelData.key ? 1 : 0.6
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: VitrailTokens.fontFamily

                    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }
                    Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
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
}
