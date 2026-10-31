import QtQuick
import QtQuick.Layouts

// Single-choice segmented control. One pill marks the choice and slides to
// the new one when it changes. An option is { key, label, icon }: `icon` is an
// optional Material Symbol before the label (alone when the label is empty),
// drawn in the label's colour and filled when the option is chosen.
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

                readonly property bool chosen: root.current === segment.modelData.key
                readonly property color ink: segment.chosen ? root.onAccent : root.foreground

                Layout.fillHeight: true
                implicitWidth: content.implicitWidth + (label.text === "" ? 20 : 28)

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: glyph

                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: segment.modelData.icon || ""
                        color: segment.ink
                        font.family: VitrailTokens.iconFamily
                        font.variableAxes: ({ "FILL": segment.chosen ? 1 : 0 })
                        font.pixelSize: 18

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
