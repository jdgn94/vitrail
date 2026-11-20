import Quickshell
import Quickshell.Io
import QtQuick
import QtQml.Models
import "../kit"
import "capture.js" as Capture

// The pinned areas. They belong to the shell, not to the overlay, so they
// outlive it; each is a PinWindow on the monitor its area came from. Closing a
// pin deletes its picture from the runtime folder.
Item {
    id: root

    property var t: function (key) {
        return key
    }

    // `rect` is the area in layout coordinates, `monitors` the frozen layout.
    function add(image, rect, monitors) {
        var monitor = Capture.monitorOf(rect, monitors)
        if (!monitor) {
            forget.exec(["python3", "-m", "vitrail.capture", "forget", "--after", "0", image])
            return
        }
        var start = Capture.pinStart(rect, monitor)
        pins.append({
            image: image,
            output: monitor.name,
            startX: start.x,
            startY: start.y,
            baseWidth: rect.w,
            baseHeight: rect.h,
            startZoom: start.zoom
        })
    }

    function drop(image) {
        for (var index = 0; index < pins.count; index++) {
            if (pins.get(index).image === image) {
                pins.remove(index)
                break
            }
        }
        forget.exec(["python3", "-m", "vitrail.capture", "forget", "--after", "0", image])
    }

    readonly property int count: pins.count

    ListModel {
        id: pins
    }

    Process {
        id: forget

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    Instantiator {
        model: pins

        delegate: PinWindow {
            t: root.t
            onDismissed: root.drop(image)
        }
    }
}
