import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../resources/resources.js" as Resources
import "netusage.js" as Net

// The Network usage popup: the down and up rates as one graph, shared from the
// resources sampler's history and axis (down in the accent, up in the info
// tone), the two speeds now, and the bytes received and sent since local
// midnight in the units the option chooses. A sampler with no counters yet is
// one calm line instead of an empty graph. The gear opens the element's block
// in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    // The sampler's snapshot and history (ResourcesSampler).
    property var snapshot: ({})
    property var history: Resources.emptyHistory()
    // The `netusageUnits` preference.
    property string units: "auto"

    signal settingsRequested()

    readonly property bool online: Net.online(root.snapshot)
    readonly property var now: Net.rates(root.snapshot)
    // Read again on every snapshot, so a tick after midnight starts the day at
    // zero without a timer of its own.
    readonly property var used: Net.todayText(root.snapshot, Net.dayKey(), root.units)
    readonly property real ceiling: Resources.networkCeiling(root.history)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: VitrailTokens.size("display") * 12
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.netusage")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.online
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.netusage.none")
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.online
            spacing: VitrailTokens.gap("md")

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    text: root.t("bar.netusage.now")
                }

                VitrailText {
                    objectName: "downRate"

                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("primary")
                    font.features: ({ "tnum": 1 })
                    text: Net.speed(root.now.down, root.units, "down")
                }

                VitrailText {
                    objectName: "upRate"

                    variant: "label"
                    opacity: 1
                    color: VitrailTokens.color("info")
                    font.features: ({ "tnum": 1 })
                    text: Net.speed(root.now.up, root.units, "up")
                }
            }

            VitrailSparkline {
                objectName: "downGraph"

                Layout.fillWidth: true
                values: root.history.rx
                maximum: root.ceiling
                capacity: Resources.CAPACITY
                tone: "primary"

                VitrailSparkline {
                    objectName: "upGraph"

                    anchors.fill: parent
                    values: root.history.tx
                    maximum: root.ceiling
                    capacity: Resources.CAPACITY
                    tone: "info"
                    showGrid: false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    icon: "arrow_downward"
                    size: "sm"
                    container: false
                    tone: "primary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.t("bar.netusage.today.rx")
                }

                VitrailText {
                    objectName: "todayRx"

                    variant: "label"
                    opacity: 1
                    font.features: ({ "tnum": 1 })
                    text: root.used.rx
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    icon: "arrow_upward"
                    size: "sm"
                    container: false
                    tone: "info"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.t("bar.netusage.today.tx")
                }

                VitrailText {
                    objectName: "todayTx"

                    variant: "label"
                    opacity: 1
                    font.features: ({ "tnum": 1 })
                    text: root.used.tx
                }
            }
        }
    }
}
