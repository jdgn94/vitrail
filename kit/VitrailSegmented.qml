import QtQuick
import QtQuick.Layouts

// Single-choice segmented control. One pill marks the choice and slides to
// the new one when it changes.
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

    Rectangle {
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

        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            id: segments

            model: root.options

            delegate: Item {
                id: segment

                required property var modelData

                Layout.fillHeight: true
                implicitWidth: label.implicitWidth + 28

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: segment.modelData.label
                    color: root.current === segment.modelData.key ? root.onAccent : root.foreground
                    font.pixelSize: 13
                    font.family: VitrailTokens.fontFamily

                    Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }
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
