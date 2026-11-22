import QtQuick
import ".."
import "../kit"
import "../kit/base"
import "pomodoro.js" as Pomodoro

// The pomodoro / timer bar element: the shell's one TimerEngine (the same one
// the dashboard's focus tab uses), so the bar and the dashboard never keep two
// countdowns. While a session runs or is paused it writes mm:ss beside a small
// progress ring; a fresh or finished session has no time to show and the
// element leaves the bar in its default "only while active" mode.
BarElementBase {
    id: root

    // The shell's TimerEngine (bar/dashboard/TimerEngine.qml).
    property var engine: null

    readonly property var face: Pomodoro.face(root.engine ? root.engine.pomodoro : null,
                                             root.engine ? root.engine.timer : null,
                                             root.engine ? root.engine.now : 0)

    icon: "timer"
    text: root.face.active ? root.face.text : ""
    active: root.face.active
    tooltip: Pomodoro.tooltipText(root.face, root.strings)
    tooltipDetail: root.face.active ? Pomodoro.detailText(root.face, root.strings)
                                    : root.t("bar.pomodoro.ready")

    content: root.face.active ? progressFace : null

    // A ring with the countdown beside it, when the bar has the room; the
    // button underneath keeps the icon-only face otherwise.
    Component {
        id: progressFace

        Row {
            spacing: VitrailTokens.gap("xs")

            VitrailRing {
                implicitWidth: VitrailTokens.size("title")
                implicitHeight: VitrailTokens.size("title")
                value: root.face.progress
            }

            VitrailText {
                variant: "label"
                font.features: ({ "tnum": 1 })
                text: root.face.text
            }
        }
    }
}
