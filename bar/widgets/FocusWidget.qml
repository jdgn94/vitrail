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
    // The common widget API: sm / md / lg, and "plain" for no card behind it.
    property string size: "md"
    property string variant: ""
    // The widget's own typography; empty values keep the variant's look.
    property string fontFamily: ""
    property string fontWeight: ""
    property bool italic: false

    readonly property var metricsLook: ({
        sm: { title: "body", remaining: "subtitle", pad: "sm", button: "sm", symbol: "sm" },
        md: { title: "subtitle", remaining: "title", pad: "md", button: "md", symbol: "sm" },
        lg: { title: "title", remaining: "display", pad: "lg", button: "lg", symbol: "md" }
    })[root.size] || ({ title: "subtitle", remaining: "title", pad: "md", button: "md", symbol: "sm" })

    signal startRequested()
    signal pauseRequested()
    signal resetRequested()
    signal minutesEdited(int value)

    implicitHeight: column.implicitHeight + 2 * VitrailTokens.gap(root.metricsLook.pad)
    radius: VitrailTokens.radius
    opacityLevel: root.variant === "plain" ? 0 : VitrailTokens.opacity

    ColumnLayout {
        id: column

        x: VitrailTokens.gap(root.metricsLook.pad)
        y: VitrailTokens.gap(root.metricsLook.pad)
        width: root.width - 2 * VitrailTokens.gap(root.metricsLook.pad)
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: root.done ? "task_alt" : "timer"
                size: root.metricsLook.symbol
                tone: "primary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: root.metricsLook.title
                family: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                elide: Text.ElideRight
                text: root.title
            }

            VitrailText {
                objectName: "focusPhase_" + root.name
                variant: "label"
                family: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                text: root.phase
            }
        }

        VitrailText {
            objectName: "focusRemaining_" + root.name
            variant: root.metricsLook.remaining
            family: root.fontFamily
            fontWeight: root.fontWeight
            italic: root.italic
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
            size: root.size === "lg" ? "md" : "sm"
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
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                size: root.metricsLook.button
                icon: root.running ? "pause" : "play_arrow"
                text: root.running ? root.pauseText : root.startText
                onClicked: root.running ? root.pauseRequested() : root.startRequested()
            }

            VitrailButton {
                objectName: "focusReset_" + root.name
                variant: "text"
                fontFamily: root.fontFamily
                fontWeight: root.fontWeight
                italic: root.italic
                size: root.metricsLook.button
                tone: "secondary"
                icon: "restart_alt"
                text: root.resetText
                onClicked: root.resetRequested()
            }

            Item { Layout.fillWidth: true }
        }
    }
}
