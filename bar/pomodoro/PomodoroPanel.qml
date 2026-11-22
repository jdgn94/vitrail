import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../widgets"
import "pomodoro.js" as Pomodoro

// The pomodoro element's popup: the same TimerEngine the dashboard's focus tab
// draws (one engine, one truth), its work/break lengths and rounds, the four
// actions through DashboardFocus, and the quick timers the plan asks for. The
// gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    // The shell's TimerEngine (bar/dashboard/TimerEngine.qml).
    property var engine: null

    signal settingsRequested()

    readonly property var face: root.engine
                                 ? Pomodoro.face(root.engine.pomodoro, root.engine.timer, root.engine.now)
                                 : null
    // Just the free timer, for the row under the quick timers.
    readonly property var quickFace: root.engine && root.engine.timer
                                       ? Pomodoro.face(null, root.engine.timer, root.engine.now)
                                       : null
    readonly property bool quickActive: root.quickFace !== null && root.quickFace.active

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function startQuick(minutes) {
        if (root.engine)
            root.engine.startTimer(minutes)
    }

    implicitWidth: 360
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.pomodoro")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        DashboardFocus {
            objectName: "pomodoroFocus"

            Layout.fillWidth: true
            engine: root.engine
            kind: "pomodoro"
            strings: root.strings
            now: root.engine ? root.engine.now : 0
            size: "md"
            variant: "plain"
        }

        VitrailText {
            objectName: "pomodoroLengths"

            Layout.fillWidth: true
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.engine
                  ? root.t("bar.pomodoro.lengths").replace("%1", root.engine.workMinutes)
                        .replace("%2", root.engine.restMinutes).replace("%3", root.engine.cycles)
                  : ""
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.quickActive
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                objectName: "pomodoroQuickRemaining"

                Layout.fillWidth: true
                variant: "body"
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
                text: root.quickFace ? Pomodoro.tooltipText(root.quickFace, root.strings) : ""
            }

            VitrailButton {
                objectName: "pomodoroQuickToggle"

                variant: "tonal"
                size: "sm"
                icon: root.engine && root.engine.timer.running ? "pause" : "play_arrow"
                text: root.engine && root.engine.timer.running
                      ? root.t("dashboard.focus.pause") : root.t("dashboard.focus.start")
                onClicked: if (root.engine) root.engine.toggleTimer()
            }

            VitrailButton {
                objectName: "pomodoroQuickReset"

                variant: "text"
                tone: "secondary"
                size: "sm"
                icon: "restart_alt"
                text: root.t("dashboard.focus.reset")
                onClicked: if (root.engine) root.engine.resetTimer()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            text: root.t("bar.pomodoro.quick")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            Repeater {
                model: Pomodoro.QUICK

                delegate: VitrailButton {
                    required property int modelData

                    objectName: "pomodoroQuick" + modelData

                    variant: "tonal"
                    size: "sm"
                    icon: "timer"
                    text: root.t("bar.pomodoro.minutes").replace("%1", modelData)
                    onClicked: root.startQuick(modelData)
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
