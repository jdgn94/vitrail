import QtQuick
import Quickshell.Io
import "../kit"

// One external program at a time, latest request wins: while a run is going
// the newest `run()` waits and replaces any older waiting one. `finished`
// carries the tag the run was started with, so the caller can tell a stale
// answer. A program that never answers is given up after `motion.timeout`.
Item {
    id: root

    // A run is waiting or going.
    readonly property bool busy: root.waiting !== null || !root.settled

    signal finished(string tag, string output)

    property var waiting: null
    property bool settled: true
    property string tag: ""
    property string output: ""
    property bool streamed: true

    function run(command, tag) {
        root.waiting = { command: command, tag: tag }
        root.next()
    }

    function next() {
        if (!root.settled || root.waiting === null)
            return
        var job = root.waiting
        root.waiting = null
        root.settled = false
        root.streamed = false
        root.output = ""
        root.tag = job.tag
        patience.restart()
        proc.exec(job.command)
    }

    function settle() {
        if (root.settled || proc.running || !root.streamed)
            return
        patience.stop()
        root.settled = true
        root.finished(root.tag, root.output)
        root.next()
    }

    Timer {
        id: patience

        interval: VitrailTokens.duration("timeout")
        onTriggered: {
            proc.running = false
            root.streamed = true
            root.settled = false
            root.settle()
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                root.output = this.text
                root.streamed = true
                root.settle()
            }
        }
        onRunningChanged: root.settle()
    }
}
