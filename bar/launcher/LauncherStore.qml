import QtQuick
import Quickshell
import Quickshell.Io
import "../kit"
import "history.js" as History

// What the launcher remembers (launches, favourites, hidden apps), in
// ~/.local/state/vitrail/launcher.json. One per shell; every monitor's
// launcher reads `state` and calls the functions. Writes wait for a pause and
// are atomic (FileView writes a temporary file and renames it).
Item {
    id: root

    // launcher.ini asks for a clear with a timestamp (see history.js).
    property string clearRequest: ""

    readonly property string folder: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/vitrail"
    readonly property string path: root.folder + "/launcher.json"
    property var state: History.empty()
    property bool loaded: false

    function change(next) {
        if (next === root.state)
            return
        root.state = next
        saver.restart()
    }

    function record(id) {
        root.change(History.record(root.state, id, Date.now()))
    }

    function togglePin(id) {
        root.change(History.togglePin(root.state, id))
    }

    function hide(id) {
        root.change(History.hide(root.state, id))
    }

    onClearRequestChanged: if (root.loaded) root.change(History.applyRequest(root.state, root.clearRequest))

    // The folder must exist before the first write.
    Process {
        command: ["mkdir", "-p", root.folder]
        running: true
    }

    Timer {
        id: saver

        interval: VitrailTokens.duration("typeahead")
        onTriggered: file.setText(History.serialize(root.state))
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        atomicWrites: true
        onLoaded: {
            var stored = History.parse(this.text())
            root.state = stored
            root.loaded = true
            root.change(History.applyRequest(stored, root.clearRequest))
        }
        onLoadFailed: root.loaded = true
    }
}
