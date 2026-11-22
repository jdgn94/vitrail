import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/updates/updates.js" as Updates
import "../../bar/disks/disks.js" as Disks
import "../../bar/brightness/brightness.js" as Brightness

// Bar elements category: one block per new-style bar element, each with the
// options every element shares (when it shows) and its own. A bar popup's gear
// lands on its element's block through `tab` (the element's id). A new
// element adds its BarElementSection here (docs/bar-elements.md).
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The element whose block to bring into view (a gear or a search result).
    property string tab: ""

    function reveal() {
        for (var i = 0; i < column.children.length; i++) {
            var block = column.children[i]
            if (block.elementId !== undefined && block.elementId === page.tab) {
                scroller.contentY = Math.min(block.y, Math.max(0, scroller.contentHeight - scroller.height))
                return
            }
        }
    }

    onTabChanged: Qt.callLater(page.reveal)

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            BarElementSection {
                Layout.fillWidth: true
                elementId: "sample"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings
            }

            BarElementSection {
                id: volumeSection

                Layout.fillWidth: true
                elementId: "volume"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "volumeStep"

                    Layout.fillWidth: true
                    label: volumeSection.t("bar.volume.step")
                    suffix: "%"
                    from: VitrailTokens.ranges.volumeStep.min
                    to: VitrailTokens.ranges.volumeStep.max
                    stepSize: VitrailTokens.ranges.volumeStep.step
                    value: page.prefs.volumeStep
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.volumeStep = value
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "text_fields"
                    label: volumeSection.t("bar.volume.percent")
                    description: volumeSection.t("bar.volume.percent.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "volumePercent"
                        checked: page.prefs.volumePercent === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.volumePercent = value }
                    }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "visibility_off"
                    label: volumeSection.t("bar.volume.hideSilent")
                    description: volumeSection.t("bar.volume.hideSilent.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "volumeHideSilent"
                        checked: page.prefs.volumeHideSilent === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.volumeHideSilent = value }
                    }
                }
            }

            BarElementSection {
                id: updatesSection

                Layout.fillWidth: true
                elementId: "updates"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "updatesInterval"

                    Layout.fillWidth: true
                    label: updatesSection.t("bar.updates.interval")
                    options: {
                        var minutes = [15, 30, 60, 120, 360, 720]
                        var now = Updates.intervalMinutes(page.prefs.updatesInterval)
                        if (minutes.indexOf(now) < 0)
                            minutes.push(now)
                        minutes.sort(function (a, b) { return a - b })
                        return minutes.map(function (value) {
                            return { key: String(value),
                                     label: updatesSection.t("bar.updates.intervalOption").replace("%1", value) }
                        })
                    }
                    current: String(Updates.intervalMinutes(page.prefs.updatesInterval))
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.updatesInterval = Number(key) }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    label: updatesSection.t("bar.updates.source.official")
                    description: updatesSection.t("bar.updates.source.official.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "updatesOfficial"
                        checked: Updates.enabledSources(page.prefs.updatesSources).indexOf("official") >= 0
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) {
                            page.prefs.updatesSources = Updates.withSource(page.prefs.updatesSources, "official", value)
                        }
                    }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    label: updatesSection.t("bar.updates.source.aur")
                    description: updatesSection.t("bar.updates.source.aur.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "updatesAur"
                        checked: Updates.enabledSources(page.prefs.updatesSources).indexOf("aur") >= 0
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) {
                            page.prefs.updatesSources = Updates.withSource(page.prefs.updatesSources, "aur", value)
                        }
                    }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    label: updatesSection.t("bar.updates.source.flatpak")
                    description: updatesSection.t("bar.updates.source.flatpak.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "updatesFlatpak"
                        checked: Updates.enabledSources(page.prefs.updatesSources).indexOf("flatpak") >= 0
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) {
                            page.prefs.updatesSources = Updates.withSource(page.prefs.updatesSources, "flatpak", value)
                        }
                    }
                }

                VitrailSelect {
                    objectName: "updatesAurHelper"

                    Layout.fillWidth: true
                    label: updatesSection.t("bar.updates.helper")
                    options: [
                        { key: "auto", label: updatesSection.t("bar.updates.helper.auto") },
                        { key: "paru", label: "paru" },
                        { key: "yay", label: "yay" }
                    ]
                    current: page.prefs.updatesAurHelper || "auto"
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.updatesAurHelper = key }
                }
            }

            BarElementSection {
                id: disksSection

                Layout.fillWidth: true
                elementId: "disks"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "download"
                    label: disksSection.t("bar.disks.automount")
                    description: disksSection.t("bar.disks.automount.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "disksAutomount"
                        checked: page.prefs.disksAutomount === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.disksAutomount = value }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    text: disksSection.t("bar.disks.ignore")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: disksSection.t("bar.disks.ignore.help")
                }

                Repeater {
                    model: Disks.parseIgnore(page.prefs.disksIgnore)

                    delegate: VitrailSettingRow {
                        id: ignored

                        required property string modelData

                        objectName: "disksIgnoreEntry"

                        Layout.fillWidth: true
                        icon: "storage"
                        label: ignored.modelData
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            objectName: "disksIgnoreRemove"

                            variant: "text"
                            tone: "error"
                            icon: "delete"
                            onClicked: page.prefs.disksIgnore = Disks.withIgnore(page.prefs.disksIgnore, ignored.modelData, false)
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: Disks.parseIgnore(page.prefs.disksIgnore).length === 0
                    variant: "label"
                    text: disksSection.t("bar.disks.ignore.empty")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: ignoreField

                        Layout.fillWidth: true
                        label: disksSection.t("bar.disks.ignore.add")
                    }

                    VitrailButton {
                        objectName: "disksIgnoreAdd"

                        Layout.alignment: Qt.AlignBottom
                        variant: "tonal"
                        icon: "add"
                        text: disksSection.t("action.add")
                        enabled: ignoreField.text.trim() !== ""
                        onClicked: {
                            page.prefs.disksIgnore = Disks.withIgnore(page.prefs.disksIgnore, ignoreField.text, true)
                            ignoreField.text = ""
                        }
                    }
                }
            }

            BarElementSection {
                id: brightnessSection

                Layout.fillWidth: true
                elementId: "brightness"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "brightnessStep"

                    Layout.fillWidth: true
                    label: brightnessSection.t("bar.brightness.step")
                    suffix: "%"
                    from: VitrailTokens.ranges.brightnessStep.min
                    to: VitrailTokens.ranges.brightnessStep.max
                    stepSize: VitrailTokens.ranges.brightnessStep.step
                    value: page.prefs.brightnessStep
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.brightnessStep = value
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "bedtime"
                    label: brightnessSection.t("bar.brightness.nightLight")
                    description: brightnessSection.t("bar.brightness.nightLight.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "nightLightEnabled"
                        checked: page.prefs.nightLightEnabled === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.nightLightEnabled = value }
                    }
                }

                VitrailSlider {
                    objectName: "nightLightTemperature"

                    Layout.fillWidth: true
                    label: brightnessSection.t("bar.brightness.temperature")
                    suffix: " K"
                    from: Brightness.TEMPERATURE_MIN
                    to: Brightness.TEMPERATURE_MAX
                    stepSize: Brightness.TEMPERATURE_STEP
                    value: page.prefs.nightLightTemperature
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.nightLightTemperature = Math.round(value)
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    wrapMode: Text.WordWrap
                    text: brightnessSection.t("bar.brightness.temperature.help")
                }

                VitrailSelect {
                    objectName: "nightLightSchedule"

                    Layout.fillWidth: true
                    label: brightnessSection.t("bar.brightness.schedule")
                    options: [
                        { key: "off", label: brightnessSection.t("bar.brightness.schedule.off") },
                        { key: "fixed", label: brightnessSection.t("bar.brightness.schedule.fixed") },
                        { key: "sun", label: brightnessSection.t("bar.brightness.schedule.sun") }
                    ]
                    current: Brightness.scheduleOf(page.prefs.nightLightSchedule).mode
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) {
                        page.prefs.nightLightSchedule = Brightness.withMode(page.prefs.nightLightSchedule, key)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: nightLightStart

                        Layout.fillWidth: true
                        label: brightnessSection.t("bar.brightness.start")
                        text: Brightness.scheduleOf(page.prefs.nightLightSchedule).start
                        error: Brightness.clock(nightLightStart.text) === null
                        errorText: brightnessSection.t("bar.brightness.timeInvalid")
                        onAccepted: {
                            page.prefs.nightLightSchedule =
                                Brightness.withTime(page.prefs.nightLightSchedule, "start", nightLightStart.text)
                        }
                    }

                    VitrailField {
                        id: nightLightEnd

                        Layout.fillWidth: true
                        label: brightnessSection.t("bar.brightness.end")
                        text: Brightness.scheduleOf(page.prefs.nightLightSchedule).end
                        error: Brightness.clock(nightLightEnd.text) === null
                        errorText: brightnessSection.t("bar.brightness.timeInvalid")
                        onAccepted: {
                            page.prefs.nightLightSchedule =
                                Brightness.withTime(page.prefs.nightLightSchedule, "end", nightLightEnd.text)
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: Brightness.scheduleOf(page.prefs.nightLightSchedule).mode === "sun"
                    variant: "label"
                    wrapMode: Text.WordWrap
                    text: brightnessSection.t("bar.brightness.sun.hint")
                }
            }

            Item { Layout.preferredHeight: VitrailTokens.gap("xl") }
        }
    }
}
