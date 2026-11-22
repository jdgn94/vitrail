import QtQuick
import QtQuick.Layouts
import ".."
import "../kit"
import "../kit/base"
import "resources.js" as Resources

// The resources bar element: CPU and RAM, as two stacked mini bars or as two
// numbers (`resourcesBar`), from the shell's one sampler (ResourcesSampler).
// The two readings keep their own colour (CPU the accent, RAM the info tone) so
// no word is needed on the bar; the tooltip names them. A reading the sampler
// has not got yet is an empty track or "--", never a zero. It is always
// active: a machine always has a CPU.
BarElementBase {
    id: root

    // The sampler's last snapshot (vitrail.resources `state --tick`).
    property var snapshot: ({})
    // The `resourcesBar` preference: both, cpu, ram or numbers.
    property string barMode: "both"
    // The `resourcesUnits` preference: auto, binary or decimal.
    property string units: "auto"

    readonly property bool ready: Resources.ready(root.snapshot)
    readonly property var now: Resources.reading(root.snapshot)
    readonly property var look: Resources.face(root.barMode)
    readonly property string cpuText: Resources.percent(root.now.cpu)
    readonly property string memoryText: Resources.percent(root.now.memory)
    // Missing metrics drop out of the lines instead of reading "--".
    readonly property string detailText: [
        root.now.disk === null ? "" : Resources.diskFree(root.snapshot.disk, root.units, root.t),
        root.snapshot && root.snapshot.rate ? Resources.networkLine(root.snapshot, root.units) : ""
    ].filter(function (part) { return part !== "" }).join(" · ")

    active: true
    tooltip: !root.ready ? root.t("bar.widget.resources")
             : root.now.temperature === null
               ? root.t("bar.resources.tooltip").replace("%1", root.cpuText).replace("%2", root.memoryText)
               : root.t("bar.resources.tooltip.temperature").replace("%1", root.cpuText)
                     .replace("%2", root.memoryText).replace("%3", Resources.temperature(root.now.temperature))
    tooltipDetail: !root.ready ? root.t("bar.resources.unreadable") : root.detailText

    content: Component {
        Item {
            implicitWidth: faceColumn.implicitWidth
            implicitHeight: faceColumn.implicitHeight

            ColumnLayout {
                id: faceColumn

                anchors.centerIn: parent
                spacing: VitrailTokens.gap("xs")

                VitrailMeter {
                    objectName: "cpuBar"

                    Layout.alignment: Qt.AlignHCenter
                    visible: root.look.bars && root.look.cpu
                    implicitWidth: VitrailTokens.size("title")
                    value: root.now.cpu === null ? -1 : root.now.cpu / 100
                    tone: "primary"
                }

                VitrailMeter {
                    objectName: "ramBar"

                    Layout.alignment: Qt.AlignHCenter
                    visible: root.look.bars && root.look.ram
                    implicitWidth: VitrailTokens.size("title")
                    value: root.now.memory === null ? -1 : root.now.memory / 100
                    tone: "info"
                }

                VitrailText {
                    objectName: "cpuNumber"

                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.look.bars && root.look.cpu
                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("primary")
                    font.features: ({ "tnum": 1 })
                    text: root.cpuText
                }

                VitrailText {
                    objectName: "ramNumber"

                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.look.bars && root.look.ram
                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("info")
                    font.features: ({ "tnum": 1 })
                    text: root.memoryText
                }
            }
        }
    }
}
