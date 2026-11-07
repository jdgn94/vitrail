import Quickshell
import QtQuick
import "bar/launcher"

// Loaded by tests/qml_smoke.sh inside a real (offscreen) Quickshell process.
// It builds the launcher and exits 0 only when the object exists; a QML error
// in the launcher or in anything it imports makes createObject() return null,
// so the smoke fails instead of testing the JavaScript modules alone.
ShellRoot {
    Item {
        id: host

        width: 1920
        height: 1080

        Component {
            id: launcher

            Launcher {
                width: host.width
                height: host.height
            }
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            var item = launcher.createObject(host)
            if (!item) {
                console.error("launcher smoke: the launcher did not load")
                Qt.exit(1)
            } else {
                console.log("launcher smoke: loaded")
                Qt.exit(0)
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            console.error("launcher smoke: timed out")
            Qt.exit(1)
        }
    }
}
