import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../layouts.js" as Layouts
import "../barview.js" as BarView
import "../dragdrop.js" as DragDrop
import "../elements.js" as Elements

// The bar tab of the in-place editor. It holds everything that used to live in
// Settings → Bar: the bar's own look (edge, tray style, chips, style, screens,
// opacity and size) and the placement of its elements — one list per group,
// with visibility, order, a group selector, chips and dividers, plus density,
// fullscreen hiding and the per-monitor override. The placements that may
// differ per monitor (the bar and OSD edges) are written to `barMonitors` for
// the screen this editor sits on; every other option stays global.
//
// Rows reorder by dragging: a grip starts the drag, the preview strip at the
// top draws the document the drop would write, an insertion line marks the
// gap and a refused target says why. The group selectors and arrows stay as
// the keyboard alternative. The document is still the only state: the drop is
// one whole `barLayout` write, emitted as `committed`, and the parent keeps
// the text and persists it.
Item {
    id: root

    property var strings: ({})
    // The bar preferences Settings no longer edits (`bar.ini`).
    property var bar: ({ edge: "left", trayStyle: "inline", batteryChip: true,
                         bluetoothChip: true, keyboard: true, style: "",
                         screens: "primary", opacityFollow: true,
                         dragReorder: true,
                         opacity: VitrailTokens.ranges.opacity.value,
                         size: VitrailTokens.ranges.bar.value })
    // The outputs the monitor override can name: [{ name }].
    property var monitors: []
    // The whole bar document and the monitor being edited ("" is global).
    property string layoutText: ""
    property string monitor: ""
    // The bar's per-monitor placements (bar.ini `barMonitors`) and the output
    // whose placement the "on this monitor" selectors write.
    property string positions: ""
    property string screenMonitor: ""

    signal committed(string text)
    signal prefChanged(string key, var value)
    signal positionsEdited(string text)

    readonly property var doc: Layouts.effective(root.layoutText, root.monitor, null, "bar")
    readonly property string positionMonitor: root.screenMonitor !== "" ? root.screenMonitor : root.monitor
    readonly property var positionDoc: BarView.document(root.positions)
    readonly property var positionEntry: root.positionMonitor !== ""
                                               ? BarView.override(root.positionDoc, root.positionMonitor) : null
    readonly property string edgeOverride: root.positionEntry
                                           && typeof root.positionEntry.edge === "string"
                                           ? root.positionEntry.edge : ""
    readonly property string osdEdgeOverride: root.positionEntry
                                              && typeof root.positionEntry.osdEdge === "string"
                                              ? root.positionEntry.osdEdge : ""
    readonly property string edge: root.bar.edge || "left"
    readonly property string trayStyle: root.bar.trayStyle || "inline"
    readonly property string style: root.bar.style || ""
    readonly property string screens: root.bar.screens || "primary"
    readonly property bool opacityFollow: root.bar.opacityFollow !== false
    // Drag handles: the rows reorder by dragging while this is on; the group
    // selectors and arrows below stay as the keyboard alternative.
    readonly property bool dragReorder: root.bar.dragReorder !== false
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
        group: { start: "first_page", center: "filter_center_focus", end: "last_page" }
    })
    // What the bar on this monitor looks like: the global edge and style with
    // this output's override, for the preview strip.
    readonly property var placement: BarView.forMonitor(root.positions, root.positionMonitor,
                                                         { edge: root.edge, style: root.style })

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

    // The placements that may differ per output. Only this monitor's entry is
    // written; the rest of the document (and the global bar) stays untouched.
    function positionOptions() {
        return [
            { key: "", icon: "public", label: root.t("bar.monitors.edge.global") },
            { key: "left", icon: root.icons.edge.left, label: root.t("bar.edge.left") },
            { key: "top", icon: root.icons.edge.top, label: root.t("bar.edge.top") },
            { key: "right", icon: root.icons.edge.right, label: root.t("bar.edge.right") },
            { key: "bottom", icon: root.icons.edge.bottom, label: root.t("bar.edge.bottom") }
        ]
    }

    function setPosition(field, key) {
        if (root.positionMonitor === "")
            return
        var patch = {}
        patch[field] = key
        var text = BarView.update(root.positions || "{}", root.positionMonitor, patch)
        if (text !== null)
            root.positionsEdited(text)
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
        return Elements.icon(entry)
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

    // --- dragging -------------------------------------------------------------

    // The row being dragged, the checked target under the pointer and the line
    // that marks it. The document is not written until the drop: `previewDoc`
    // is what the strip at the top draws while the pointer moves.
    property string dragId: ""
    property var dragTarget: null
    property bool dragInvalid: false
    // { x, y, width } of the insertion line, in this tab's coordinates.
    property var dragLine: null
    property var dragPoint: ({ x: 0, y: 0 })
    // The drop areas the row delegates announce themselves to. The smallest
    // one under the pointer wins, so a chip member beats its chip body and its
    // whole card.
    property var zones: []

    readonly property bool dragging: root.dragId !== ""
    readonly property var previewDoc: {
        if (root.dragging && root.dragTarget !== null) {
            var preview = DragDrop.preview(root.doc, root.dragId, root.dragTarget)
            if (preview !== null)
                return preview
        }
        return root.doc
    }

    function registerZone(item, spec) {
        var next = root.zones.slice()
        next.push({ item: item, spec: spec })
        root.zones = next
    }

    function unregisterZone(item) {
        root.zones = root.zones.filter(function (zone) {
            return zone.item !== item
        })
    }

    // The drop area under a point, with the gap of that area the pointer marks.
    function zoneAt(point) {
        var best = null
        var local = null
        var area = 0
        for (var i = 0; i < root.zones.length; i++) {
            var zone = root.zones[i]
            var item = zone.item
            if (!item || !item.visible)
                continue
            var at = item.mapFromItem(root, point.x, point.y)
            if (at.x < 0 || at.y < 0 || at.x > item.width || at.y > item.height)
                continue
            var size = item.width * item.height
            if (best !== null && size >= area)
                continue
            best = zone
            local = at
            area = size
        }
        if (best === null)
            return null
        var spec = best.spec
        var base = spec.base === undefined ? 0 : spec.base
        return {
            item: best.item,
            base: base,
            atEnd: spec.atEnd === true,
            target: {
                kind: spec.kind,
                group: spec.group,
                chip: spec.chip,
                index: spec.atEnd ? base
                                  : base + DragDrop.insertion(0, local.y, best.item.height)
            }
        }
    }

    function startDrag(id) {
        if (!root.dragReorder)
            return
        root.dragId = id
        root.dragTarget = null
        root.dragInvalid = false
        root.dragLine = null
    }

    // Check a drop target without the pointer (the drag surface calls it, and
    // the tests drive a whole drag through it).
    function hoverTarget(raw) {
        if (!root.dragging)
            return null
        var checked = DragDrop.target(root.doc, root.dragId, raw)
        root.dragTarget = checked !== null && checked.valid ? checked : null
        root.dragInvalid = checked !== null && !checked.valid
        return checked
    }

    // The pointer moved: find its zone, check the target, place the line.
    function pointAt(sceneX, sceneY) {
        if (!root.dragging)
            return
        var point = root.mapFromItem(null, sceneX, sceneY)
        root.dragPoint = point
        var hit = root.zoneAt(point)
        if (hit === null) {
            root.dragTarget = null
            root.dragInvalid = false
            root.dragLine = null
            return
        }
        var checked = DragDrop.target(root.doc, root.dragId, hit.target)
        if (checked === null || !checked.valid) {
            root.dragTarget = null
            root.dragInvalid = checked !== null
            root.dragLine = null
            return
        }
        root.dragTarget = checked
        root.dragInvalid = false
        var origin = hit.item.mapToItem(root, 0, 0)
        var offset = hit.atEnd ? hit.item.height
                               : (checked.index > hit.base ? hit.item.height : 0)
        root.dragLine = { x: origin.x, y: origin.y + offset, width: hit.item.width }
    }

    // Let go: write the previewed document. A release without a target leaves
    // the document as it was.
    function finishDrag() {
        var id = root.dragId
        var place = root.dragTarget
        root.cancelDrag()
        if (id === "" || place === null)
            return false
        var result = DragDrop.apply(root.doc, id, place)
        if (result === null)
            return false
        root.commit({ order: result.order, chips: result.chips })
        return true
    }

    function cancelDrag() {
        root.dragId = ""
        root.dragTarget = null
        root.dragInvalid = false
        root.dragLine = null
    }

    ColumnLayout {
        id: page

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        // --- the live preview -------------------------------------------
        // Only the strip, on the panel's own surface: no card behind it.
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                variant: "subtitle"
                text: root.t("bar.editor.preview")
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "label"
                elide: Text.ElideRight
                text: preview.anyHidden ? root.t("bar.editor.preview.hidden")
                                        : root.t("bar.editor.preview.help")
            }
        }

        // The strip sits on the side of the list the bar sits on the screen:
        // above it for a top bar, under it for a bottom bar, beside it for a
        // side bar.
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            rowSpacing: VitrailTokens.gap("md")
            columnSpacing: VitrailTokens.gap("md")

            BarPreview {
                id: preview

                objectName: "editorBarPreview"

                Layout.row: root.placement.edge === "bottom" ? 1 : 0
                Layout.column: root.placement.edge === "right" ? 1 : 0
                Layout.fillWidth: !preview.vertical
                Layout.fillHeight: preview.vertical
                doc: root.previewDoc
                strings: root.strings
                target: root.dragTarget
                edge: root.placement.edge
                variant: root.placement.style
                opacityLevel: root.opacityFollow ? VitrailTokens.opacity : root.barOpacityValue
            }

        Flickable {
            id: scroller

            objectName: "editorBarScroller"

            Layout.row: root.placement.edge === "top" ? 1 : 0
            Layout.column: root.placement.edge === "left" ? 1 : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            // A drag owns the pointer; scrolling would move the row under it.
            interactive: !root.dragging

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
                        icon: "monitor"
                        label: root.t("bar.editor.position")
                        description: root.t("bar.editor.position.help")

                        VitrailSegmented {
                            objectName: "editorBarPosition"

                            options: root.positionOptions()
                            current: root.edgeOverride
                            onSelected: root.setPosition("edge", key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "aspect_ratio"
                        label: root.t("bar.editor.osdPosition")

                        VitrailSegmented {
                            objectName: "editorBarOsdEdge"

                            options: root.positionOptions()
                            current: root.osdEdgeOverride
                            onSelected: root.setPosition("osdEdge", key)
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
                        icon: "drag_indicator"
                        label: root.t("bar.editor.drag")
                        description: root.t("bar.editor.drag.help")

                        VitrailSwitch {
                            objectName: "editorBarDragReorder"

                            checked: root.dragReorder
                            onToggled: root.prefChanged("barDragReorder", value)
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

                        // The card itself catches the pointer between the rows
                        // and on the Add buttons: a drop there goes last.
                        Component.onCompleted: root.registerZone(groupColumn, {
                            kind: "group",
                            group: groupCard.modelData,
                            base: (root.doc.order[groupCard.modelData] || []).length,
                            atEnd: true
                        })
                        Component.onDestruction: root.unregisterZone(groupColumn)

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

                                // One row, one drop area: its top half inserts
                                // before it and its bottom half after it.
                                Component.onCompleted: root.registerZone(widgetRow, {
                                    kind: "group",
                                    group: groupCard.modelData,
                                    base: widgetRow.index,
                                    atEnd: false
                                })
                                Component.onDestruction: root.unregisterZone(widgetRow)

                                VitrailSettingRow {
                                    Layout.fillWidth: true
                                    icon: root.entryIcon(widgetRow.entry)
                                    label: root.entryLabel(widgetRow.entry)
                                    description: root.entryDescription(widgetRow.entry)

                                    BarDragHandle {
                                        objectName: "editorBarDrag-" + widgetRow.entry

                                        Layout.alignment: Qt.AlignTop
                                        enabled: root.dragReorder
                                        visible: root.dragReorder
                                        onStarted: root.startDrag(widgetRow.entry)
                                        onMoved: function (sceneX, sceneY) {
                                            root.pointAt(sceneX, sceneY)
                                        }
                                        onFinished: root.finishDrag()
                                    }

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

                                // The members and the "add a member" buttons:
                                // the chip's own drop area. Dropping here puts
                                // the row at the end of the chip; dropping on
                                // a member row puts it at that gap.
                                ColumnLayout {
                                    id: chipBody

                                    Layout.fillWidth: true
                                    spacing: VitrailTokens.gap("xs")
                                    visible: widgetRow.chipEntry

                                    Component.onCompleted: {
                                        if (widgetRow.chipEntry)
                                            root.registerZone(chipBody, {
                                                kind: "chip",
                                                chip: widgetRow.chipId,
                                                base: root.chipMembers(widgetRow.chipId).length,
                                                atEnd: true
                                            })
                                    }
                                    Component.onDestruction: root.unregisterZone(chipBody)

                                    Repeater {
                                        model: widgetRow.chipEntry
                                               ? root.chipMembers(widgetRow.chipId) : []

                                        delegate: VitrailSettingRow {
                                            id: memberRow

                                            required property string modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            Layout.leftMargin: VitrailTokens.gap("lg")
                                            icon: root.entryIcon(memberRow.modelData)
                                            label: root.labelOf(memberRow.modelData)

                                            Component.onCompleted: root.registerZone(memberRow, {
                                                kind: "chip",
                                                chip: widgetRow.chipId,
                                                base: memberRow.index,
                                                atEnd: false
                                            })
                                            Component.onDestruction: root.unregisterZone(memberRow)

                                            BarDragHandle {
                                                objectName: "editorBarMemberDrag-"
                                                            + widgetRow.chipId + "-" + memberRow.modelData

                                                Layout.alignment: Qt.AlignTop
                                                enabled: root.dragReorder
                                                visible: root.dragReorder
                                                onStarted: root.startDrag(memberRow.modelData)
                                                onMoved: function (sceneX, sceneY) {
                                                    root.pointAt(sceneX, sceneY)
                                                }
                                                onFinished: root.finishDrag()
                                            }

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

                                    // An empty chip still needs a target while a
                                    // drag is in flight.
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.dragging
                                                                ? VitrailTokens.gap("md") : 0
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
        }

        // The insertion line: the gap the drop would fill, in the primary
        // colour, drawn over the list at the height of the hovered row.
        VitrailSurface {
            id: insertionLine

            objectName: "editorBarInsertion"

            visible: root.dragTarget !== null && root.dragLine !== null
            z: 90
            x: root.dragLine !== null ? root.dragLine.x : 0
            y: root.dragLine !== null ? root.dragLine.y - height / 2 : 0
            width: root.dragLine !== null ? root.dragLine.width : 0
            height: VitrailTokens.gap("xs")
            radius: height / 2
            tint: VitrailTokens.color("primary", "#a8c7fa")
            opacityLevel: VitrailTokens.opacity
        }

        // The ghost: a copy of the dragged row that follows the pointer. It
        // says why a destination is refused instead of drawing a line.
        Item {
            id: ghost

            objectName: "editorBarGhost"

            readonly property real gap: VitrailTokens.gap("sm")

            visible: root.dragging
            z: 100
            width: ghostRow.implicitWidth + 2 * ghost.gap
            height: ghostRow.implicitHeight + 2 * VitrailTokens.gap("xs")
            x: Math.max(ghost.gap,
                        Math.min(root.width - ghost.width - ghost.gap,
                                 root.dragPoint.x + ghost.gap))
            y: Math.max(ghost.gap,
                        Math.min(root.height - ghost.height - ghost.gap,
                                 root.dragPoint.y - ghost.height / 2))

            VitrailSurface {
                anchors.fill: parent
                radius: VitrailTokens.radius * 0.7
                tint: VitrailTokens.color("primary", "#a8c7fa")
                opacityLevel: VitrailTokens.opacity * 0.61
            }

            RowLayout {
                id: ghostRow

                anchors.centerIn: parent
                spacing: VitrailTokens.gap("xs")

                VitrailIcon {
                    icon: root.entryIcon(root.dragId)
                    size: "sm"
                    color: VitrailTokens.color("foreground", "#e2e2e9")
                }

                ColumnLayout {
                    spacing: 0

                    VitrailText {
                        variant: "label"
                        text: root.entryLabel(root.dragId)
                    }

                    VitrailText {
                        visible: root.dragInvalid
                        variant: "label"
                        color: VitrailTokens.color("error", "#ffb4ab")
                        text: root.t("bar.editor.drop.invalid")
                    }
                }
            }
        }
}
