import QtQuick
import ".."
import "volume.js" as Volume

// The volume bar element: a glyph that follows the default output's level
// (muted, none, low, high), the level as text when the preference asks, the
// wheel for the master volume and a middle click for its mute. The shell runs
// the actions (`audioAction`); the snapshot is vitrail.audio's (BarSnapshot).
// "Only while active" is offered but never needed: a volume is always
// meaningful, so `active` is true and the element defaults to always shown.
BarElementBase {
    id: root

    property var snapshot: ({})
    // Preferences: the percent one wheel notch moves, and the level as text.
    property int step: 5
    property bool showPercent: false

    // Arguments for `python3 -m vitrail.audio`; the shell spawns the process.
    signal audioAction(var args)

    readonly property bool ready: Volume.ready(root.snapshot)
    readonly property bool muted: Volume.muted(root.snapshot)
    readonly property int level: Volume.level(root.snapshot)

    active: true
    icon: Volume.icon(root.snapshot)
    tone: root.ready && root.muted ? "error" : "secondary"
    text: root.ready && root.showPercent && !root.muted ? root.level + "%" : ""
    tooltip: root.ready ? root.snapshot.defaultSink.description : root.t("bar.volume.unavailable")
    tooltipDetail: !root.ready ? root.t("bar.volume.unavailableDetail")
                   : root.muted ? root.t("bar.volume.mutedAt").replace("%1", root.level)
                                : root.t("bar.volume.level").replace("%1", root.level)

    onWheeled: function (delta) {
        var change = Volume.wheelChange(delta, root.step)
        if (root.ready && change !== 0)
            root.audioAction(Volume.stepArgs("sink", change))
    }

    onMiddleClicked: {
        if (root.ready)
            root.audioAction(Volume.muteArgs("sink"))
    }
}
