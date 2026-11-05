import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../dashboard/dashboard.js" as Dash

// The dashboard's performance readout: CPU, memory, temperature, disk and
// network, with an empty state while the service has not answered. The same
// component draws the desktop resources; `variant: "compact"` keeps the first
// three readings.
Item {
    id: root

    property var readings: ({})
    property var strings: ({})
    property string size: "md"
    property string variant: ""

    readonly property bool hasResources: !!(root.readings && root.readings.memory)
    readonly property bool compact: root.variant === "compact"
    // One row per reading; a missing value reads as absent, never as zero.
    readonly property var metrics: {
        var data = root.readings || ({})
        var rows = [
            { key: "cpu", icon: "speed", label: root.t("dashboard.cpu"), value: Dash.percent(data.cpu) },
            { key: "memory", icon: "memory", label: root.t("dashboard.memory"), value: Dash.usage(data.memory) },
            { key: "temperature", icon: "thermostat", label: root.t("dashboard.temperature"),
              value: Dash.temperature(data.temperature, "°C") },
            { key: "disk", icon: "storage", label: root.t("dashboard.disk"), value: Dash.usage(data.disk) },
            { key: "network", icon: "swap_vert", label: root.t("dashboard.network"), value: Dash.network(data.network) }
        ]
        return root.compact ? rows.slice(0, 3) : rows
    }
    readonly property var look: ({
        sm: { label: "label", value: "label", symbol: "sm" },
        md: { label: "label", value: "body", symbol: "sm" },
        lg: { label: "body", value: "title", symbol: "md" }
    })[root.size] || ({ label: "label", value: "body", symbol: "sm" })

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitHeight: root.hasResources ? performanceColumn.implicitHeight : performanceEmpty.implicitHeight

    ColumnLayout {
        id: performanceEmpty

        anchors.fill: parent
        spacing: VitrailTokens.gap("sm")
        visible: !root.hasResources

        VitrailIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "monitoring"
            size: "xl"
            tone: "muted"
        }

        VitrailText {
            objectName: "dashboardPerformanceEmpty"
            Layout.alignment: Qt.AlignHCenter
            variant: "content"
            text: root.t("dashboard.performance.empty")
            wrapMode: Text.WordWrap
        }
    }

    ColumnLayout {
        id: performanceColumn

        objectName: "dashboardPerformanceData"
        anchors.fill: parent
        spacing: VitrailTokens.gap("sm")
        visible: root.hasResources

        Repeater {
            model: root.metrics

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    icon: modelData.icon
                    size: root.look.symbol
                    tone: "secondary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: root.look.label
                    elide: Text.ElideRight
                    text: modelData.label
                }

                VitrailText {
                    objectName: "dashboardValue_" + modelData.key
                    variant: root.look.value
                    font.features: ({ "tnum": 1 })
                    text: modelData.value
                }
            }
        }
    }
}
