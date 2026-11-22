import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/updates/updates.js" as Updates
import "../../bar/disks/disks.js" as Disks
import "../../bar/containers/containers.js" as Containers
import "../../bar/brightness/brightness.js" as Brightness
import "../../bar/battery/battery.js" as Battery
import "../../bar/resources/resources.js" as Resources
import "../../bar/netusage/netusage.js" as NetUsage
import "../../bar/health/health.js" as Health
import "../../bar/privacy/privacy.js" as Privacy
import "../../bar/weather/weather.js" as Weather
import "../../bar/market/market.js" as Market
import "../../bar/dnd/dnd.js" as Dnd
import "../../bar/caffeine/caffeine.js" as Caffeine
import "../../bar/elements.js" as Elements

// Bar elements category: one block per new-style bar element, each with the
// options every element shares (when it shows) and its own. The blocks sit in
// a one-column grid under their group headings, in the order of
// bar/elements.js PAGE_GROUPS (each block takes its row from there), so the
// order the blocks are written in below does not matter. A bar popup's gear
// lands on its element's block through `tab` (the element's id). A new
// element adds its BarElementSection here (docs/bar-elements.md).
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The element whose block to bring into view (a gear or a search result).
    property string tab: ""

    // A block may send the user to the page that owns a shared setting (the
    // Do Not Disturb apps live on Bar → Notifications).
    signal openCategory(string category, string tab)

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

        GridLayout {
            id: column

            width: parent.width
            columns: 1
            rowSpacing: VitrailTokens.gap("xl")
            columnSpacing: 0

            // One heading per group, on the row before its elements.
            Repeater {
                model: Elements.PAGE_GROUPS

                delegate: VitrailText {
                    required property var modelData

                    objectName: "barElementsGroup-" + modelData.key
                    Layout.row: Elements.headingRow(modelData.key)
                    Layout.fillWidth: true
                    Layout.topMargin: VitrailTokens.gap("md")
                    variant: "title"
                    color: page.palette.primary
                    text: {
                        var key = "bar.elements.group." + modelData.key
                        var value = page.strings[key]
                        return value === undefined ? key : value
                    }
                }
            }

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
                id: containersSection

                Layout.fillWidth: true
                elementId: "containers"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "containersEngine"

                    Layout.fillWidth: true
                    label: containersSection.t("bar.containers.engine")
                    options: [
                        { key: "auto", label: containersSection.t("bar.containers.engine.auto") },
                        { key: "docker", label: "docker" },
                        { key: "podman", label: "podman" }
                    ]
                    current: page.prefs.containersEngine || "auto"
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.containersEngine = key }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: containersSection.t("bar.containers.engine.help")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    text: containersSection.t("bar.containers.pins")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: containersSection.t("bar.containers.pins.help")
                }

                Repeater {
                    model: Containers.parsePinned(page.prefs.containersPinned)

                    delegate: VitrailSettingRow {
                        id: pinned

                        required property string modelData

                        objectName: "containersPinnedEntry"

                        Layout.fillWidth: true
                        icon: "push_pin"
                        label: pinned.modelData
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            objectName: "containersPinnedRemove"

                            variant: "text"
                            tone: "error"
                            icon: "delete"
                            onClicked: page.prefs.containersPinned =
                                Containers.withPinned(page.prefs.containersPinned, pinned.modelData, false)
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: Containers.parsePinned(page.prefs.containersPinned).length === 0
                    variant: "label"
                    text: containersSection.t("bar.containers.pins.empty")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: pinField

                        Layout.fillWidth: true
                        label: containersSection.t("bar.containers.pins.add")
                    }

                    VitrailButton {
                        objectName: "containersPinnedAdd"

                        Layout.alignment: Qt.AlignBottom
                        variant: "tonal"
                        icon: "add"
                        text: containersSection.t("action.add")
                        enabled: pinField.text.trim() !== ""
                        onClicked: {
                            page.prefs.containersPinned =
                                Containers.withPinned(page.prefs.containersPinned, pinField.text, true)
                            pinField.text = ""
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

            BarElementSection {
                id: peripheralsSection

                Layout.fillWidth: true
                elementId: "peripherals"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    text: peripheralsSection.t("bar.peripherals.hide")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: peripheralsSection.t("bar.peripherals.hide.help")
                }

                Repeater {
                    model: [
                        { kind: "mouse", icon: "mouse" },
                        { kind: "keyboard", icon: "keyboard" },
                        { kind: "headphones", icon: "headphones" },
                        { kind: "gamepad", icon: "sports_esports" }
                    ]

                    delegate: VitrailSettingRow {
                        id: hiddenKind

                        required property var modelData

                        Layout.fillWidth: true
                        icon: hiddenKind.modelData.icon
                        label: peripheralsSection.t("bar.peripherals.kind." + hiddenKind.modelData.kind)
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "peripheralsHide-" + hiddenKind.modelData.kind
                            checked: Battery.hidden({ kind: hiddenKind.modelData.kind },
                                                    Battery.parseHide(page.prefs.peripheralsHide))
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.peripheralsHide = Battery.withKind(page.prefs.peripheralsHide,
                                                                              hiddenKind.modelData.kind, value)
                            }
                        }
                    }
                }

                VitrailSlider {
                    objectName: "peripheralsLow"

                    Layout.fillWidth: true
                    label: peripheralsSection.t("bar.peripherals.low")
                    suffix: "%"
                    from: VitrailTokens.ranges.peripheralLow.min
                    to: VitrailTokens.ranges.peripheralLow.max
                    stepSize: VitrailTokens.ranges.peripheralLow.step
                    value: page.prefs.peripheralsLow
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.peripheralsLow = value
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: peripheralsSection.t("bar.peripherals.low.help")
                }
            }

            BarElementSection {
                id: resourcesSection

                Layout.fillWidth: true
                elementId: "resources"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "resourcesInterval"

                    Layout.fillWidth: true
                    label: resourcesSection.t("bar.resources.interval")
                    suffix: " s"
                    from: VitrailTokens.ranges.resourcesInterval.min
                    to: VitrailTokens.ranges.resourcesInterval.max
                    stepSize: VitrailTokens.ranges.resourcesInterval.step
                    value: Resources.interval(page.prefs.resourcesInterval)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.resourcesInterval = value
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: resourcesSection.t("bar.resources.interval.help")
                }

                VitrailSelect {
                    objectName: "resourcesBar"

                    Layout.fillWidth: true
                    label: resourcesSection.t("bar.resources.bar")
                    options: Resources.BAR_MODES.map(function (mode) {
                        return { key: mode, label: resourcesSection.t("bar.resources.bar." + mode) }
                    })
                    current: Resources.barMode(page.prefs.resourcesBar)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.resourcesBar = key }
                }

                VitrailSelect {
                    objectName: "resourcesUnits"

                    Layout.fillWidth: true
                    label: resourcesSection.t("bar.resources.units")
                    options: Resources.UNITS.map(function (mode) {
                        return { key: mode, label: resourcesSection.t("bar.resources.units." + mode) }
                    })
                    current: Resources.unitsMode(page.prefs.resourcesUnits)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.resourcesUnits = key }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: resourcesSection.t("bar.resources.units.help")
                }
            }

            BarElementSection {
                id: netusageSection

                Layout.fillWidth: true
                elementId: "netusage"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "netusageBar"

                    Layout.fillWidth: true
                    label: netusageSection.t("bar.netusage.bar")
                    options: NetUsage.BAR_MODES.map(function (mode) {
                        return { key: mode, label: netusageSection.t("bar.netusage.bar." + mode) }
                    })
                    current: NetUsage.barMode(page.prefs.netusageBar)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.netusageBar = key }
                }

                VitrailSelect {
                    objectName: "netusageUnits"

                    Layout.fillWidth: true
                    label: netusageSection.t("bar.netusage.units")
                    options: NetUsage.UNITS.map(function (mode) {
                        return { key: mode, label: netusageSection.t("bar.netusage.units." + mode) }
                    })
                    current: Resources.unitsMode(page.prefs.netusageUnits)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.netusageUnits = key }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: netusageSection.t("bar.netusage.units.help")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: netusageSection.t("bar.netusage.interval.help")
                }
            }

            BarElementSection {
                id: healthSection

                Layout.fillWidth: true
                elementId: "health"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "healthDiskThreshold"

                    Layout.fillWidth: true
                    label: healthSection.t("bar.health.threshold")
                    suffix: "%"
                    from: VitrailTokens.ranges.healthDisk.min
                    to: VitrailTokens.ranges.healthDisk.max
                    stepSize: VitrailTokens.ranges.healthDisk.step
                    value: Health.threshold(page.prefs.healthDiskThreshold)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.healthDiskThreshold = value
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: healthSection.t("bar.health.threshold.help")
                }

                Repeater {
                    model: Health.CHECKS

                    delegate: VitrailSettingRow {
                        id: checkRow

                        required property string modelData

                        Layout.fillWidth: true
                        label: healthSection.t("bar.health.check." + checkRow.modelData)
                        description: healthSection.t("bar.health.check." + checkRow.modelData + ".help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "healthCheck-" + checkRow.modelData
                            checked: Health.enabledChecks(page.prefs.healthChecks).indexOf(checkRow.modelData) >= 0
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.healthChecks = Health.withCheck(page.prefs.healthChecks,
                                                                           checkRow.modelData, value)
                            }
                        }
                    }
                }
            }

            BarElementSection {
                id: privacySection

                Layout.fillWidth: true
                elementId: "privacy"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                Repeater {
                    model: Privacy.KINDS

                    delegate: VitrailSettingRow {
                        id: watchRow

                        required property string modelData

                        Layout.fillWidth: true
                        label: privacySection.t("bar.privacy.watch." + watchRow.modelData)
                        description: privacySection.t("bar.privacy.watch." + watchRow.modelData + ".help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "privacyWatch-" + watchRow.modelData
                            checked: Privacy.watching(page.prefs.privacyWatch, watchRow.modelData)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.privacyWatch = Privacy.withWatch(page.prefs.privacyWatch,
                                                                            watchRow.modelData, value)
                            }
                        }
                    }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    label: privacySection.t("bar.privacy.dotColor")
                    description: privacySection.t("bar.privacy.dotColor.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSelect {
                        objectName: "privacyDotColor"

                        Layout.preferredWidth: VitrailTokens.size("display") * 5
                        current: Privacy.dotToken(page.prefs.privacyDotColor)
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        options: Privacy.DOT_COLORS.map(function (key) {
                            return { key: key, label: privacySection.t("bar.privacy.dotColor." + key) }
                        })
                        onSelected: function (key) { page.prefs.privacyDotColor = Privacy.dotToken(key) }
                    }
                }
            }

            BarElementSection {
                id: weatherSection

                Layout.fillWidth: true
                elementId: "weather"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    text: weatherSection.t("bar.weather.cities")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: weatherSection.t("bar.weather.cities.help")
                }

                Repeater {
                    model: Weather.cities(page.prefs.weatherCities, "")

                    delegate: VitrailSettingRow {
                        id: weatherCity

                        required property string modelData

                        objectName: "weatherCityEntry"

                        Layout.fillWidth: true
                        icon: "place"
                        label: weatherCity.modelData
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            objectName: "weatherCityRemove"

                            variant: "text"
                            tone: "error"
                            icon: "delete"
                            onClicked: {
                                var rest = Weather.cities(page.prefs.weatherCities, "")
                                        .filter(function (name) { return name !== weatherCity.modelData })
                                page.prefs.weatherCities = Weather.withCities(rest)
                            }
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: Weather.cities(page.prefs.weatherCities, "").length === 0
                    variant: "label"
                    text: weatherSection.t("bar.weather.cities.empty")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: weatherCityField

                        Layout.fillWidth: true
                        label: weatherSection.t("bar.weather.cities.add")
                    }

                    VitrailButton {
                        objectName: "weatherCityAdd"

                        Layout.alignment: Qt.AlignBottom
                        variant: "tonal"
                        icon: "add"
                        text: weatherSection.t("action.add")
                        enabled: weatherCityField.text.trim() !== ""
                        onClicked: {
                            var names = Weather.cities(page.prefs.weatherCities, "")
                            names.push(weatherCityField.text)
                            page.prefs.weatherCities = Weather.withCities(names)
                            weatherCityField.text = ""
                        }
                    }
                }

                VitrailSelect {
                    objectName: "weatherUnits"

                    Layout.fillWidth: true
                    label: weatherSection.t("bar.weather.units")
                    options: [
                        { key: "metric", label: weatherSection.t("bar.weather.units.metric") },
                        { key: "imperial", label: weatherSection.t("bar.weather.units.imperial") }
                    ]
                    current: page.prefs.weatherUnits || "metric"
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.weatherUnits = key }
                }

                VitrailSelect {
                    objectName: "weatherInterval"

                    Layout.fillWidth: true
                    label: weatherSection.t("bar.weather.interval")
                    options: {
                        var minutes = [15, 30, 60, 120, 360, 720]
                        var now = Weather.intervalMinutes(page.prefs.weatherInterval)
                        if (minutes.indexOf(now) < 0)
                            minutes.push(now)
                        minutes.sort(function (a, b) { return a - b })
                        return minutes.map(function (value) {
                            return { key: String(value),
                                     label: weatherSection.t("bar.weather.intervalOption").replace("%1", value) }
                        })
                    }
                    current: String(Weather.intervalMinutes(page.prefs.weatherInterval))
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.weatherInterval = Number(key) }
                }
            }

            BarElementSection {
                id: marketSection

                Layout.fillWidth: true
                elementId: "market"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "marketCurrency"

                    Layout.fillWidth: true
                    label: marketSection.t("bar.market.currency")
                    options: Market.currencyOptions()
                    current: Market.currencyOf(page.prefs.marketCurrency)
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.marketCurrency = key }
                }

                VitrailSelect {
                    objectName: "marketInterval"

                    Layout.fillWidth: true
                    label: marketSection.t("bar.market.interval")
                    options: {
                        var minutes = Market.INTERVALS.slice()
                        var now = Market.intervalMinutes(page.prefs.marketInterval)
                        if (minutes.indexOf(now) < 0)
                            minutes.push(now)
                        minutes.sort(function (a, b) { return a - b })
                        return minutes.map(function (value) {
                            return { key: String(value),
                                     label: marketSection.t("bar.market.intervalOption").replace("%1", value) }
                        })
                    }
                    current: String(Market.intervalMinutes(page.prefs.marketInterval))
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.marketInterval = Number(key) }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    text: marketSection.t("bar.market.symbols")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: marketSection.t("bar.market.symbols.help")
                }

                Repeater {
                    model: Market.symbolsOf(page.prefs.marketSymbols)

                    delegate: VitrailSettingRow {
                        id: symbolRow

                        required property string modelData

                        objectName: "marketSymbolEntry"

                        Layout.fillWidth: true
                        icon: "monitoring"
                        label: symbolRow.modelData
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            objectName: "marketSymbolRemove"

                            variant: "text"
                            tone: "error"
                            icon: "delete"
                            onClicked: page.prefs.marketSymbols =
                                Market.withSymbol(page.prefs.marketSymbols, symbolRow.modelData, false)
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: Market.symbolsOf(page.prefs.marketSymbols).length === 0
                    variant: "label"
                    text: marketSection.t("bar.market.symbols.empty")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: symbolField

                        Layout.fillWidth: true
                        label: marketSection.t("bar.market.symbols.add")
                    }

                    VitrailButton {
                        objectName: "marketSymbolAdd"

                        Layout.alignment: Qt.AlignBottom
                        variant: "tonal"
                        icon: "add"
                        text: marketSection.t("action.add")
                        enabled: Market.normalizeSymbol(symbolField.text) !== ""
                        onClicked: {
                            page.prefs.marketSymbols =
                                Market.withSymbol(page.prefs.marketSymbols, symbolField.text, true)
                            symbolField.text = ""
                        }
                    }
                }
            }

            BarElementSection {
                id: downloadsSection

                Layout.fillWidth: true
                elementId: "downloads"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "downloadsRecent"

                    Layout.fillWidth: true
                    label: downloadsSection.t("bar.downloads.recentOption")
                    from: VitrailTokens.ranges.downloadsRecent.min
                    to: VitrailTokens.ranges.downloadsRecent.max
                    stepSize: VitrailTokens.ranges.downloadsRecent.step
                    value: page.prefs.downloadsRecent
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.downloadsRecent = Math.round(value)
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: downloadsSection.t("bar.downloads.recentOption.help")
                }
            }

            BarElementSection {
                id: dndSection

                Layout.fillWidth: true
                elementId: "dnd"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "dndDefaultMinutes"

                    Layout.fillWidth: true
                    label: dndSection.t("bar.dnd.default")
                    options: [
                        { key: "30", label: dndSection.t("bar.dnd.30m") },
                        { key: "60", label: dndSection.t("bar.dnd.1h") },
                        { key: "0", label: dndSection.t("bar.dnd.tomorrow") }
                    ]
                    current: String(Dnd.minutesOf(page.prefs.dndDefaultMinutes))
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.dndDefaultMinutes = Number(key) }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: dndSection.t("bar.dnd.default.help")
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "notifications_active"
                    label: dndSection.t("bar.dnd.settings.apps")
                    description: dndSection.t("bar.dnd.settings.apps.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailButton {
                        objectName: "dndAppsSettings"

                        variant: "tonal"
                        tone: "secondary"
                        size: "sm"
                        icon: "notifications"
                        text: dndSection.t("bar.dnd.settings.open")
                        onClicked: page.openCategory("bar", "notifications")
                    }
                }
            }

            BarElementSection {
                id: caffeineSection

                Layout.fillWidth: true
                elementId: "caffeine"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSelect {
                    objectName: "caffeineMinutes"

                    Layout.fillWidth: true
                    label: caffeineSection.t("bar.caffeine.default")
                    options: [
                        { key: "15", label: caffeineSection.t("bar.caffeine.15m") },
                        { key: "30", label: caffeineSection.t("bar.caffeine.30m") },
                        { key: "60", label: caffeineSection.t("bar.caffeine.1h") },
                        { key: "0", label: caffeineSection.t("bar.caffeine.untilOff") }
                    ]
                    current: String(Caffeine.minutesOf(page.prefs.caffeineMinutes))
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: function (key) { page.prefs.caffeineMinutes = Number(key) }
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: caffeineSection.t("bar.caffeine.default.help")
                }
            }

            BarElementSection {
                id: pomodoroSection

                Layout.fillWidth: true
                elementId: "pomodoro"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "pomodoroWork"

                    Layout.fillWidth: true
                    label: pomodoroSection.t("bar.widgets.pomodoroWork")
                    suffix: " min"
                    from: VitrailTokens.ranges.pomodoroWork.min
                    to: VitrailTokens.ranges.pomodoroWork.max
                    stepSize: VitrailTokens.ranges.pomodoroWork.step
                    value: page.prefs.pomodoroWork
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.pomodoroWork = value
                }

                VitrailSlider {
                    objectName: "pomodoroRest"

                    Layout.fillWidth: true
                    label: pomodoroSection.t("bar.widgets.pomodoroRest")
                    suffix: " min"
                    from: VitrailTokens.ranges.pomodoroRest.min
                    to: VitrailTokens.ranges.pomodoroRest.max
                    stepSize: VitrailTokens.ranges.pomodoroRest.step
                    value: page.prefs.pomodoroRest
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.pomodoroRest = value
                }

                VitrailSlider {
                    objectName: "pomodoroCycles"

                    Layout.fillWidth: true
                    label: pomodoroSection.t("bar.widgets.pomodoroCycles")
                    from: VitrailTokens.ranges.pomodoroCycles.min
                    to: VitrailTokens.ranges.pomodoroCycles.max
                    stepSize: VitrailTokens.ranges.pomodoroCycles.step
                    value: page.prefs.pomodoroCycles
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.pomodoroCycles = value
                }

                VitrailSlider {
                    objectName: "pomodoroTimerMinutes"

                    Layout.fillWidth: true
                    label: pomodoroSection.t("bar.widgets.timerMinutes")
                    suffix: " min"
                    from: VitrailTokens.ranges.timerMinutes.min
                    to: VitrailTokens.ranges.timerMinutes.max
                    stepSize: VitrailTokens.ranges.timerMinutes.step
                    value: page.prefs.timerMinutes
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.timerMinutes = value
                }
            }

            BarElementSection {
                id: notesSection

                Layout.fillWidth: true
                elementId: "notes"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "notesPopupMax"

                    Layout.fillWidth: true
                    label: notesSection.t("bar.notes.popupMax")
                    from: VitrailTokens.ranges.notesPopupMax.min
                    to: VitrailTokens.ranges.notesPopupMax.max
                    stepSize: VitrailTokens.ranges.notesPopupMax.step
                    value: page.prefs.notesPopupMax
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.notesPopupMax = value
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: notesSection.t("bar.notes.popupMax.help")
                }
            }

            BarElementSection {
                id: clipboardbarSection

                Layout.fillWidth: true
                elementId: "clipboardbar"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "clipboardbarRecent"

                    Layout.fillWidth: true
                    label: clipboardbarSection.t("bar.clipboardbar.recentOption")
                    from: VitrailTokens.ranges.clipboardbarRecent.min
                    to: VitrailTokens.ranges.clipboardbarRecent.max
                    stepSize: VitrailTokens.ranges.clipboardbarRecent.step
                    value: page.prefs.clipboardbarRecent
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.clipboardbarRecent = Math.round(value)
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: clipboardbarSection.t("bar.clipboardbar.recentOption.help")
                }
            }

            BarElementSection {
                id: colorpickerSection

                Layout.fillWidth: true
                elementId: "colorpicker"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "colorpickerRecent"

                    Layout.fillWidth: true
                    label: colorpickerSection.t("bar.colorpicker.recentOption")
                    from: VitrailTokens.ranges.colorpickerRecent.min
                    to: VitrailTokens.ranges.colorpickerRecent.max
                    stepSize: VitrailTokens.ranges.colorpickerRecent.step
                    value: page.prefs.colorpickerRecent
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.colorpickerRecent = Math.round(value)
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    text: colorpickerSection.t("bar.colorpicker.recentOption.help")
                }
            }

            Item {
                Layout.row: Elements.pageRows()
                Layout.preferredHeight: VitrailTokens.gap("xl")
            }
        }
    }
}
