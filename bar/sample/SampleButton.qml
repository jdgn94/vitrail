import QtQuick
import ".."

// The sample bar element, the reference for docs/bar-elements.md: a button
// whose tooltip and visibility follow a Python snapshot (vitrail/sample.py).
// Hidden by default (bar/layouts.js DEFAULT_HIDDEN); "only while active" hides
// it whenever the snapshot has nothing to say.
BarElementBase {
    id: root

    // The element's data: vitrail.sample's snapshot (BarSnapshot).
    property var snapshot: ({})
    readonly property bool ready: root.snapshot.counter !== undefined && !root.snapshot.error

    icon: "widgets"
    active: root.ready
    tooltip: root.ready ? root.t("bar.widget.sample.run").replace("%1", root.snapshot.counter)
                        : root.t("bar.widget.sample.unavailable")
    tooltipDetail: root.t("bar.widget.sample.tooltipDetail")
}
