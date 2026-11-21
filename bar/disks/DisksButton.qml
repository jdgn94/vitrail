import QtQuick
import ".."
import "disks.js" as Disks

// The disks bar element: a drive glyph that appears while a removable drive is
// plugged in, from vitrail.disks' snapshot (BarSnapshot). "Only while active"
// is the element's default mode (bar/elements.js): with nothing plugged in the
// button has no drive to name and no popup to offer, so it leaves the bar
// instead of holding an empty slot; "always" keeps the glyph in place for
// anyone who wants the slot steady.
BarElementBase {
    id: root

    // The element's data: vitrail.disks' snapshot.
    property var snapshot: ({})
    // The `disksIgnore` preference (labels and UUIDs, one JSON array).
    property string ignore: ""

    readonly property bool ready: Disks.ready(root.snapshot)
    readonly property var devices: Disks.visibleDevices(root.snapshot, root.ignore)

    icon: "storage"
    showMode: "active"
    active: root.devices.length > 0
    tooltip: !root.ready ? root.t("bar.widget.disks")
             : root.devices.length === 0 ? root.t("bar.widget.disks")
             : root.devices.length === 1 ? Disks.nameOf(root.devices[0])
                                        : root.t("bar.disks.drives").replace("%1", root.devices.length)
    tooltipDetail: !root.ready ? root.t("bar.disks.unavailable")
                   : root.devices.length === 0 ? root.t("bar.disks.empty")
                                               : Disks.usage(root.devices)
}
