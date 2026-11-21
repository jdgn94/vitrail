import QtQuick
import Quickshell
import Quickshell.Io
import "elements.js" as Elements

// One element's data from Python: `python3 -m vitrail.<module> state`, run
// every `interval` ms while `active` and parsed into `snapshot`. A snapshot is
// a JSON object; a failure is data (`snapshot.error`), never a traceback. One run at a
// time, so a slow module never piles up processes. Inactive costs nothing:
// the shell binds `active` to "this element is in a bar" (shell.barShows).
Item {
    id: root

    // The vitrail module's name: a constant of the element, never user text.
    property string module: ""
    property int interval: 60000
    property bool active: false
    property var snapshot: ({})

    implicitWidth: 0
    implicitHeight: 0

    function refresh() {
        if (root.module !== "" && !fetch.running)
            fetch.running = true
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetch

        command: ["python3", "-m", "vitrail." + root.module, "state"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.snapshot = Elements.snapshot(this.text)
        }
    }
}
