import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "resources.js" as Resources

// One graph of the Resources popup: the name and the current value on top, the
// history below. `second` is an optional second series drawn over the first on
// the same axis (the network's upload over its download). A series with no
// reading at all swaps the graph for one calm line (`missing`), so a machine
// without a thermal zone or a disk is told instead of shown a flat zero.
ColumnLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string valueText: "--"
    property var values: []
    property var second: null
    property real maximum: 100
    property string tone: "primary"
    property string secondTone: "info"
    // What the calm line says when nothing has ever been read.
    property string missing: ""
    readonly property bool hasData: Resources.hasData({ a: root.values }, "a")
                                    || (root.second !== null && Resources.hasData({ a: root.second }, "a"))

    spacing: VitrailTokens.gap("xs")

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        VitrailIcon {
            icon: root.icon
            size: "sm"
            container: false
            tone: "secondary"
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            elide: Text.ElideRight
            text: root.label
        }

        VitrailText {
            objectName: "value"

            variant: "label"
            opacity: 1
            font.features: ({ "tnum": 1 })
            text: root.valueText
        }
    }

    VitrailSparkline {
        objectName: "graph"

        Layout.fillWidth: true
        visible: root.hasData
        values: root.values
        maximum: root.maximum
        capacity: Resources.CAPACITY
        tone: root.tone

        VitrailSparkline {
            objectName: "secondGraph"

            anchors.fill: parent
            visible: root.second !== null
            values: root.second || []
            maximum: root.maximum
            capacity: Resources.CAPACITY
            tone: root.secondTone
            showGrid: false
        }
    }

    VitrailText {
        objectName: "missing"

        Layout.fillWidth: true
        visible: !root.hasData
        variant: "label"
        opacity: 0.7
        wrapMode: Text.WordWrap
        text: root.missing
    }
}
