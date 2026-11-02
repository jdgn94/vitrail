import QtQuick
import Qt.labs.settings 1.1
import "../../kit"

// Hands one password to vitrail.network without putting it in a preference, a
// request, an argument or a log: `write` stores it as `password` in
// `<folder>/vitrail-secret-<nonce>.ini` (folder: $XDG_RUNTIME_DIR, a private
// tmpfs), calls `done` once it has reached the disk and forgets it. The
// request that follows names only the nonce; the helper reads the file, gives
// the tool its own private copy and deletes both (vitrail/network.py).
Item {
    id: root

    property string folder: ""
    property string nonce: ""
    property string password: ""
    property var done: null

    function write(folder, nonce, password, done) {
        root.folder = folder
        root.nonce = nonce
        root.password = password
        root.done = done
        holder.active = true
        settle.restart()
    }

    Loader {
        id: holder

        active: false

        sourceComponent: Component {
            Settings {
                fileName: root.folder + "/vitrail-secret-" + root.nonce + ".ini"
                category: "secret"

                property string password: root.password
            }
        }
    }

    Timer {
        id: settle

        interval: VitrailTokens.duration("settle")
        onTriggered: {
            holder.active = false
            root.password = ""
            var next = root.done
            root.done = null
            root.nonce = ""
            if (next)
                next()
        }
    }
}
