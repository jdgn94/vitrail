import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/layouts.js" as Layouts
import "../../bar/widgets.js" as Widgets

// Bar category: where the system bar docks, its style, the screen frame,
// the side panels and where notifications appear. An empty preference
// inherits the family default from VitrailStyle.
//
// Its Editor tab is the one UI for the bar's elements: their order in the
// start / center / end groups, their visibility per monitor, the density and
// whether a fullscreen window hides the bar. It writes bar.ini `barLayout`, the
// document bar/shell.qml reads (bar/layouts.js), so panel, desktop and lock
// can offer the same editor later with a document of their own.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "layout"
    // { available, monitors: [{ name, … }] } as the settings window injected it.
    property var monitors: ({ available: false, monitors: [] })
    // The installed text families, as the settings window injected them
    // (`{ fonts: [...] }`); the typography picker lists them.
    property var fonts: ({ fonts: [], monospace: [] })
    // The monitor whose order and visibility the editor edits; "" is global.
    property string monitor: ""
    // Which surface the editor edits: "bar" (today's groups) or "panel" (one
    // flat list). The desktop will reuse the same surface switch.
    property string editorSurface: "bar"
    readonly property var layout: Layouts.effective(page.prefs.barLayout || "", page.monitor)
    // The panel's flat document (bar.ini `panelLayout`); empty is today's panel.
    readonly property var panelLayout: Layouts.effective(page.prefs.panelLayout || "", "", null, "panel")
    // The desktop widgets of the selected output (bar.ini `desktopLayout`).
    property string desktopMonitor: ""
    // The placed widget whose typography the editor is showing; "" is none.
    property string desktopSelection: ""
    readonly property var desktopOutputs: page.monitors && page.monitors.monitors
                                             ? page.monitors.monitors : []
    readonly property string desktopMonitorName: {
        for (var i = 0; i < page.desktopOutputs.length; i++) {
            if (page.desktopOutputs[i].name === page.desktopMonitor)
                return page.desktopMonitor
        }
        return page.desktopOutputs.length > 0 ? page.desktopOutputs[0].name : ""
    }
    readonly property var desktopOutput: {
        for (var i = 0; i < page.desktopOutputs.length; i++) {
            if (page.desktopOutputs[i].name === page.desktopMonitorName)
                return page.desktopOutputs[i]
        }
        return null
    }
    readonly property real desktopAspect: page.desktopOutput && page.desktopOutput.width > 0
                                          && page.desktopOutput.height > 0
                                          ? page.desktopOutput.width / page.desktopOutput.height
                                          : 16 / 9
    readonly property var desktopDocument: Layouts.effective(page.prefs.desktopLayout || "",
                                                              page.desktopMonitorName, null, "desktop")
    readonly property var desktopAvailable: {
        var placed = page.desktopDocument.widgets.map(function (widget) { return widget.id })
        return Layouts.widgets("desktop").filter(function (widget) {
            return placed.indexOf(widget.id) < 0
        })
    }
    // The placed entry the Typography section edits, or null; it follows the
    // document, so it disappears when the widget does.
    readonly property var desktopSelectedEntry: page.desktopEntry(page.desktopSelection)
    // Where a dragged panel widget would land: an insertion index, -1 when no
    // drag is running.
    property int panelDragFrom: -1
    property int panelDropIndex: -1

    onTabChanged: scroller.contentY = 0
    onDesktopMonitorChanged: page.desktopSelection = ""

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function labelOf(id) {
        var widget = Layouts.find(id)
        return page.t(widget ? widget.labelKey : id)
    }

    function monitorOptions() {
        var out = [{ key: "", label: page.t("bar.editor.global") }]
        var list = page.monitors && page.monitors.monitors ? page.monitors.monitors : []
        for (var i = 0; i < list.length; i++)
            out.push({ key: list[i].name, label: list[i].name })
        return out
    }

    // One patch of the document, on the selected monitor (or globally), as
    // layouts.js writes it; unchanged values write nothing.
    function commit(patch) {
        var text = Layouts.write(page.prefs.barLayout || "", page.monitor, patch)
        if (text !== null)
            page.prefs.barLayout = text
    }

    // Density and fullscreen hiding are one bar, not one monitor.
    function commitGlobal(patch) {
        var text = Layouts.write(page.prefs.barLayout || "", "", patch)
        if (text !== null)
            page.prefs.barLayout = text
    }

    function setVisible(id, visible) {
        if (visible === (page.layout.hidden.indexOf(id) < 0))
            return
        page.commit({ hidden: Layouts.toggle(page.layout.hidden, id) })
    }

    function moveWidget(id, delta) {
        page.commit({ order: Layouts.move(page.layout.order, id, delta) })
    }

    // One patch of the panel's document, as layouts.js writes it; unchanged
    // values write nothing.
    function commitPanel(patch) {
        var text = Layouts.write(page.prefs.panelLayout || "", "", patch, "panel")
        if (text !== null)
            page.prefs.panelLayout = text
    }

    function panelSetting(id) {
        return Layouts.setting(page.panelLayout, id, "panel")
    }

    function setPanelVisible(id, visible) {
        if (visible === (page.panelLayout.hidden.indexOf(id) < 0))
            return
        page.commitPanel({ hidden: Layouts.toggle(page.panelLayout.hidden, id) })
    }

    function setPanelSize(id, size) {
        page.commitPanel({ widgets: Layouts.configure(page.panelLayout.widgets, id, { size: size }, "panel") })
    }

    function setPanelStyle(id, style) {
        page.commitPanel({ widgets: Layouts.configure(page.panelLayout.widgets, id, { style: style }, "panel") })
    }

    // A drag ended on an insertion slot: put the widget there.
    function dropPanelWidget(from, to) {
        if (from < 0 || to < 0)
            return
        page.commitPanel({ order: Layouts.reorder(page.panelLayout.order, from, to) })
    }

    // --- the desktop canvas --------------------------------------------------
    function desktopCommit(widgets) {
        if (page.desktopMonitorName === "")
            return
        var text = Layouts.write(page.prefs.desktopLayout || "", page.desktopMonitorName,
                                 { widgets: widgets }, "desktop")
        if (text !== null)
            page.prefs.desktopLayout = text
    }

    function desktopAddWidget(id) {
        var count = page.desktopDocument.widgets.length
        page.desktopCommit(Layouts.desktopAdd(page.desktopDocument.widgets, id, 0.5,
                                              0.3 + Math.min(0.5, count * 0.08)))
        page.desktopSelection = id
    }

    function desktopRemoveWidget(id) {
        page.desktopCommit(Layouts.desktopRemove(page.desktopDocument.widgets, id))
        if (page.desktopSelection === id)
            page.desktopSelection = ""
    }

    function desktopMoveWidget(id, x, y) {
        page.desktopCommit(Layouts.desktopMove(page.desktopDocument.widgets, id, x, y))
    }

    function desktopSetSize(id, size) {
        page.desktopCommit(Layouts.desktopConfigure(page.desktopDocument.widgets, id,
                                                     { size: size }))
    }

    function desktopSetStyle(id, style) {
        page.desktopCommit(Layouts.desktopConfigure(page.desktopDocument.widgets, id,
                                                     { style: style }))
    }

    function desktopSetFont(id, font) {
        page.desktopCommit(Layouts.desktopConfigure(page.desktopDocument.widgets, id,
                                                     { font: font }))
    }

    function desktopSetWeight(id, weight) {
        page.desktopCommit(Layouts.desktopConfigure(page.desktopDocument.widgets, id,
                                                     { weight: weight }))
    }

    function desktopSetItalic(id, italic) {
        page.desktopCommit(Layouts.desktopConfigure(page.desktopDocument.widgets, id,
                                                     { italic: italic }))
    }

    // The placed entry of one id, or null.
    function desktopEntry(id) {
        var list = page.desktopDocument.widgets
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    // One card or row selects a widget; selecting it again closes the section.
    function selectDesktopWidget(id) {
        page.desktopSelection = page.desktopSelection === id ? "" : id
    }

    function desktopFontOptions() {
        var families = page.fonts && Array.isArray(page.fonts.fonts) ? page.fonts.fonts : []
        return [{ key: "", label: page.t("desktop.editor.font.inherit") }].concat(
            families.map(function (family) {
                return { key: family, label: family }
            }))
    }

    function desktopWeightOptions() {
        return ["", "regular", "medium", "bold"].map(function (weight) {
            return { key: weight,
                     label: page.t("desktop.editor.weight." + (weight === "" ? "inherit" : weight)) }
        })
    }

    function desktopWidget(id) {
        return Layouts.find(id, "desktop")
    }

    function desktopLabel(id) {
        var widget = page.desktopWidget(id)
        return page.t(widget ? widget.labelKey : id)
    }

    function desktopMonitorOptions() {
        return page.desktopOutputs.map(function (output) {
            return { key: output.name, label: output.name }
        })
    }

    function desktopSizeOptions(id) {
        var widget = page.desktopWidget(id)
        return widget ? widget.sizes.map(function (size) {
            return { key: size, label: page.t("panel.editor.size." + size) }
        }) : []
    }

    function desktopStyleOptions(id) {
        var widget = page.desktopWidget(id)
        if (!widget)
            return []
        return [{ key: "", label: page.t("panel.editor.style.default") }].concat(
            widget.styles.map(function (style) {
                return { key: style, label: page.t("panel.editor.style." + style) }
            }))
    }

    readonly property var icons: ({
        edge: { left: "left_panel_open", top: "top_panel_open", right: "right_panel_open", bottom: "bottom_panel_open" },
        style: { docked: "dock_to_bottom", floating: "bottom_navigation", islands: "splitscreen", floatingIslands: "view_agenda" },
        screens: { primary: "monitor", all: "devices" },
        frame: { full: "border_outer", corners: "rounded_corner", none: "border_clear" },
        vertical: { top: "vertical_align_top", bottom: "vertical_align_bottom" },
        visualiser: { bars: "bar_chart", reflection: "flip", panel: "crop_free" },
        group: { start: "first_page", center: "filter_center_focus", end: "last_page" },
        widget: {
            launcher: "apps", notifications: "notifications", media: "play_circle",
            clock: "schedule", capture: "screenshot_monitor", recording: "stop_circle",
            tray: "widgets", network: "lan", bluetooth: "bluetooth", vpn: "shield",
            profile: "speed", battery: "battery_full", keyboard: "keyboard",
            power: "power_settings_new"
        }
    })

    function options(prefix, keys, icons) {
        return keys.map(function (key) {
            return { key: key, icon: icons[key], label: page.t(prefix + key) }
        })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "layout", icon: "toolbar", label: page.t("bar.section.layout") },
                { key: "editor", icon: "tune", label: page.t("bar.tab.editor") },
                { key: "frame", icon: "crop_free", label: page.t("bar.tab.framePanels") },
                { key: "notifications", icon: "notifications", label: page.t("bar.section.notifications") },
                { key: "osd", icon: "tune", label: page.t("bar.section.osd") },
                { key: "widgets", icon: "timer", label: page.t("bar.section.widgets") },
                { key: "background", icon: "graphic_eq", label: page.t("bar.section.background") },
                { key: "capture", icon: "screenshot_monitor", label: page.t("bar.section.capture") }
            ]
            current: page.tab
            foreground: page.palette.foreground
            accent: page.palette.primary
            onSelected: page.tab = key
        }

        Flickable {
            id: scroller

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: column

                width: parent.width
                spacing: VitrailTokens.gap("xl")

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "layout"
                    icon: "toolbar"
                    title: page.t("bar.section.layout")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "dock_to_left"
                        label: page.t("bar.edge")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.edge.", ["left", "top", "right", "bottom"], page.icons.edge)
                            current: page.prefs.barEdge
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.barEdge = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "dock_to_bottom"
                        label: page.t("bar.trayStyle")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.trayStyle.", ["inline", "popup"], ({}))
                            current: page.prefs.trayStyle
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.trayStyle = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "battery_full"
                        label: page.t("bar.batteryChip")
                        description: page.t("bar.batteryChip.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.barBatteryChip === undefined || page.prefs.barBatteryChip === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.barBatteryChip = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "bluetooth"
                        label: page.t("bar.bluetoothChip")
                        description: page.t("bar.bluetoothChip.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.barBluetoothChip === undefined || page.prefs.barBluetoothChip === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.barBluetoothChip = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "keyboard"
                        label: page.t("bar.keyboardChip")
                        description: page.t("bar.keyboardChip.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.barKeyboard === undefined || page.prefs.barKeyboard === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.barKeyboard = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "style"
                        label: page.t("bar.style")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.style.", Object.keys(VitrailVariants.bar), page.icons.style)
                            current: page.prefs.barStyle || VitrailStyle.defaults.bar
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.barStyle = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "desktop_windows"
                        label: page.t("bar.screens")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.screens.", ["primary", "all"], page.icons.screens)
                            current: page.prefs.barScreens
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.barScreens = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "opacity"
                        label: page.t("bar.opacity")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "follow", icon: "sync", label: page.t("bar.opacity.follow") },
                                { key: "own", icon: "tune", label: page.t("bar.opacity.own") }
                            ]
                            current: page.prefs.barOpacityFollow ? "follow" : "own"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.barOpacityFollow = key === "follow"
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        visible: !page.prefs.barOpacityFollow
                        label: page.t("bar.opacity.value")
                        suffix: "%"
                        from: VitrailTokens.ranges.opacity.min * 100
                        to: VitrailTokens.ranges.opacity.max * 100
                        stepSize: VitrailTokens.ranges.opacity.step * 100
                        value: page.prefs.barOpacity * 100
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.barOpacity = value / 100
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.size")
                        suffix: " px"
                        from: VitrailTokens.ranges.bar.min
                        to: VitrailTokens.ranges.bar.max
                        stepSize: VitrailTokens.ranges.bar.step
                        value: page.prefs.barSize
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.barSize = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "editor"
                    icon: "tune"
                    title: page.t("bar.section.editor")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Text {
                        Layout.fillWidth: true
                        text: page.t("bar.editor.help")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    VitrailSettingRow {
                        icon: "layers"
                        label: page.t("bar.editor.surface")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "bar", icon: "toolbar", label: page.t("bar.editor.surface.bar") },
                                { key: "panel", icon: "view_sidebar", label: page.t("bar.editor.surface.panel") },
                                { key: "desktop", icon: "desktop_windows", label: page.t("bar.editor.surface.desktop") }
                            ]
                            current: page.editorSurface
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.editorSurface = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "monitor"
                        label: page.t("bar.editor.monitor")
                        description: page.t("bar.editor.monitor.help")
                        visible: page.editorSurface === "bar"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.monitorOptions()
                            current: page.monitor
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.monitor = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "compress"
                        label: page.t("bar.editor.density")
                        description: page.t("bar.editor.density.help")
                        visible: page.editorSurface === "bar"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "comfortable", icon: "density_medium", label: page.t("bar.editor.density.comfortable") },
                                { key: "compact", icon: "density_small", label: page.t("bar.editor.density.compact") }
                            ]
                            current: page.layout.density
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.commitGlobal({ density: key })
                        }
                    }

                    VitrailSettingRow {
                        icon: "fullscreen"
                        label: page.t("bar.editor.fullscreen")
                        description: page.t("bar.editor.fullscreen.help")
                        visible: page.editorSurface === "bar"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.layout.hideFullscreen
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: page.commitGlobal({ hideFullscreen: value })
                        }
                    }
                }

                // One list per group, in the document's order: show or hide an
                // element, and move it up or down inside its group.
                Repeater {
                    model: Layouts.groups("bar")

                    delegate: Section {
                        id: groupCard

                        required property string modelData

                        Layout.fillWidth: true
                        visible: page.tab === "editor" && page.editorSurface === "bar"
                        icon: page.icons.group[groupCard.modelData] || "widgets"
                        title: page.t("bar.editor.group." + groupCard.modelData)
                        foreground: page.palette.foreground
                        accent: page.palette.primary

                        Repeater {
                            model: page.layout.order[groupCard.modelData] || []

                            delegate: VitrailSettingRow {
                                id: widgetRow

                                required property string modelData
                                required property int index

                                readonly property var ids: page.layout.order[groupCard.modelData] || []

                                Layout.fillWidth: true
                                icon: page.icons.widget[widgetRow.modelData] || "widgets"
                                label: page.labelOf(widgetRow.modelData)
                                foreground: page.palette.foreground
                                muted: page.palette.muted

                                VitrailSwitch {
                                    checked: page.layout.hidden.indexOf(widgetRow.modelData) < 0
                                    foreground: page.palette.foreground
                                    accent: page.palette.primary
                                    onToggled: page.setVisible(widgetRow.modelData, value)
                                }

                                VitrailButton {
                                    variant: "text"
                                    icon: "arrow_upward"
                                    onClicked: if (widgetRow.index > 0)
                                                   page.moveWidget(widgetRow.modelData, -1)
                                }

                                VitrailButton {
                                    variant: "text"
                                    icon: "arrow_downward"
                                    onClicked: if (widgetRow.index < widgetRow.ids.length - 1)
                                                   page.moveWidget(widgetRow.modelData, 1)
                                }
                            }
                        }
                    }
                }

                // The panel's widgets: one card each, in the document's order.
                // Drag a card by its handle to reorder it (the line marks the
                // insertion point); the switch hides it.
                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "editor" && page.editorSurface === "panel"
                    icon: "view_sidebar"
                    title: page.t("panel.editor.title")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Text {
                        Layout.fillWidth: true
                        text: page.t("panel.editor.help")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: page.panelLayout.order

                        delegate: Item {
                            id: cardItem

                            required property string modelData
                            required property int index

                            readonly property var meta: Layouts.find(cardItem.modelData, "panel")
                            readonly property var setting: page.panelSetting(cardItem.modelData)
                            readonly property bool shown: page.panelLayout.hidden.indexOf(cardItem.modelData) < 0

                            objectName: "panelEditorCard"
                            Layout.fillWidth: true
                            Layout.preferredHeight: card.height
                            opacity: handleDrag.active ? 0.6 : (cardItem.shown ? 1 : 0.5)

                            Behavior on opacity {
                                NumberAnimation { duration: VitrailTokens.duration("fast") }
                            }

                            Drag.active: handleDrag.active
                            Drag.source: cardItem
                            Drag.dragType: Drag.Internal
                            Drag.hotSpot: Qt.point(cardItem.width / 2, cardItem.height / 2)

                            VitrailSurface {
                                id: card

                                width: parent.width
                                height: content.implicitHeight + 2 * VitrailTokens.gap("md")
                                tint: page.palette.surfaceHigh
                                radius: VitrailTokens.radius * 0.85

                                ColumnLayout {
                                    id: content

                                    anchors.fill: parent
                                    anchors.margins: VitrailTokens.gap("md")
                                    spacing: VitrailTokens.gap("sm")

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: VitrailTokens.gap("sm")

                                        Item {
                                            id: handle

                                            implicitWidth: 24
                                            implicitHeight: 24

                                            VitrailIcon {
                                                anchors.centerIn: parent
                                                icon: "drag_indicator"
                                                size: "sm"
                                                tone: "secondary"
                                            }

                                            HoverHandler {
                                                cursorShape: handleDrag.active ? Qt.ClosedHandCursor
                                                                               : Qt.OpenHandCursor
                                            }

                                            DragHandler {
                                                id: handleDrag

                                                target: null
                                                onActiveChanged: {
                                                    if (active) {
                                                        page.panelDragFrom = cardItem.index
                                                        page.panelDropIndex = cardItem.index
                                                    } else {
                                                        page.panelDropIndex = -1
                                                    }
                                                }
                                            }
                                        }

                                        VitrailIcon {
                                            icon: cardItem.meta ? cardItem.meta.icon : "widgets"
                                            size: "sm"
                                            tone: "secondary"
                                        }

                                        VitrailText {
                                            Layout.fillWidth: true
                                            variant: "body"
                                            elide: Text.ElideRight
                                            text: page.t(cardItem.meta ? cardItem.meta.labelKey
                                                                       : cardItem.modelData)
                                        }

                                        VitrailSwitch {
                                            checked: cardItem.shown
                                            foreground: page.palette.foreground
                                            accent: page.palette.primary
                                            onToggled: page.setPanelVisible(cardItem.modelData, value)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: VitrailTokens.gap("sm")
                                        visible: cardItem.meta
                                                 && (cardItem.meta.sizes.length > 1
                                                     || cardItem.meta.styles.length > 0)

                                        VitrailText {
                                            variant: "label"
                                            text: page.t("panel.editor.size")
                                            visible: cardItem.meta && cardItem.meta.sizes.length > 0
                                        }

                                        VitrailSegmented {
                                            visible: cardItem.meta && cardItem.meta.sizes.length > 0
                                            options: cardItem.meta ? cardItem.meta.sizes.map(function (size) {
                                                return { key: size,
                                                         label: page.t("panel.editor.size." + size) }
                                            }) : []
                                            current: cardItem.setting.size
                                            foreground: page.palette.foreground
                                            accent: page.palette.primary
                                            onSelected: page.setPanelSize(cardItem.modelData, key)
                                        }

                                        VitrailText {
                                            variant: "label"
                                            text: page.t("panel.editor.style")
                                            visible: cardItem.meta && cardItem.meta.styles.length > 0
                                        }

                                        VitrailSegmented {
                                            visible: cardItem.meta && cardItem.meta.styles.length > 0
                                            options: cardItem.meta ? [{ key: "",
                                                                        label: page.t("panel.editor.style.default") }]
                                                .concat(cardItem.meta.styles.map(function (style) {
                                                    return { key: style,
                                                             label: page.t("panel.editor.style." + style) }
                                                })) : []
                                            current: cardItem.setting.style
                                            foreground: page.palette.foreground
                                            accent: page.palette.primary
                                            onSelected: page.setPanelStyle(cardItem.modelData, key)
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            // Where the dragged card would land: above this one,
                            // or below the last one when it goes to the end.
                            VitrailSurface {
                                objectName: "panelEditorDropLine"

                                visible: page.panelDragFrom >= 0
                                         && page.panelDropIndex === cardItem.index
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }
                                height: 2
                                radius: 1
                                tint: page.palette.primary
                                opacityLevel: 1
                                z: 2

                                Behavior on opacity {
                                    NumberAnimation { duration: VitrailTokens.duration("fast") }
                                }
                            }

                            VitrailSurface {
                                visible: page.panelDragFrom >= 0
                                         && cardItem.index === page.panelLayout.order.length - 1
                                         && page.panelDropIndex === page.panelLayout.order.length
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 2
                                radius: 1
                                tint: page.palette.primary
                                opacityLevel: 1
                                z: 2
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: function (drag) {
                                    page.panelDropIndex = cardItem.index
                                                          + (drag.y > cardItem.height / 2 ? 1 : 0)
                                }
                                onPositionChanged: function (drag) {
                                    page.panelDropIndex = cardItem.index
                                                          + (drag.y > cardItem.height / 2 ? 1 : 0)
                                }
                                onDropped: page.dropPanelWidget(page.panelDragFrom, page.panelDropIndex)
                            }
                        }
                    }
                }

                // The desktop: a canvas of the selected monitor. Cards show
                // where each widget sits; drag one to move it, and the rows
                // below set its size, style or removal.
                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "editor" && page.editorSurface === "desktop"
                    icon: "desktop_windows"
                    title: page.t("desktop.editor.title")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Text {
                        Layout.fillWidth: true
                        text: page.t("desktop.editor.help")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    VitrailSettingRow {
                        icon: "monitor"
                        label: page.t("desktop.editor.monitor")
                        description: page.t("desktop.editor.monitor.help")
                        visible: page.desktopOutputs.length > 0
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.desktopMonitorOptions()
                            current: page.desktopMonitorName
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.desktopMonitor = key
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: page.desktopAvailable.length > 0
                        spacing: VitrailTokens.gap("xs")

                        Text {
                            text: page.t("desktop.editor.add")
                            color: page.palette.muted
                            font.pixelSize: 12
                            font.family: VitrailTokens.fontFamily
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("xs")

                            Repeater {
                                model: page.desktopAvailable

                                delegate: VitrailButton {
                                    required property var modelData

                                    variant: "outlined"
                                    tone: "secondary"
                                    size: "sm"
                                    icon: modelData.icon
                                    text: page.t(modelData.labelKey)
                                    onClicked: page.desktopAddWidget(modelData.id)
                                }
                            }
                        }
                    }

                    VitrailSurface {
                        id: canvas

                        objectName: "desktopEditorCanvas"
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(300, canvas.width / page.desktopAspect)
                        tint: page.palette.surface
                        radius: VitrailTokens.radius

                        Item {
                            id: canvasArea

                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: page.desktopDocument.widgets.length === 0
                                spacing: VitrailTokens.gap("xs")

                                VitrailIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    icon: "desktop_windows"
                                    size: "xl"
                                    tone: "muted"
                                }

                                VitrailText {
                                    Layout.alignment: Qt.AlignHCenter
                                    variant: "content"
                                    text: page.t("desktop.editor.empty")
                                }
                            }

                            Repeater {
                                model: page.desktopDocument.widgets

                                delegate: Item {
                                    id: placed

                                    required property var modelData
                                    required property int index

                                    readonly property var meta: page.desktopWidget(placed.modelData.id)
                                    readonly property real naturalWidth: Widgets.widthOf(placed.modelData.id,
                                                                                         placed.modelData.size)
                                    readonly property real canvasScale: page.desktopOutput
                                                                        && page.desktopOutput.width > 0
                                                                        ? canvasArea.width
                                                                          / page.desktopOutput.width : 0.3
                                    readonly property real cardWidth: Math.max(56,
                                                                                placed.naturalWidth
                                                                                * placed.canvasScale)
                                    readonly property real cardHeight: 40

                                    objectName: "desktopEditorWidget"
                                    width: Math.min(placed.cardWidth,
                                                    Math.max(56, canvasArea.width - placed.x))
                                    height: placed.cardHeight
                                    z: grab.active ? 1 : 0

                                    Binding on x {
                                        when: !grab.active
                                        value: placed.modelData.x * canvasArea.width
                                    }
                                    Binding on y {
                                        when: !grab.active
                                        value: placed.modelData.y * canvasArea.height
                                    }

                                    Behavior on x {
                                        enabled: !grab.active
                                        NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
                                    }
                                    Behavior on y {
                                        enabled: !grab.active
                                        NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
                                    }

                                    VitrailSurface {
                                        anchors.fill: parent
                                        tint: grab.active ? page.palette.primary : page.palette.surfaceHigh
                                        radius: VitrailTokens.radius * 0.75

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: VitrailTokens.gap("xs")
                                            spacing: VitrailTokens.gap("xs")

                                            VitrailIcon {
                                                icon: placed.meta ? placed.meta.icon : "widgets"
                                                size: "sm"
                                                tone: "secondary"
                                            }

                                            VitrailText {
                                                Layout.fillWidth: true
                                                variant: "label"
                                                elide: Text.ElideRight
                                                text: page.desktopLabel(placed.modelData.id)
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        cursorShape: grab.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    }

                                    TapHandler {
                                        onTapped: page.selectDesktopWidget(placed.modelData.id)
                                    }

                                    DragHandler {
                                        id: grab

                                        target: placed
                                        xAxis.minimum: 0
                                        xAxis.maximum: Math.max(0, canvasArea.width - placed.width)
                                        yAxis.minimum: 0
                                        yAxis.maximum: Math.max(0, canvasArea.height - placed.height)
                                        onActiveChanged: if (!grab.active)
                                                             page.desktopMoveWidget(placed.modelData.id,
                                                                                    placed.x / canvasArea.width,
                                                                                    placed.y / canvasArea.height)
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: page.desktopDocument.widgets

                        delegate: VitrailSettingRow {
                            id: desktopRow

                            required property var modelData

                            readonly property var meta: page.desktopWidget(desktopRow.modelData.id)

                            Layout.fillWidth: true
                            icon: desktopRow.meta ? desktopRow.meta.icon : "widgets"
                            label: page.desktopLabel(desktopRow.modelData.id)
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSegmented {
                                options: page.desktopSizeOptions(desktopRow.modelData.id)
                                current: desktopRow.modelData.size
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onSelected: page.desktopSetSize(desktopRow.modelData.id, key)
                            }

                            VitrailSegmented {
                                visible: desktopRow.meta && desktopRow.meta.styles.length > 0
                                options: page.desktopStyleOptions(desktopRow.modelData.id)
                                current: desktopRow.modelData.style
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onSelected: page.desktopSetStyle(desktopRow.modelData.id, key)
                            }

                            VitrailButton {
                                variant: "text"
                                tone: page.desktopSelection === desktopRow.modelData.id
                                      ? "primary" : "secondary"
                                icon: "text_fields"
                                onClicked: page.selectDesktopWidget(desktopRow.modelData.id)
                            }

                            VitrailButton {
                                variant: "text"
                                tone: "secondary"
                                icon: "delete"
                                onClicked: page.desktopRemoveWidget(desktopRow.modelData.id)
                            }
                        }
                    }
                }

                // The selected widget's own typography. Empty values are
                // the widget's variant; a family is a name from the shell's
                // font list.
                Section {
                    objectName: "desktopTypography"
                    Layout.fillWidth: true
                    visible: page.tab === "editor" && page.editorSurface === "desktop"
                             && page.desktopSelectedEntry !== null
                    icon: "text_fields"
                    title: page.t("desktop.editor.typography")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Text {
                        Layout.fillWidth: true
                        text: page.t("desktop.editor.typography.help")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    VitrailSettingRow {
                        icon: "font_download"
                        label: page.t("desktop.editor.font")
                        description: page.t("desktop.editor.font.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "desktopFontPicker"
                            Layout.preferredWidth: 320
                            label: page.t("desktop.editor.font")
                            searchHint: page.t("desktop.editor.font.search")
                            current: page.desktopSelectedEntry
                                     ? page.desktopSelectedEntry.font : ""
                            options: page.desktopFontOptions()
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: function (key) {
                                page.desktopSetFont(page.desktopSelection, key)
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "format_bold"
                        label: page.t("desktop.editor.weight")
                        description: page.t("desktop.editor.weight.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            objectName: "desktopWeightPicker"
                            options: page.desktopWeightOptions()
                            current: page.desktopSelectedEntry
                                     ? page.desktopSelectedEntry.weight : ""
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: function (key) {
                                page.desktopSetWeight(page.desktopSelection, key)
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "format_italic"
                        label: page.t("desktop.editor.italic")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "desktopItalicSwitch"
                            checked: page.desktopSelectedEntry
                                     ? page.desktopSelectedEntry.italic : false
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.desktopSetItalic(page.desktopSelection, value)
                            }
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "subtitle"
                        family: page.desktopSelectedEntry ? page.desktopSelectedEntry.font : ""
                        fontWeight: page.desktopSelectedEntry
                                    ? page.desktopSelectedEntry.weight : ""
                        italic: page.desktopSelectedEntry
                                ? page.desktopSelectedEntry.italic : false
                        text: page.t("desktop.editor.typography.preview")
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "frame"
                    icon: "crop_free"
                    title: page.t("bar.frame")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "rounded_corner"
                        label: page.t("bar.frame")
                        description: page.t("bar.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.frame.", Object.keys(VitrailVariants.frame), page.icons.frame)
                            current: page.prefs.frameStyle || VitrailStyle.defaults.frame
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.frameStyle = key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.frameSize")
                        suffix: " px"
                        from: VitrailTokens.ranges.frame.min
                        to: VitrailTokens.ranges.frame.max
                        stepSize: VitrailTokens.ranges.frame.step
                        value: page.prefs.frameSize
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.frameSize = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "frame"
                    icon: "view_sidebar"
                    title: page.t("bar.section.panels")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "open_in_full"
                        label: page.t("bar.panelPush")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.panelPush
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.panelPush = value
                            }
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.panelSize")
                        suffix: " px"
                        from: VitrailTokens.ranges.panel.min
                        to: VitrailTokens.ranges.panel.max
                        stepSize: VitrailTokens.ranges.panel.step
                        value: page.prefs.panelSize
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.panelSize = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "notifications"
                    icon: "notifications"
                    title: page.t("bar.section.notifications")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    // "top-right" and friends: one segment picks the edge, the
                    // other where along it.
                    VitrailSettingRow {
                        icon: "vertical_align_center"
                        label: page.t("bar.notifications")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.edge.", ["top", "bottom"], page.icons.vertical)
                            current: page.prefs.notificationPosition.split("-")[0]
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.notificationPosition = key + "-" + page.prefs.notificationPosition.split("-")[1]
                        }

                        VitrailSegmented {
                            options: [
                                { key: "left", icon: "align_horizontal_left", label: page.t("bar.edge.left") },
                                { key: "center", icon: "align_horizontal_center", label: page.t("bar.notifications.center") },
                                { key: "right", icon: "align_horizontal_right", label: page.t("bar.edge.right") }
                            ]
                            current: page.prefs.notificationPosition.split("-")[1]
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.notificationPosition = page.prefs.notificationPosition.split("-")[0] + "-" + key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.notifications.max")
                        from: VitrailTokens.ranges.notifications.min
                        to: VitrailTokens.ranges.notifications.max
                        stepSize: VitrailTokens.ranges.notifications.step
                        value: page.prefs.notificationMax
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.notificationMax = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "notifications"
                    icon: "notifications_active"
                    title: page.t("bar.notifications.behaviour")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "snooze"
                        label: page.t("bar.notifications.snooze")
                        description: page.t("bar.notifications.snooze.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.notificationSnooze === undefined || page.prefs.notificationSnooze === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.notificationSnooze = value }
                        }
                    }

                    VitrailField {
                        id: mutedField

                        Layout.fillWidth: true
                        size: "sm"
                        label: page.t("bar.notifications.muted")
                        supportingText: page.t("bar.notifications.muted.help")
                        text: page.prefs.notificationMuted || ""
                        onTextChanged: if (mutedField.text !== (page.prefs.notificationMuted || ""))
                                            page.prefs.notificationMuted = mutedField.text
                    }

                    VitrailField {
                        id: urgentField

                        Layout.fillWidth: true
                        size: "sm"
                        label: page.t("bar.notifications.urgent")
                        supportingText: page.t("bar.notifications.urgent.help")
                        text: page.prefs.notificationUrgentApps || ""
                        onTextChanged: if (urgentField.text !== (page.prefs.notificationUrgentApps || ""))
                                            page.prefs.notificationUrgentApps = urgentField.text
                    }

                    VitrailSettingRow {
                        icon: "priority_high"
                        label: page.t("bar.notifications.urgentBypass")
                        description: page.t("bar.notifications.urgentBypass.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.notificationUrgentBypass === undefined
                                     || page.prefs.notificationUrgentBypass === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.notificationUrgentBypass = value }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "capture"
                    icon: "screenshot_monitor"
                    title: page.t("bar.section.capture")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailField {
                        Layout.fillWidth: true
                        label: page.t("bar.capture.dir")
                        placeholder: page.t("bar.capture.dirHelp")
                        text: page.prefs.captureDir
                        onTextChanged: page.prefs.captureDir = text
                    }

                    VitrailSettingRow {
                        icon: "content_copy"
                        label: page.t("bar.capture.copy")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureCopy
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureCopy = value }
                        }
                    }

                    VitrailField {
                        Layout.fillWidth: true
                        label: page.t("bar.capture.recordDir")
                        placeholder: page.t("bar.capture.dirHelp")
                        text: page.prefs.captureRecordDir
                        onTextChanged: page.prefs.captureRecordDir = text
                    }

                    VitrailSettingRow {
                        icon: "edit"
                        label: page.t("bar.capture.annotate")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureAnnotate
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureAnnotate = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "crop_free"
                        label: page.t("bar.capture.recordRegion")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureRecordRegion
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureRecordRegion = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "mic"
                        label: page.t("bar.capture.audio")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureRecordAudio
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureRecordAudio = value }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "osd"
                    icon: "tune"
                    title: page.t("bar.section.osd")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "keyboard"
                        label: page.t("bar.osd.keys")
                        description: page.t("bar.osd.keys.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.osdKeys === undefined || page.prefs.osdKeys === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.osdKeys = value }
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.osd.keyTime")
                        suffix: " ms"
                        from: VitrailTokens.ranges.osdKey.min
                        to: VitrailTokens.ranges.osdKey.max
                        stepSize: VitrailTokens.ranges.osdKey.step
                        value: page.prefs.osdKeyTime
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.osdKeyTime = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.osd.hotZone")
                        suffix: " px"
                        from: VitrailTokens.ranges.osdHot.min
                        to: VitrailTokens.ranges.osdHot.max
                        stepSize: VitrailTokens.ranges.osdHot.step
                        value: page.prefs.osdHotZone
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.osdHotZone = value
                    }

                    VitrailSettingRow {
                        icon: "aspect_ratio"
                        label: page.t("bar.osd.size")
                        description: page.t("bar.osd.size.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "sm", label: page.t("bar.osd.size.sm") },
                                { key: "md", label: page.t("bar.osd.size.md") },
                                { key: "lg", label: page.t("bar.osd.size.lg") }
                            ]
                            current: page.prefs.osdSize || VitrailTokens.osd.size
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.osdSize = key
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "capture"
                    icon: "screenshot_monitor"
                    title: page.t("bar.section.capture")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailField {
                        Layout.fillWidth: true
                        label: page.t("bar.capture.dir")
                        placeholder: page.t("bar.capture.dirHelp")
                        text: page.prefs.captureDir
                        onTextChanged: page.prefs.captureDir = text
                    }

                    VitrailSettingRow {
                        icon: "content_copy"
                        label: page.t("bar.capture.copy")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureCopy
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureCopy = value }
                        }
                    }

                    VitrailField {
                        Layout.fillWidth: true
                        label: page.t("bar.capture.recordDir")
                        placeholder: page.t("bar.capture.dirHelp")
                        text: page.prefs.captureRecordDir
                        onTextChanged: page.prefs.captureRecordDir = text
                    }

                    VitrailSettingRow {
                        icon: "edit"
                        label: page.t("bar.capture.annotate")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureAnnotate
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureAnnotate = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "crop_free"
                        label: page.t("bar.capture.recordRegion")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureRecordRegion
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureRecordRegion = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "mic"
                        label: page.t("bar.capture.audio")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.captureRecordAudio
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.captureRecordAudio = value }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "widgets"
                    icon: "timer"
                    title: page.t("bar.section.widgets")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.widgets.pomodoroWork")
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
                        Layout.fillWidth: true
                        label: page.t("bar.widgets.pomodoroRest")
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
                        Layout.fillWidth: true
                        label: page.t("bar.widgets.pomodoroCycles")
                        from: VitrailTokens.ranges.pomodoroCycles.min
                        to: VitrailTokens.ranges.pomodoroCycles.max
                        stepSize: VitrailTokens.ranges.pomodoroCycles.step
                        value: page.prefs.pomodoroCycles
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.pomodoroCycles = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.widgets.timerMinutes")
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

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "background"
                    icon: "graphic_eq"
                    title: page.t("bar.section.background")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "graphic_eq"
                        label: page.t("bar.visualiser.enabled")
                        description: page.t("bar.visualiser.enabled.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.visualiserEnabled
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.visualiserEnabled = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "bar_chart"
                        label: page.t("bar.visualiser.variant")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: page.options("bar.visualiser.variant.",
                                                  Object.keys(VitrailVariants.visualiser),
                                                  page.icons.visualiser)
                            current: page.prefs.visualiserVariant || VitrailStyle.defaults.visualiser
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.visualiserVariant = key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.visualiser.height")
                        suffix: " px"
                        from: VitrailTokens.ranges.visualiserHeight.min
                        to: VitrailTokens.ranges.visualiserHeight.max
                        stepSize: VitrailTokens.ranges.visualiserHeight.step
                        value: page.prefs.visualiserHeight
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.visualiserHeight = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "osd"
                    icon: "speed"
                    title: page.t("bar.osd.steps")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.osd.step")
                        suffix: "%"
                        from: VitrailTokens.ranges.osdStep.min
                        to: VitrailTokens.ranges.osdStep.max
                        stepSize: VitrailTokens.ranges.osdStep.step
                        value: page.prefs.osdStep
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.osdStep = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("bar.osd.brightnessStep")
                        suffix: "%"
                        from: VitrailTokens.ranges.osdBrightnessStep.min
                        to: VitrailTokens.ranges.osdBrightnessStep.max
                        stepSize: VitrailTokens.ranges.osdBrightnessStep.step
                        value: page.prefs.osdBrightnessStep
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.osdBrightnessStep = value
                    }
                }
            }
        }
    }
}
