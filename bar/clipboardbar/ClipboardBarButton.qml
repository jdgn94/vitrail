import QtQuick
import ".."
import "clipboardbar.js" as ClipboardBar

// The clipboard bar element: the number of copies the history holds and the
// newest one's first line (redacted, never a secret), with the oldest shown as
// the second line. The popup draws the newest five with the rich preview; this
// button reads the same history the clipboard panel does.
BarElementBase {
    id: root

    // The history, newest first, as vitrail.clipboard's store gives it.
    property var entries: []
    // How many the popup shows (`clipboardbarRecent`, 1–10).
    property int limit: ClipboardBar.DEFAULT

    readonly property int count: ClipboardBar.count(root.entries)
    readonly property string newest: ClipboardBar.newest(root.entries)
    readonly property string oldest: ClipboardBar.oldest(root.entries, root.limit)

    icon: "content_paste"
    active: root.count > 0
    tooltip: root.count === 0 ? root.t("bar.clipboardbar.none")
             : root.count === 1 ? root.t("bar.clipboardbar.tooltip.one").replace("%1", root.newest)
                                : root.t("bar.clipboardbar.tooltip")
                                    .replace("%1", root.count).replace("%2", root.newest)
    tooltipDetail: root.count === 0 ? root.t("bar.clipboardbar.empty")
                   : root.count === 1 ? root.newest
                                      : root.oldest
}
