pragma ComponentBehavior: Bound
import QtQuick
import "../kit"
import "../kit/base"

// The colours of an option bar: the six swatches of the tokens, the custom
// colour the user made (a seventh, once there is one) and the button that
// makes it. The chosen one wears a ring in the accent.
Row {
    id: root

    property var t: function (key) {
        return key
    }
    property string current: ""
    property string custom: ""

    signal picked(string hex)
    signal customRequested()

    readonly property var editor: VitrailTokens.capture.editor

    spacing: VitrailTokens.gap("xs")

    Repeater {
        model: root.custom !== "" ? root.editor.color.swatches.concat([root.custom]) : root.editor.color.swatches

        delegate: Item {
            id: swatch

            required property string modelData

            readonly property bool chosen: swatch.modelData.toLowerCase() === root.current.toLowerCase()

            width: root.editor.color.swatch + 2 * root.editor.color.ring + 2
            height: width
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: swatch.chosen ? root.editor.color.ring : 0
                border.color: VitrailTokens.color("primary")
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.editor.color.swatch
                height: width
                radius: width / 2
                color: swatch.modelData
                border.width: 1
                border.color: VitrailTokens.color("outline")
                scale: hover.hovered ? 1.1 : 1

                Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.picked(swatch.modelData)
            }

            VitrailTooltip {
                text: swatch.modelData.toUpperCase()
                active: hover.hovered
                edge: "bottom"
                x: (swatch.width - width) / 2
                y: -height - VitrailTokens.gap("xs")
            }
        }
    }

    EditorAction {
        anchors.verticalCenter: parent.verticalCenter
        icon: "add"
        variant: "outlined"
        tooltip: root.t("capture.editor.custom")
        tooltipDetail: root.t("capture.editor.custom.detail")
        onClicked: root.customRequested()
    }
}
