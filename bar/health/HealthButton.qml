import QtQuick
import ".."
import "health.js" as Health

// The system health bar element: a warning glyph, tinted by the worst severity,
// with the number of problems when there is more than one, from vitrail.health's
// snapshot (BarSnapshot) plus the bar's own load failures. "Only while active"
// is its default mode (bar/elements.js): a machine with nothing wrong has
// nothing to say, so the button leaves the bar until a check fails; "always"
// keeps the calm glyph in place for anyone who wants the slot steady.
BarElementBase {
    id: root

    // The element's data: vitrail.health's snapshot.
    property var snapshot: ({})
    // The ids of the bar elements that failed to load (the shell's own signal).
    property var failed: []

    readonly property var problems: Health.problems(root.snapshot, root.failed)
    readonly property int count: root.problems.length
    readonly property string severity: Health.worst(root.problems)
    readonly property bool ready: Health.ready(root.snapshot) || root.count > 0

    icon: Health.icon(root.count)
    text: Health.countText(root.count)
    tone: Health.tone(root.severity)
    showMode: "active"
    active: Health.active(root.count)
    tooltip: !root.ready ? root.t("bar.widget.health")
             : root.count === 0 ? root.t("bar.health.fine")
             : Health.title(root.problems[0], root.t)
    tooltipDetail: !root.ready ? root.t("bar.health.unreadable")
                   : root.count === 0 ? root.t("bar.health.fine.detail")
                   : root.count === 1 ? Health.detail(root.problems[0], root.t)
                                      : Health.more(root.count, root.t)
}
