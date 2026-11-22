import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "resources.js" as Resources

// The Resources popup: five graphs drawn from the sampler's history (CPU, RAM,
// temperature, disk free, network) with the current value and its unit, and the
// busiest processes with a button to end one. Ending is two steps: "End" sends
// SIGTERM; a process that is still there offers "Force quit", which asks for a
// confirmation before it sends SIGKILL. Nothing is ever killed without a click.
// A metric that is missing gets one calm line. The gear opens the element's
// block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    // The sampler's snapshot and history (ResourcesSampler).
    property var snapshot: ({})
    property var history: Resources.emptyHistory()
    // The `resourcesUnits` preference.
    property string units: "auto"
    // The sampler's answer to the last kill: { ok } or { error: code }.
    property var killResult: ({})

    signal settingsRequested()
    // The user clicked End (force false: SIGTERM) or confirmed Force quit (true).
    signal killRequested(int pid, bool force)

    readonly property bool ready: Resources.ready(root.snapshot)
    readonly property var now: Resources.reading(root.snapshot)
    readonly property var list: Resources.processes(root.snapshot)
    // Per pid: the kill button's stage ("sent", "confirm", "done"); absent is idle.
    property var stages: ({})
    readonly property string killProblem: root.killResult && root.killResult.error
                                          ? root.t(Resources.killError(root.killResult.error)) : ""

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // Keep the delegates alive across ticks: a click that lands while the list
    // refreshes must still hit the same row.
    function syncRows() {
        var items = root.list
        while (rows.count > items.length)
            rows.remove(rows.count - 1)
        for (var i = 0; i < items.length; i++) {
            // A ListModel role keeps one type: a missing CPU share is -1.
            var item = { pid: items[i].pid, name: items[i].name,
                         cpu: items[i].cpu === null ? -1 : items[i].cpu,
                         memory: items[i].memory === null ? 0 : items[i].memory }
            if (i < rows.count)
                rows.set(i, item)
            else
                rows.append(item)
        }
        root.stages = Resources.prune(root.stages, items)
    }

    function press(pid) {
        var step = Resources.click(root.stages[String(pid)])
        var next = Object.assign({}, root.stages)
        next[String(pid)] = step.stage
        root.stages = next
        if (step.send !== "")
            root.killRequested(pid, step.send === "kill")
    }

    function abort(pid) {
        var next = Object.assign({}, root.stages)
        next[String(pid)] = Resources.cancel(root.stages[String(pid)])
        root.stages = next
    }

    onListChanged: root.syncRows()
    Component.onCompleted: root.syncRows()

    implicitWidth: VitrailTokens.size("display") * 12
    implicitHeight: body.implicitHeight

    ListModel {
        id: rows
    }

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
                text: root.t("bar.widget.resources")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.resources.unreadable")
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.ready
            spacing: VitrailTokens.gap("md")

            ResourcesGraph {
                objectName: "cpuGraph"

                Layout.fillWidth: true
                icon: "speed"
                label: root.t("bar.resources.cpu")
                valueText: Resources.percent(root.now.cpu)
                values: root.history.cpu
                missing: root.t("bar.resources.cpu.missing")
            }

            ResourcesGraph {
                objectName: "memoryGraph"

                Layout.fillWidth: true
                icon: "memory"
                label: root.t("bar.resources.memory")
                valueText: Resources.memoryUsed(root.snapshot.memory, root.units, root.t)
                values: root.history.memory
                tone: "info"
                missing: root.t("bar.resources.memory.missing")
            }

            ResourcesGraph {
                objectName: "temperatureGraph"

                Layout.fillWidth: true
                icon: "thermostat"
                label: root.t("bar.resources.temperature")
                valueText: Resources.temperature(root.now.temperature)
                values: root.history.temperature
                missing: root.t("bar.resources.temperature.missing")
            }

            ResourcesGraph {
                objectName: "diskGraph"

                Layout.fillWidth: true
                icon: "storage"
                label: root.t("bar.resources.disk")
                valueText: Resources.diskFree(root.snapshot.disk, root.units, root.t)
                values: root.history.disk
                tone: "info"
                missing: root.t("bar.resources.disk.missing")
            }

            ResourcesGraph {
                objectName: "networkGraph"

                Layout.fillWidth: true
                icon: "swap_vert"
                label: root.t("bar.resources.network")
                valueText: Resources.networkLine(root.snapshot, root.units)
                values: root.history.rx
                second: root.history.tx
                maximum: Resources.networkCeiling(root.history)
                missing: root.t("bar.resources.network.missing")
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.ready
            variant: "label"
            opacity: 0.7
            text: root.t("bar.resources.top")
        }

        VitrailText {
            objectName: "noProcesses"

            Layout.fillWidth: true
            visible: root.ready && rows.count === 0
            variant: "label"
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: root.t("bar.resources.top.empty")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: rows

                delegate: RowLayout {
                    id: row

                    required property int pid
                    required property string name
                    required property real cpu
                    required property real memory
                    readonly property string stage: root.stages[String(row.pid)] || ""

                    objectName: "processRow"

                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        objectName: "name"

                        Layout.fillWidth: true
                        variant: "label"
                        opacity: 1
                        elide: Text.ElideRight
                        text: row.name
                    }

                    VitrailText {
                        objectName: "cpu"

                        variant: "label"
                        font.features: ({ "tnum": 1 })
                        text: Resources.percent(row.cpu < 0 ? null : row.cpu)
                    }

                    VitrailText {
                        objectName: "memory"

                        variant: "label"
                        font.features: ({ "tnum": 1 })
                        text: Resources.bytes(row.memory, root.units, "memory")
                    }

                    VitrailButton {
                        objectName: "cancel"

                        visible: row.stage === "confirm"
                        variant: "plain"
                        tone: "secondary"
                        size: "sm"
                        icon: "close"
                        onClicked: root.abort(row.pid)
                    }

                    VitrailButton {
                        objectName: "kill"

                        variant: "tonal"
                        tone: row.stage === "confirm" ? "error" : "secondary"
                        size: "sm"
                        enabled: row.stage !== "done"
                        icon: row.stage === "confirm" ? "warning" : "close"
                        text: root.t(Resources.killKey(row.stage))
                        onClicked: root.press(row.pid)
                    }
                }
            }
        }

        VitrailText {
            objectName: "killError"

            Layout.fillWidth: true
            visible: root.killProblem !== ""
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.killProblem
        }
    }
}
