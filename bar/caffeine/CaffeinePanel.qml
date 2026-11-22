import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "caffeine.js" as Caffeine

// The caffeine popup: the switch, the four durations and what the inhibitor
// reports. The duration is only remembered (`caffeineMinutes`); the inhibitor
// itself is Quickshell's, enabled in bar/shell.qml and gone when it is off.
// The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property bool caffeineOn: false
    property double until: 0
    property bool inhibiting: false
    property int defaultMinutes: Caffeine.DEFAULT_MINUTES
    property double now: Date.now()

    signal settingsRequested()
    signal toggleRequested()
    signal durationRequested(int minutes)

    readonly property var state: Caffeine.state(root.caffeineOn, root.until, root.now)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 380
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
                text: root.t("bar.widget.caffeine")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                objectName: "caffeineState"

                Layout.fillWidth: true
                variant: "body"
                wrapMode: Text.WordWrap
                text: Caffeine.summary(root.caffeineOn, root.until, root.now, root.t)
            }

            VitrailSwitch {
                objectName: "caffeineSwitch"

                checked: root.state.on
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                onToggled: root.toggleRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            text: root.t("bar.caffeine.duration")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: Caffeine.DURATIONS

                delegate: VitrailButton {
                    required property int modelData

                    objectName: "duration-" + modelData

                    Layout.fillWidth: true
                    variant: root.defaultMinutes === modelData ? "tonal" : "plain"
                    tone: "secondary"
                    size: "sm"
                    text: Caffeine.durationLabel(modelData, root.t)
                    onClicked: root.durationRequested(modelData)
                }
            }
        }

        VitrailText {
            objectName: "inhibitorState"

            Layout.fillWidth: true
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.t("bar.caffeine.state") + ": " + Caffeine.detail(root.inhibiting, root.t)
        }
    }
}
