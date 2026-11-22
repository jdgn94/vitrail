import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../elements.js" as Elements
import "resources.js" as Resources

// The shell's one resources sampler. Every consumer (the Resources element's
// button and popup, and the network element that comes after it) reads this
// object; none of them runs a process or a timer of its own.
//
// - One `python3 -m vitrail.resources state --tick` per tick, through
//   BarSnapshot: one process at a time, none while `active` is false (the shell
//   binds it to "any resources or network element is in a bar").
// - What the next tick needs (CPU ticks, network counters, each process's
//   ticks) is kept by the Python side between runs; QML only receives numbers.
// - `history` is the one ring buffer (Resources.CAPACITY readings) of CPU,
//   memory, temperature, disk free and the network rates. A graph reads its
//   series from it; nobody keeps a copy.
// - `withTop` adds the busiest processes to the snapshot; the shell turns it on
//   only while the Resources popup is open.
//
// The API a consumer uses: `snapshot`, `history`, `refresh()`, `kill(pid, force)`
// and `killResult`. See docs/bar-elements.md for the shape of the snapshot.
Item {
    id: root

    // Seconds between two readings (the `resourcesInterval` preference).
    property int interval: Resources.INTERVAL_DEFAULT
    // Whether anything shows the readings. False costs nothing.
    property bool active: false
    // Whether the popup wants the top processes.
    property bool withTop: false

    // The last reading: cpu, memory, temperature, disk, network, rate, at, top.
    readonly property var snapshot: reader.snapshot
    // The ring: { cpu, memory, temperature, disk, rx, tx }, oldest first; a
    // missing reading is null.
    property var history: Resources.emptyHistory()
    // The answer of the last kill: { ok: true } or { error: code }.
    property var killResult: ({})

    implicitWidth: 0
    implicitHeight: 0

    function refresh() {
        reader.refresh()
    }

    // Send SIGTERM (or SIGKILL when `force`) to one process. The Python side
    // refuses pid 1 and the shell itself. Nothing calls this without a click.
    function kill(pid, force) {
        if (killer.running)
            return
        killer.pid = Number(pid)
        killer.force = !!force
        killer.running = true
    }

    BarSnapshot {
        id: reader

        module: "resources"
        interval: Resources.intervalMs(root.interval)
        active: root.active
        arguments: root.withTop ? ["--tick", "--top"] : ["--tick"]
    }

    Connections {
        target: reader

        function onSnapshotChanged() {
            root.history = Resources.push(root.history, reader.snapshot, Resources.CAPACITY)
        }
    }

    Process {
        id: killer

        property int pid: 0
        property bool force: false

        command: ["python3", "-m", "vitrail.resources", "kill", String(killer.pid)]
                 .concat(killer.force ? ["--force"] : [])
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: {
                var result = Elements.snapshot(this.text)
                result.pid = killer.pid
                root.killResult = result
                root.refresh()
            }
        }
    }
}
