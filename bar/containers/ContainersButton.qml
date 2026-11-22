import QtQuick
import ".."
import "containers.js" as Containers

// The containers bar element: how many containers are running, from
// vitrail.containers' snapshot (BarSnapshot). "Only while active" is the
// element's default mode (bar/elements.js) and its `active` is "an engine is
// installed", so a machine with neither docker nor podman draws nothing at
// all. The tooltip names the engine and the count; the pinned containers that
// are down get the second line.
BarElementBase {
    id: root

    // The element's data: vitrail.containers' snapshot.
    property var snapshot: ({})
    // The `containersPinned` preference (one JSON array of names).
    property string pinned: ""

    readonly property bool ready: Containers.ready(root.snapshot)
    readonly property string engine: Containers.engineOf(root.snapshot)
    readonly property int count: Containers.count(root.snapshot)
    readonly property var down: Containers.downPinned(root.snapshot, root.pinned)

    icon: "deployed_code"
    text: root.ready && root.engine !== "" ? String(root.count) : ""
    active: root.engine !== ""
    tooltip: !root.ready ? root.t("bar.widget.containers")
             : root.engine === "" ? root.t("bar.widget.containers")
             : root.count === 1 ? root.t("bar.containers.tooltip.one")
                                  .replace("%1", root.engine).replace("%2", root.count)
             : root.t("bar.containers.tooltip")
                   .replace("%1", root.engine).replace("%2", root.count)
    tooltipDetail: !root.ready ? root.t("bar.containers.unavailable")
                   : root.engine === "" ? root.t("bar.containers.noEngine")
                   : root.down.length > 0 ? root.t("bar.containers.down").replace("%1", root.down.join(", "))
                                          : ""
}
