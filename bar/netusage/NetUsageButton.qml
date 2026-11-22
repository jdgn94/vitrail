import QtQuick
import QtQuick.Layouts
import ".."
import "../kit"
import "../kit/base"
import "netusage.js" as Net

// The network usage bar element: the down and up speeds as two short lines
// with their arrows (`netusageBar` picks both or one), from the shell's one
// resources sampler — no process and no timer of its own. A missing reading is
// "--", never a zero; an idle link really is 0 B/s, so the element is always
// active. The tooltip carries both rates and, below, the bytes since local
// midnight. A click opens the popup.
BarElementBase {
    id: root

    // The sampler's last snapshot (vitrail.resources `state --tick`).
    property var snapshot: ({})
    // The `netusageBar` preference: both, down or up.
    property string barMode: "both"
    // The `netusageUnits` preference: auto, binary or decimal.
    property string units: "auto"

    readonly property bool ready: Net.online(root.snapshot)
    readonly property var now: Net.rates(root.snapshot)
    readonly property var look: Net.face(root.barMode)
    // The day is read again on every tick, so midnight needs no timer.
    readonly property string todayText: Net.todayLine(root.snapshot, Net.dayKey(), root.units, root.t)

    active: true
    tooltip: !root.ready ? root.t("bar.widget.netusage")
             : root.t("bar.netusage.tooltip").replace("%1", Net.rate(root.now.down, root.units))
                   .replace("%2", Net.rate(root.now.up, root.units))
    tooltipDetail: !root.ready ? root.t("bar.netusage.unreadable") : root.todayText

    content: Component {
        Item {
            implicitWidth: faceColumn.implicitWidth
            implicitHeight: faceColumn.implicitHeight

            ColumnLayout {
                id: faceColumn

                anchors.centerIn: parent
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    objectName: "downText"

                    Layout.alignment: Qt.AlignHCenter
                    visible: root.look.down
                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("primary")
                    font.features: ({ "tnum": 1 })
                    text: Net.speed(root.now.down, root.units, "down")
                }

                VitrailText {
                    objectName: "upText"

                    Layout.alignment: Qt.AlignHCenter
                    visible: root.look.up
                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("info")
                    font.features: ({ "tnum": 1 })
                    text: Net.speed(root.now.up, root.units, "up")
                }
            }
        }
    }
}
