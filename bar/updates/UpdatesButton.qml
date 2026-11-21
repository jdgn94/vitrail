import QtQuick
import ".."
import "updates.js" as Updates

// The updates bar element: the number of pending packages, from
// vitrail.updates' snapshot (BarSnapshot), and nothing at all when there are
// none. "Only while active" is the element's default mode (bar/elements.js):
// a count that is always zero is not something to say, so the button leaves
// the bar until the first update arrives; "always" keeps the ordinary glyph
// in place for anyone who wants the slot steady.
BarElementBase {
    id: root

    // The element's data: vitrail.updates' snapshot.
    property var snapshot: ({})

    readonly property bool ready: Updates.ready(root.snapshot)
    readonly property int count: Updates.total(root.snapshot)
    readonly property string failure: root.firstError()

    // The sources with something pending, as "Official repositories 3 · AUR 2".
    function sourceDetail() {
        var list = Updates.counts(root.snapshot)
        var parts = []
        for (var i = 0; i < list.length; i++)
            parts.push(root.t("bar.updates.source." + list[i].source) + " " + list[i].count)
        return parts.join(" · ")
    }

    // The first source that could not answer. The popup lists every one of
    // them; the tooltip has room for one line.
    function firstError() {
        var sources = Updates.sourcesOf(root.snapshot)
        for (var i = 0; i < sources.length; i++) {
            var message = Updates.errorOf(root.snapshot, sources[i])
            if (message !== "")
                return message
        }
        return ""
    }

    icon: "update"
    text: root.count > 0 ? String(root.count) : ""
    active: root.count > 0
    tooltip: !root.ready ? root.t("bar.widget.updates")
             : root.count === 0 ? root.t("bar.updates.none")
             : root.count === 1 ? root.t("bar.updates.tooltip.one").replace("%1", root.count)
                                : root.t("bar.updates.tooltip").replace("%1", root.count)
    tooltipDetail: !root.ready ? root.t("bar.updates.unavailable")
                   : root.count > 0 ? root.sourceDetail()
                   : root.failure !== "" ? root.failure
                   : root.snapshot.checkedAt !== undefined
                       ? root.t("bar.updates.checked").replace("%1",
                           Qt.formatTime(new Date(root.snapshot.checkedAt), "HH:mm"))
                       : root.t("bar.updates.none")
}
