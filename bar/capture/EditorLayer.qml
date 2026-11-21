pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import QtQml.Models
import "capture.js" as Capture

// The editors that are open. They belong to the shell, not to the overlay, so
// they outlive it; each is an EditorWindow on the monitor its area came from.
// Closing one deletes its pictures from the runtime folder. The shell tells the
// user what happened (`saved`, `copied`, the two failures) and keeps the
// options to remember (`remember`).
Item {
    id: root

    property var t: function (key) {
        return key
    }
    // The tool to start with, and the options to start from ("" for the defaults).
    property string tool: "pencil"
    property string options: ""

    signal saved(string path)
    signal copied(string size)
    signal saveFailed()
    signal copyFailed()
    signal remember(string options)

    // `rect` is the area in layout coordinates, `monitors` the frozen layout;
    // `width` and `height` are the picture's pixels.
    function add(image, width, height, rect, monitors) {
        var monitor = Capture.monitorOf(rect, monitors)
        edits.append({ image: image, imageWidth: width, imageHeight: height, output: monitor ? monitor.name : "" })
    }

    function drop(image) {
        for (var index = 0; index < edits.count; index++) {
            if (edits.get(index).image === image) {
                edits.remove(index)
                break
            }
        }
        // The rendered picture is `<image>-final.png`: it stays on disk after a
        // failed save.
        forget.exec(["python3", "-m", "vitrail.capture", "forget", "--after", "0", image,
                     image.replace(/\.png$/, "") + "-final.png"])
    }

    readonly property int count: edits.count

    ListModel {
        id: edits
    }

    Process {
        id: forget

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    Instantiator {
        model: edits

        delegate: EditorWindow {
            t: root.t
            startTool: root.tool
            lastOptions: root.options
            onKept: function (path) { root.saved(path) }
            onCopied: function (size) { root.copied(size) }
            onSaveFailed: root.saveFailed()
            onCopyFailed: root.copyFailed()
            onRemember: function (options) { root.remember(options) }
            onDismissed: root.drop(image)
        }
    }
}
