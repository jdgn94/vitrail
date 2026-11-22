import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "brightness.js" as Brightness

// The brightness element's popup: one row per monitor Hyprland reports (a
// readable one with its slider and percentage, an unreadable one with the
// reason instead of a dead slider), then the night light's switch, colour
// temperature, schedule and the next change the module computed
// (`vitrail.nightlight`'s `state.next`). Every change leaves as a signal; the
// shell writes the preference or runs the process. The gear opens the
// element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    // `vitrail brightness list`: { status, devices: [{ name, kind, percent… }] }.
    property var snapshot: ({})
    // `vitrail.nightlight state`: enabled, temperature, schedule, next, error.
    property var nightlight: ({})
    // Every monitor Hyprland reports, in its order.
    property var screens: []
    // nightLightSchedule, already parsed.
    property var schedule: Brightness.scheduleOf("")
    // nightLightTemperature, in kelvin.
    property real temperature: Brightness.TEMPERATURE_DEFAULT
    property bool nightLightOn: false
    // The percent one wheel notch moves a monitor's slider (brightnessStep).
    property real step: 5

    signal settingsRequested()
    signal brightnessRequested(string name, real percent)
    signal nightLightToggled(bool on)
    signal temperatureRequested(real kelvin)
    signal scheduleRequested(string text)

    readonly property bool ready: Brightness.ready(root.snapshot)
    readonly property var rows: Brightness.rows(root.snapshot, root.screens)
    // Stable names for the Repeater, so a new snapshot does not rebuild a
    // slider under the pointer.
    readonly property var monitorNames: {
        if (root.screens && root.screens.length > 0)
            return root.screens
        return Brightness.rows(root.snapshot, []).map(function (row) { return row.name })
    }
    readonly property string nextText: Brightness.nextText(
        root.nightlight ? root.nightlight.next : null, root.strings)
    readonly property string sunText: Brightness.sunText(
        root.nightlight ? root.nightlight.schedule : root.schedule, root.strings)
    readonly property string mode: root.schedule ? root.schedule.mode : "off"
    readonly property string error: root.nightlight ? String(root.nightlight.error || "") : ""

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function chooseMode(key) {
        root.scheduleRequested(Brightness.withMode(root.schedule, key))
    }

    function changeTime(which, value) {
        var text = Brightness.withTime(root.schedule, which, value)
        if (text !== JSON.stringify(Brightness.scheduleOf(root.schedule)))
            root.scheduleRequested(text)
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
                text: root.t("bar.widget.brightness")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready && root.rows.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.brightness.unreadable")
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.rows.length > 0
            variant: "label"
            text: root.t("bar.brightness.monitors")
        }

        Repeater {
            model: root.monitorNames

            delegate: ColumnLayout {
                id: monitor

                required property string modelData

                readonly property var row: Brightness.rowFor(root.snapshot, monitor.modelData)

                objectName: "monitor"

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    objectName: "monitorName"

                    Layout.fillWidth: true
                    variant: "body"
                    elide: Text.ElideRight
                    text: monitor.row.name
                }

                VitrailSlider {
                    objectName: "brightnessSlider"

                    Layout.fillWidth: true
                    visible: monitor.row.readable
                    size: "sm"
                    from: 0
                    to: 100
                    stepSize: 1
                    wheelStep: root.step
                    value: monitor.row.readable ? monitor.row.percent : 0
                    onMoved: function (value) { root.brightnessRequested(monitor.row.name, value) }
                }

                VitrailText {
                    objectName: "monitorReason"

                    Layout.fillWidth: true
                    visible: !monitor.row.readable
                    variant: "label"
                    wrapMode: Text.WordWrap
                    text: monitor.row.readable ? "" : root.t(monitor.row.reason)
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "subtitle"
            text: root.t("bar.brightness.nightLight")
        }

        VitrailSettingRow {
            Layout.fillWidth: true
            label: root.t("bar.brightness.nightLight")
            description: root.t("bar.brightness.nightLight.help")

            VitrailSwitch {
                objectName: "nightLightSwitch"

                checked: root.nightLightOn
                onToggled: function (value) { root.nightLightToggled(value) }
            }
        }

        VitrailSlider {
            objectName: "nightLightTemperature"

            Layout.fillWidth: true
            label: root.t("bar.brightness.temperature")
            suffix: " K"
            from: Brightness.TEMPERATURE_MIN
            to: Brightness.TEMPERATURE_MAX
            stepSize: Brightness.TEMPERATURE_STEP
            value: root.temperature
            onMoved: function (value) { root.temperatureRequested(value) }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.t("bar.brightness.temperature.help")
        }

        VitrailSelect {
            objectName: "nightLightSchedule"

            Layout.fillWidth: true
            label: root.t("bar.brightness.schedule")
            options: [
                { key: "off", label: root.t("bar.brightness.schedule.off") },
                { key: "fixed", label: root.t("bar.brightness.schedule.fixed") },
                { key: "sun", label: root.t("bar.brightness.schedule.sun") }
            ]
            current: root.mode
            onSelected: function (key) { root.chooseMode(key) }
        }

        RowLayout {
            objectName: "fixedHours"

            Layout.fillWidth: true
            visible: root.mode === "fixed" || root.mode === "sun"
            spacing: VitrailTokens.gap("sm")

            VitrailField {
                id: startField

                Layout.fillWidth: true
                label: root.t("bar.brightness.start")
                text: root.schedule ? root.schedule.start : ""
                error: Brightness.clock(startField.text) === null
                errorText: root.t("bar.brightness.timeInvalid")
                onAccepted: root.changeTime("start", startField.text)
            }

            VitrailField {
                id: endField

                Layout.fillWidth: true
                label: root.t("bar.brightness.end")
                text: root.schedule ? root.schedule.end : ""
                error: Brightness.clock(endField.text) === null
                errorText: root.t("bar.brightness.timeInvalid")
                onAccepted: root.changeTime("end", endField.text)
            }
        }

        VitrailText {
            objectName: "sunTimes"

            Layout.fillWidth: true
            visible: root.mode === "sun"
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.sunText !== "" ? root.sunText : root.t("bar.brightness.sunUnavailable")
        }

        VitrailText {
            objectName: "nextChange"

            Layout.fillWidth: true
            visible: root.nextText !== ""
            variant: "label"
            text: root.nextText
        }

        VitrailText {
            objectName: "nightLightError"

            Layout.fillWidth: true
            visible: root.error !== ""
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.error
        }
    }
}
