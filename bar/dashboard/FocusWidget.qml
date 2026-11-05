import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// One clock widget in the dashboard: the phase, the time left, its progress,
// and the three actions. The pomodoro and the timer only differ in what they
// say and whether a free length can be typed, so they share this card.
VitrailSurface {
    id: root

    // The name the tests and the caller use ("pomodoro", "timer").
    property string name: ""
    property string title: ""
    property string phase: ""
    property string remaining: "00:00"
    property real progress: 0
    property bool running: false
    property bool done: false
    property string startText: ""
    property string pauseText: ""
    property string resetText: ""
    // The timer's free length: shown while it is not running.
    property bool editableMinutes: false
    property int minutes: 0
    property string minutesLabel: ""

    signal startRequested()
    signal pauseRequested()
    signal resetRequested()
    signal minutesEdited(int value)

    implicitHeight: column.implicitHeight + 2 * VitrailTokens.gap("md")
    radius: VitrailTokens.radius

    ColumnLayout {
        id: column

        x: VitrailTokens.gap("md")
        y: VitrailTokens.gap("md")
        width: root.width - 2 * VitrailTokens.gap("md")
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: root.done ? "task_alt" : "timer"
                size: "sm"
                tone: "primary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.title
            }

            VitrailText {
                objectName: "focusPhase_" + root.name
                variant: "label"
                text: root.phase
            }
        }

        VitrailText {
            objectName: "focusRemaining_" + root.name
            variant: "title"
            font.features: ({ "tnum": 1 })
            text: root.remaining
        }

        VitrailSlider {
            objectName: "focusProgress_" + root.name
            Layout.fillWidth: true
            readOnly: true
            continuous: true
            size: "thin"
            from: 0
            to: 1
            stepSize: 0
            value: root.progress
        }

        VitrailField {
            id: minutesField

            objectName: "focusMinutes_" + root.name
            Layout.fillWidth: true
            visible: root.editableMinutes && !root.running
            size: "sm"
            label: root.minutesLabel
            text: String(root.minutes)
            onTextChanged: {
                var value = parseInt(minutesField.text, 10)
                if (!isNaN(value) && value !== root.minutes)
                    root.minutesEdited(value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailButton {
                objectName: "focusToggle_" + root.name
                variant: root.running ? "tonal" : "flat"
                icon: root.running ? "pause" : "play_arrow"
                text: root.running ? root.pauseText : root.startText
                onClicked: root.running ? root.pauseRequested() : root.startRequested()
            }

            VitrailButton {
                objectName: "focusReset_" + root.name
                variant: "text"
                tone: "secondary"
                icon: "restart_alt"
                text: root.resetText
                onClicked: root.resetRequested()
            }

            Item { Layout.fillWidth: true }
        }
    }
}
