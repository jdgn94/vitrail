import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../layouts.js" as Layouts

// The bar tab of the in-place editor. It holds everything that used to live in
// Settings → Bar: the bar's own look (edge, tray style, chips, style, screens,
// opacity and size) and the placement of its elements — one list per group,
// with visibility, order, a group selector, chips and dividers, plus density,
// fullscreen hiding and the per-monitor override.
//
// The document is the state: every edit is one whole `barLayout` write, emitted
// as `committed`, and the parent keeps the text and persists it.
Item {
    id: root

    property var strings: ({})
    // The bar preferences Settings no longer edits (`bar.ini`).
    property var bar: ({ edge: "left", trayStyle: "inline", batteryChip: true,
                         bluetoothChip: true, keyboard: true, style: "",
                         screens: "primary", opacityFollow: true,
                         opacity: VitrailTokens.ranges.opacity.value,
                         size: VitrailTokens.ranges.bar.value })
    // The outputs the monitor override can name: [{ name }].
    property var monitors: []
    // The whole bar document and the monitor being edited ("" is global).
    property string layoutText: ""
    property string monitor: ""

    signal committed(string text)
    signal prefChanged(string key, var value)

    readonly property var doc: Layouts.effective(root.layoutText, root.monitor, null, "bar")
    readonly property string edge: root.bar.edge || "left"
    readonly property string trayStyle: root.bar.trayStyle || "inline"
    readonly property string style: root.bar.style || ""
    readonly property string screens: root.bar.screens || "primary"
    readonly property bool opacityFollow: root.bar.opacityFollow !== false
    readonly property real barOpacityValue: root.bar.opacity !== undefined
                                             && root.bar.opacity !== ""
                                             ? Number(root.bar.opacity)
                                             : VitrailTokens.ranges.opacity.value
    readonly property real barSize: root.bar.size !== undefined && root.bar.size !== ""
                                    ? Number(root.bar.size)
                                    : VitrailTokens.ranges.bar.value

    readonly property var icons: ({
        edge: { left: "left_panel_open", top: "top_panel_open",
                right: "right_panel_open", bottom: "bottom_panel_open" },
        screens: { primary: "monitor", all: "devices" },
        group: { start: "first_page", center: "filter_center_focus", end: "last_page" },
        widget: {
            launcher: "apps", workspaces: "view_column", notifications: "notifications",
            title: "desktop_windows", media: "play_circle",
            clock: "schedule", capture: "screenshot_monitor", recording: "stop_circle",
            tray: "widgets", network: "lan", bluetooth: "bluetooth", vpn: "shield",
            profile: "speed", battery: "battery_full", keyboard: "keyboard",
            power: "power_settings_new", divider: "vertical_split"
        }
    })

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function options(prefix, keys, icons) {
        return keys.map(function (key) {
            return { key: key, icon: icons[key], label: root.t(prefix + key) }
        })
    }

    function groupOptions() {
        return Layouts.groups("bar").map(function (group) {
            return { key: group, icon: root.icons.group[group] || "widgets", label: "" }
        })
    }

    function monitorOptions() {
        var out = [{ key: "", label: root.t("bar.editor.global") }]
        for (var i = 0; i < root.monitors.length; i++)
            out.push({ key: root.monitors[i].name, label: root.monitors[i].name })
        return out
    }

    // One whole document write, on the selected monitor (or globally).
    function commit(patch) {
        var text = Layouts.write(root.layoutText, root.monitor, patch, "bar")
        if (text !== null)
            root.committed(text)
    }

    // Density and fullscreen hiding belong to the whole bar, not one monitor.
    function commitGlobal(patch) {
        var text = Layouts.write(root.layoutText, "", patch, "bar")
        if (text !== null)
            root.committed(text)
    }

    function setVisible(id, visible) {
        if (visible === (root.doc.hidden.indexOf(id) < 0))
            return
        root.commit({ hidden: Layouts.toggle(root.doc.hidden, id) })
    }

    function moveWidget(id, delta) {
        root.commit({ order: Layouts.move(root.doc.order, id, delta) })
    }

    // --- entries: elements, chips and dividers -------------------------------

    function labelOf(id) {
        var widget = Layouts.find(id, "bar")
        return root.t(widget ? widget.labelKey : id)
    }

    function entryFixed(entry) {
        return !Layouts.isChipToken(entry) && !Layouts.isDivider(entry)
               && Layouts.isFixed(entry, "bar")
    }

    function entryIcon(entry) {
        if (Layouts.isChipToken(entry))
            return "link"
        if (Layouts.isDivider(entry))
            return "vertical_split"
        return root.icons.widget[entry] || "widgets"
    }

    function entryLabel(entry) {
        if (Layouts.isChipToken(entry))
            return root.t("bar.editor.chip")
        return root.labelOf(entry)
    }

    function chipMembers(chipId) {
        var chip = Layouts.chipEntry(root.doc.chips, chipId)
        return chip ? chip.members.slice() : []
    }

    function entryDescription(entry) {
        if (Layouts.isChipToken(entry)) {
            var members = root.chipMembers(Layouts.chipName(entry))
            if (members.length === 0)
                return root.t("bar.editor.chip.empty")
            return members.map(function (id) { return root.labelOf(id) }).join(" · ")
        }
        if (Layouts.isDivider(entry))
            return root.t("bar.editor.divider.help")
        return root.entryFixed(entry) ? root.t("bar.editor.fixed") : ""
    }

    function chipCandidates(chipId) {
        return Layouts.widgets("bar").filter(function (widget) {
            if (widget.fixed || widget.optional || Layouts.isDivider(widget.id))
                return false
            var owner = Layouts.chipOf(root.doc.chips, widget.id)
            return (owner === null || owner === chipId)
                   && root.chipMembers(chipId).indexOf(widget.id) < 0
        })
    }

    function moveEntry(entry, group) {
        var at = root.doc.order[group] ? root.doc.order[group].length : 0
        root.commit({ order: Layouts.moveTo(root.doc.order, entry, group, at, "bar") })
    }

    function addChip(group) {
        var result = Layouts.newChip(root.doc.order, root.doc.chips, group, "bar")
        root.commit({ order: result.order, chips: result.chips })
    }

    function addDivider(group) {
        root.commit({ order: Layouts.addDivider(root.doc.order, group, undefined, "bar") })
    }

    function removeEntry(entry) {
        if (Layouts.isChipToken(entry)) {
            var result = Layouts.removeChip(root.doc.order, root.doc.chips,
                                            Layouts.chipName(entry))
            root.commit({ order: result.order, chips: result.chips })
        } else if (Layouts.isDivider(entry)) {
            root.commit({ order: Layouts.removeDivider(root.doc.order, entry) })
        }
    }

    function toggleChipMember(chipId, id) {
        var members = root.chipMembers(chipId)
        var at = members.indexOf(id)
        if (at < 0)
            members.push(id)
        else
            members.splice(at, 1)
        var result = Layouts.setChipMembers(root.doc.order, root.doc.chips, chipId, members, "bar")
        root.commit({ order: result.order, chips: result.chips })
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("md")

            // --- the bar's own options -------------------------------------
            VitrailSurface {
                Layout.fillWidth: true
                implicitHeight: optionsColumn.implicitHeight + 2 * VitrailTokens.gap("md")
                radius: VitrailTokens.radius
                tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                opacityLevel: VitrailTokens.opacity * 0.83

                ColumnLayout {
                    id: optionsColumn

                    anchors.fill: parent
                    anchors.margins: VitrailTokens.gap("md")
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "subtitle"
                        text: root.t("desktop.edit.bar.options")
                    }

                    VitrailSettingRow {
                        icon: "dock_to_left"
                        label: root.t("bar.edge")

                        VitrailSegmented {
                            objectName: "editorBarEdge"

                            options: root.options("bar.edge.",
                                                  ["left", "top", "right", "bottom"],
                                                  root.icons.edge)
                            current: root.edge
                            onSelected: root.prefChanged("barEdge", key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "dock_to_bottom"
                        label: root.t("bar.trayStyle")

                        VitrailSegmented {
                            objectName: "editorBarTrayStyle"

                            options: root.options("bar.trayStyle.", ["inline", "popup"], ({}))
                            current: root.trayStyle
                            onSelected: root.prefChanged("trayStyle", key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "battery_full"
                        label: root.t("bar.batteryChip")
                        description: root.t("bar.batteryChip.help")

                        VitrailSwitch {
                            objectName: "editorBarBatteryChip"

                            checked: root.bar.batteryChip !== false
                            onToggled: root.prefChanged("barBatteryChip", value)
                        }
                    }

                    VitrailSettingRow {
                        icon: "bluetooth"
                        label: root.t("bar.bluetoothChip")
                        description: root.t("bar.bluetoothChip.help")

                        VitrailSwitch {
                            objectName: "editorBarBluetoothChip"

                            checked: root.bar.bluetoothChip !== false
                            onToggled: root.prefChanged("barBluetoothChip", value)
                        }
                    }

                    VitrailSettingRow {
                        icon: "keyboard"
                        label: root.t("bar.keyboardChip")
                        description: root.t("bar.keyboardChip.help")

                        VitrailSwitch {
                            objectName: "editorBarKeyboardChip"

                            checked: root.bar.keyboard !== false
                            onToggled: root.prefChanged("barKeyboard", value)
                        }
                    }

                    VitrailSettingRow {
                        icon: "style"
                        label: root.t("bar.style")

                        VitrailSegmented {
                            objectName: "editorBarStyle"

                            options: root.options("bar.style.", Object.keys(VitrailVariants.bar),
                                                  ({}))
                            current: root.style || VitrailStyle.defaults.bar
                            onSelected: root.prefChanged("barStyle", key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "desktop_windows"
                        label: root.t("bar.screens")

                        VitrailSegmented {
                            objectName: "editorBarScreens"

                            options: root.options("bar.screens.", ["primary", "all"],
                                                  root.icons.screens)
                            current: root.screens
                            onSelected: root.prefChanged("barScreens", key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "opacity"
                        label: root.t("bar.opacity")

                        VitrailSegmented {
                            objectName: "editorBarOpacityMode"

                            options: [
                                { key: "follow", icon: "sync", label: root.t("bar.opacity.follow") },
                                { key: "own", icon: "tune", label: root.t("bar.opacity.own") }
                            ]
                            current: root.opacityFollow ? "follow" : "own"
                            onSelected: root.prefChanged("barOpacityFollow", key === "follow")
                        }
                    }

                    VitrailSlider {
                        objectName: "editorBarOpacity"

                        Layout.fillWidth: true
                        visible: !root.opacityFollow
                        label: root.t("bar.opacity.value")
                        suffix: "%"
                        from: VitrailTokens.ranges.opacity.min * 100
                        to: VitrailTokens.ranges.opacity.max * 100
                        stepSize: VitrailTokens.ranges.opacity.step * 100
                        value: root.barOpacityValue * 100
                        onMoved: root.prefChanged("barOpacity", value / 100)
                    }

                    VitrailSlider {
                        objectName: "editorBarSize"

                        Layout.fillWidth: true
                        label: root.t("bar.size")
                        suffix: " px"
                        from: VitrailTokens.ranges.bar.min
                        to: VitrailTokens.ranges.bar.max
                        stepSize: VitrailTokens.ranges.bar.step
                        value: root.barSize
                        onMoved: root.prefChanged("barSize", value)
                    }
                }
            }

            // --- placement --------------------------------------------------
            VitrailSurface {
                Layout.fillWidth: true
                implicitHeight: placementColumn.implicitHeight + 2 * VitrailTokens.gap("md")
                radius: VitrailTokens.radius
                tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                opacityLevel: VitrailTokens.opacity * 0.83

                ColumnLayout {
                    id: placementColumn

                    anchors.fill: parent
                    anchors.margins: VitrailTokens.gap("md")
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "subtitle"
                        text: root.t("desktop.edit.bar.elements")
                    }

                    VitrailSettingRow {
                        icon: "monitor"
                        label: root.t("bar.editor.monitor")
                        description: root.t("bar.editor.monitor.help")

                        VitrailSegmented {
                            objectName: "editorBarMonitor"

                            options: root.monitorOptions()
                            current: root.monitor
                            onSelected: root.monitor = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "compress"
                        label: root.t("bar.editor.density")
                        description: root.t("bar.editor.density.help")

                        VitrailSegmented {
                            objectName: "editorBarDensity"

                            options: [
                                { key: "comfortable", icon: "density_medium",
                                  label: root.t("bar.editor.density.comfortable") },
                                { key: "compact", icon: "density_small",
                                  label: root.t("bar.editor.density.compact") }
                            ]
                            current: root.doc.density
                            onSelected: root.commitGlobal({ density: key })
                        }
                    }

                    VitrailSettingRow {
                        icon: "fullscreen"
                        label: root.t("bar.editor.fullscreen")
                        description: root.t("bar.editor.fullscreen.help")

                        VitrailSwitch {
                            objectName: "editorBarFullscreen"

                            checked: root.doc.hideFullscreen
                            onToggled: root.commitGlobal({ hideFullscreen: value })
                        }
                    }
                }
            }

            // One list per group, in the document's order: an element, a chip
            // or a divider.
            Repeater {
                model: Layouts.groups("bar")

                delegate: VitrailSurface {
                    id: groupCard

                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: groupColumn.implicitHeight + 2 * VitrailTokens.gap("md")
                    radius: VitrailTokens.radius
                    tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                    opacityLevel: VitrailTokens.opacity * 0.83

                    ColumnLayout {
                        id: groupColumn

                        anchors.fill: parent
                        anchors.margins: VitrailTokens.gap("md")
                        spacing: VitrailTokens.gap("xs")

                        VitrailText {
                            variant: "subtitle"
                            text: root.t("bar.editor.group." + groupCard.modelData)
                        }

                        Repeater {
                            model: root.doc.order[groupCard.modelData] || []

                            delegate: ColumnLayout {
                                id: widgetRow

                                required property string modelData
                                required property int index

                                readonly property var ids: root.doc.order[groupCard.modelData] || []
                                readonly property bool chipEntry: Layouts.isChipToken(widgetRow.modelData)
                                readonly property bool dividerEntry: Layouts.isDivider(widgetRow.modelData)
                                readonly property string chipId: widgetRow.chipEntry
                                                               ? Layouts.chipName(widgetRow.modelData) : ""
                                readonly property string entry: widgetRow.modelData

                                objectName: "editorBarEntry-" + widgetRow.modelData
                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("xs")

                                VitrailSettingRow {
                                    Layout.fillWidth: true
                                    icon: root.entryIcon(widgetRow.entry)
                                    label: root.entryLabel(widgetRow.entry)
                                    description: root.entryDescription(widgetRow.entry)

                                    VitrailSwitch {
                                        objectName: "editorBarVisible-" + widgetRow.entry
                                        visible: !widgetRow.chipEntry
                                        checked: root.doc.hidden.indexOf(widgetRow.entry) < 0
                                        onToggled: root.setVisible(widgetRow.entry, value)
                                    }

                                    VitrailSegmented {
                                        objectName: "editorBarGroup-" + widgetRow.entry
                                        visible: !root.entryFixed(widgetRow.entry)
                                        options: root.groupOptions()
                                        current: groupCard.modelData
                                        onSelected: root.moveEntry(widgetRow.entry, key)
                                    }

                                    VitrailButton {
                                        objectName: "editorBarUp-" + widgetRow.entry
                                        variant: "text"
                                        icon: "arrow_upward"
                                        enabled: widgetRow.index > 0
                                        onClicked: root.moveWidget(widgetRow.entry, -1)
                                    }

                                    VitrailButton {
                                        objectName: "editorBarDown-" + widgetRow.entry
                                        variant: "text"
                                        icon: "arrow_downward"
                                        enabled: widgetRow.index < widgetRow.ids.length - 1
                                        onClicked: root.moveWidget(widgetRow.entry, 1)
                                    }

                                    VitrailButton {
                                        objectName: "editorBarRemove-" + widgetRow.entry
                                        variant: "text"
                                        tone: "error"
                                        icon: "remove_circle_outline"
                                        visible: widgetRow.chipEntry || widgetRow.dividerEntry
                                        onClicked: root.removeEntry(widgetRow.entry)
                                    }
                                }

                                Repeater {
                                    model: widgetRow.chipEntry
                                           ? root.chipMembers(widgetRow.chipId) : []

                                    delegate: VitrailSettingRow {
                                        id: memberRow

                                        required property string modelData

                                        Layout.fillWidth: true
                                        Layout.leftMargin: VitrailTokens.gap("lg")
                                        icon: root.entryIcon(memberRow.modelData)
                                        label: root.labelOf(memberRow.modelData)

                                        VitrailSwitch {
                                            objectName: "editorBarChipVisible-"
                                                        + widgetRow.chipId + "-" + memberRow.modelData
                                            checked: root.doc.hidden.indexOf(memberRow.modelData) < 0
                                            onToggled: root.setVisible(memberRow.modelData, value)
                                        }

                                        VitrailButton {
                                            objectName: "editorBarChipRemove-"
                                                        + widgetRow.chipId + "-" + memberRow.modelData
                                            variant: "text"
                                            icon: "close"
                                            onClicked: root.toggleChipMember(widgetRow.chipId,
                                                                             memberRow.modelData)
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: VitrailTokens.gap("lg")
                                    visible: widgetRow.chipEntry
                                             && root.chipCandidates(widgetRow.chipId).length > 0
                                    spacing: VitrailTokens.gap("xs")

                                    Repeater {
                                        model: widgetRow.chipEntry
                                               ? root.chipCandidates(widgetRow.chipId) : []

                                        delegate: VitrailButton {
                                            required property var modelData

                                            objectName: "editorBarChipAdd-" + widgetRow.chipId
                                                        + "-" + modelData.id
                                            variant: "outlined"
                                            tone: "secondary"
                                            size: "sm"
                                            icon: "add"
                                            text: root.t(modelData.labelKey)
                                            onClicked: root.toggleChipMember(widgetRow.chipId,
                                                                             modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailButton {
                                objectName: "editorBarAddChip-" + groupCard.modelData
                                variant: "outlined"
                                tone: "secondary"
                                size: "sm"
                                icon: "link"
                                text: root.t("bar.editor.chip.add")
                                onClicked: root.addChip(groupCard.modelData)
                            }

                            VitrailButton {
                                objectName: "editorBarAddDivider-" + groupCard.modelData
                                variant: "outlined"
                                tone: "secondary"
                                size: "sm"
                                icon: "horizontal_rule"
                                text: root.t("bar.editor.divider.add")
                                onClicked: root.addDivider(groupCard.modelData)
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
