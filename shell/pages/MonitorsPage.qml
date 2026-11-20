import QtQuick
import QtQuick.Layouts
import Qt.labs.settings 1.1
import "../../kit"
import "../../kit/base"
import "../monitorsview.js" as View

// Monitors: a Windows-style canvas at the outputs' logical positions, with the
// selected output's settings underneath, all in one scroll. Nothing reaches
// monitors.ini while the user drags or edits: the page keeps a draft, and the
// floating bar writes it only on Apply. Discard restores the applied document;
// a refused apply keeps the draft and shows why.
//
// The window cannot run commands: `bin/vitrail-settings` injects the live
// state as `--monitors`, and `vitrail-monitors apply` rewrites
// monitor-state.json after every change (the path unit runs it through
// apply-settings.sh). The page polls that file while it waits, then adopts it.
// The one JSON document is `monitorOverrides` in monitors.ini; an output
// without an entry follows Hyprland's defaults.
//
// The picture and the bar of one output live in their own categories
// (Wallpaper and Bar): this page owns only the output itself.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string configDir: ""
    // The small files the bar watches (<cache>/system/monitor-edit.ini).
    property string cacheDir: ""
    // { available, monitors: [...], overrides } as injected at launch.
    property var monitors: ({ available: false, monitors: [] })

    property var live: page.monitors && page.monitors.monitors ? page.monitors.monitors : []
    property bool available: page.monitors && page.monitors.available === true
    // A change is on its way to the compositor; poll until the state answers.
    property bool pending: false
    property double sent: 0

    // The applied document, the draft the canvas edits, and the last saved
    // text, which Discard puts back after a refused apply.
    property var appliedDoc: ({})
    property var draftDoc: ({})
    property string previousText: ""
    property string selected: ""
    property string error: ""

    readonly property bool dirty: View.dirty(page.appliedDoc, page.draftDoc)
    readonly property int changes: View.countChanges(page.appliedDoc, page.draftDoc)
    // The selected output stays marked on its physical screen while this page
    // is on screen.
    readonly property bool indicatorActive: page.visible
    readonly property string indicatorState: View.indicator(page.selected, page.indicatorActive)

    readonly property var selectedMonitor: View.live(page.live, page.selected)
    readonly property var selectedSpec: View.override(page.draftDoc, page.selected)
    readonly property var canvasRects: View.rects(page.live, page.draftDoc)
    readonly property var canvasBounds: View.bounds(page.canvasRects)

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function monitorOf(name) {
        return View.live(page.live, name)
    }

    function specOf(name) {
        var spec = View.override(page.draftDoc, name)
        return spec || View.seed(page.monitorOf(name))
    }

    function refreshDraft() {
        var fallback = page.selected !== "" ? page.selected : View.defaultPrimary(page.live)
        page.appliedDoc = View.draft(page.live, page.prefs.monitorOverrides || "", fallback)
        page.draftDoc = View.copy(page.appliedDoc)
        page.error = ""
        page.previousText = ""
        page.ensureSelection()
    }

    function ensureSelection() {
        var name = page.selected
        if (!View.live(page.live, name))
            name = View.primaryOf(page.draftDoc)
        if (name === "" || !View.live(page.live, name))
            name = View.defaultPrimary(page.live)
        if (name !== page.selected)
            page.selected = name
    }

    function select(name) {
        if (!View.live(page.live, name))
            return
        page.selected = name
    }

    function patch(name, values) {
        page.draftDoc = View.set(page.draftDoc, page.live, name, values)
    }

    function setPrimary(name) {
        page.draftDoc = View.setPrimary(page.draftDoc, name)
        page.selected = name
    }

    function resetDraft(name) {
        var monitor = page.monitorOf(name)
        if (!monitor)
            return
        var wasPrimary = page.specOf(name).primary === true
        var next = View.copy(page.draftDoc)
        next[name] = View.seed(monitor)
        if (wasPrimary)
            next[name].primary = true
        page.draftDoc = next
        page.ensureSelection()
    }

    // A typed position, committed when the field is accepted or loses focus.
    function setPosition(name, x, y) {
        var left = Number(x)
        var top = Number(y)
        if (isNaN(left) || isNaN(top))
            return
        page.patch(name, { position: Math.round(left) + "x" + Math.round(top) })
    }

    function dragMonitor(name, x, y) {
        page.draftDoc = View.moveTo(page.draftDoc, page.live, name, x, y, false)
    }

    function dropMonitor(name) {
        page.draftDoc = View.drop(page.draftDoc, page.live, name)
    }

    function canvasFit(width, height) {
        return View.fit(page.canvasBounds, width, height, VitrailTokens.gap("lg"))
    }

    // The canvas frame stays put while a monitor is dragged: re-fitting on
    // every move changes the scale under the pointer, and the output slips
    // away from it. It re-fits once, when the drag ends.
    property var dragFrame: null

    function frameFor(width, height) {
        return page.dragFrame !== null ? page.dragFrame : page.canvasFit(width, height)
    }

    function beginDrag() {
        page.dragFrame = page.canvasFit(canvas.width, canvas.height)
    }

    function endDrag() {
        page.dragFrame = null
    }

    // --- the applied document ------------------------------------------------
    function applyDraft() {
        if (!page.dirty || page.pending)
            return
        page.previousText = View.documentText(page.appliedDoc)
        page.error = ""
        page.prefs.monitorOverrides = View.documentText(page.draftDoc)
        page.wait()
    }

    // The draft goes, and the configuration the page started from comes back
    // (writing it is only needed when a refused Apply had already saved it).
    function discardDraft() {
        if (page.previousText !== "") {
            page.prefs.monitorOverrides = page.previousText
            page.wait()
        }
        page.draftDoc = View.copy(page.appliedDoc)
        page.error = ""
        page.previousText = ""
        page.ensureSelection()
    }

    function wait() {
        page.sent = Date.now()
        page.pending = true
        poller.start()
        patience.restart()
    }

    function poll() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE)
                page.read(request.responseText)
        }
        request.open("GET", "file://" + page.configDir + "/monitor-state.json?_=" + Date.now())
        request.send()
    }

    function read(text) {
        var data
        try {
            data = JSON.parse(text)
        } catch (error) {
            return
        }
        if (!data || (data.updated || 0) < page.sent)
            return
        page.pending = false
        poller.stop()
        patience.stop()
        page.live = data.monitors || []
        page.available = data.available === true
        if (!page.dirty)
            return
        var result = data.result || {}
        if ((result.code || 0) === 0) {
            page.appliedDoc = View.copy(page.draftDoc)
            page.previousText = ""
            page.error = ""
        } else {
            var failed = result.failed || []
            page.error = failed.length > 0
                         ? page.t("monitors.apply.failed").replace("%1", failed.join(", "))
                         : page.t("monitors.apply.refused")
        }
    }

    // --- the indicator on the physical monitor -------------------------------
    function syncIndicator() {
        if (page.cacheDir === "")
            return
        indicatorFile.monitorEdit = page.indicatorState
        // The bar reads this file while the page is open, not at quit: QSettings
        // buffers writes until sync().
        indicatorFile.sync()
    }

    Settings {
        id: indicatorFile

        fileName: page.cacheDir + "/system/monitor-edit.ini"
        category: "monitorEdit"

        property string monitorEdit: ""
    }

    Timer {
        id: poller

        interval: VitrailTokens.duration("poll")
        running: false
        repeat: true
        onTriggered: page.poll()
    }

    // A request that never answers (the apply service is not running) frees
    // the page instead of leaving it waiting.
    Timer {
        id: patience

        interval: VitrailTokens.duration("patience")
        onTriggered: {
            page.pending = false
            page.error = page.t("monitors.apply.timeout")
        }
    }

    onLiveChanged: {
        if (!page.ready)
            return
        page.ensureSelection()
        if (!page.pending && !page.dirty)
            page.refreshDraft()
    }

    onVisibleChanged: page.syncIndicator()
    onSelectedChanged: page.syncIndicator()
    onIndicatorActiveChanged: page.syncIndicator()

    Connections {
        target: page.prefs

        function onMonitorOverridesChanged() {
            if (page.ready && !page.pending && !page.dirty)
                page.refreshDraft()
        }
    }

    Component.onDestruction: {
        if (page.cacheDir !== "") {
            indicatorFile.monitorEdit = View.indicator("", false)
            indicatorFile.sync()
        }
    }

    // The live state can arrive while the page is still being built; the
    // draft needs the outputs, so the first read waits for this.
    property bool ready: false

    Component.onCompleted: {
        page.ready = true
        page.refreshDraft()
        page.syncIndicator()
    }

    // One scroll for the whole page: the canvas leaves the top as the output's
    // settings come up, instead of staying pinned over them.
    Flickable {
        id: pageScroll

        objectName: "pageScroll"
        anchors.fill: parent
        contentHeight: pageColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: pageColumn

            width: parent.width
            enabled: !page.pending
            spacing: VitrailTokens.gap("lg")

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: page.t("monitors.help")
                color: page.palette.muted
                wrapMode: Text.WordWrap
            }

            VitrailText {
                Layout.fillWidth: true
                visible: !page.available
                variant: "label"
                text: page.t("monitors.unavailable")
                color: page.palette.muted
                wrapMode: Text.WordWrap
            }

            // The canvas: each output at its logical place, dragged with the
            // pointer and snapped to the others on release.
            Item {
                id: canvas

                objectName: "canvas"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(VitrailTokens.size("display") * 4, page.height * 0.34)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: VitrailTokens.radius
                    color: Qt.rgba(page.palette.surfaceHigh.r, page.palette.surfaceHigh.g,
                                   page.palette.surfaceHigh.b, 0.35)
                }

                VitrailText {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: VitrailTokens.gap("sm")
                    variant: "label"
                    text: page.t("monitors.canvas.help")
                    color: page.palette.muted
                }

                Repeater {
                    model: page.canvasRects

                    delegate: Item {
                        id: screen

                        required property var modelData

                        objectName: "canvasMonitor." + screen.modelData.name
                        readonly property var frame: page.frameFor(canvas.width, canvas.height)
                        readonly property bool chosen: screen.modelData.name === page.selected
                        readonly property var spec: View.override(page.draftDoc, screen.modelData.name)
                                                  || View.seed(screen.modelData.monitor)

                        x: screen.frame.x + screen.modelData.x * screen.frame.scale
                        y: screen.frame.y + screen.modelData.y * screen.frame.scale
                        width: Math.max(28, screen.modelData.width * screen.frame.scale)
                        height: Math.max(24, screen.modelData.height * screen.frame.scale)
                        z: screen.chosen ? 2 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(VitrailTokens.radius, height / 2)
                            color: Qt.rgba(page.palette.surfaceHigh.r, page.palette.surfaceHigh.g,
                                           page.palette.surfaceHigh.b, screen.chosen ? 0.9 : 0.62)
                            border.width: screen.chosen ? 2 : 1
                            border.color: screen.chosen
                                          ? page.palette.primary
                                          : Qt.rgba(page.palette.foreground.r, page.palette.foreground.g,
                                                    page.palette.foreground.b, 0.22)
                            opacity: screen.modelData.disabled ? 0.45 : 1
                        }

                        VitrailIcon {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: VitrailTokens.gap("xs")
                            visible: screen.modelData.primary
                            icon: "star"
                            size: "sm"
                            color: page.palette.primary
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: VitrailTokens.gap("xs")
                            spacing: 0

                            VitrailText {
                                width: parent.width
                                variant: "label"
                                text: screen.modelData.name
                                color: screen.chosen ? page.palette.primary : page.palette.foreground
                                elide: Text.ElideRight
                            }

                            VitrailText {
                                width: parent.width
                                variant: "label"
                                visible: screen.chosen
                                text: page.t("monitors.selected")
                                color: page.palette.primary
                                elide: Text.ElideRight
                            }

                            VitrailText {
                                width: parent.width
                                variant: "label"
                                visible: !screen.chosen && screen.modelData.mirror !== ""
                                text: page.t("monitors.mirror") + " " + screen.modelData.mirror
                                color: page.palette.muted
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: dragArea

                            property real pressX: 0
                            property real pressY: 0
                            property real originX: 0
                            property real originY: 0
                            property bool dragged: false

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // The page scrolls; a press on a monitor belongs to it.
                            preventStealing: true

                            onPressed: function (mouse) {
                                page.select(screen.modelData.name)
                                page.beginDrag()
                                var at = dragArea.mapToItem(canvas, mouse.x, mouse.y)
                                dragArea.pressX = at.x
                                dragArea.pressY = at.y
                                var place = View.position(screen.spec)
                                dragArea.originX = place.auto ? screen.modelData.monitor.x : place.x
                                dragArea.originY = place.auto ? screen.modelData.monitor.y : place.y
                                dragArea.dragged = false
                            }

                            onPositionChanged: function (mouse) {
                                if (!dragArea.pressed)
                                    return
                                var at = dragArea.mapToItem(canvas, mouse.x, mouse.y)
                                var fit = page.frameFor(canvas.width, canvas.height)
                                var dx = (at.x - dragArea.pressX) / fit.scale
                                var dy = (at.y - dragArea.pressY) / fit.scale
                                if (Math.abs(dx) + Math.abs(dy) > 1)
                                    dragArea.dragged = true
                                page.dragMonitor(screen.modelData.name, dragArea.originX + dx,
                                                 dragArea.originY + dy)
                            }

                            onReleased: {
                                if (dragArea.dragged)
                                    page.dropMonitor(screen.modelData.name)
                                page.endDrag()
                                page.select(screen.modelData.name)
                            }

                            onCanceled: page.endDrag()
                            onClicked: page.select(screen.modelData.name)
                        }
                    }
                }

                VitrailText {
                    anchors.centerIn: parent
                    visible: page.canvasRects.length === 0
                    variant: "body"
                    text: page.t("monitors.none")
                    color: page.palette.muted
                }
            }

            // The selected output's settings, below the canvas in the same scroll.
            ColumnLayout {
                id: detailsColumn

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xl")

                Section {
                    Layout.fillWidth: true
                    visible: page.selected !== ""
                    title: page.selected !== "" ? page.selected : ""
                    icon: "monitor"
                    badge: page.selectedSpec && page.selectedSpec.primary
                           ? page.t("monitors.primary") : page.t("monitors.selected")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "star"
                        label: page.t("monitors.primary")
                        description: page.t("monitors.primary.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            text: page.selectedSpec && page.selectedSpec.primary
                                  ? page.t("monitors.primary") : page.t("monitors.primary.make")
                            icon: "star"
                            variant: page.selectedSpec && page.selectedSpec.primary ? "flat" : "outlined"
                            enabled: !(page.selectedSpec && page.selectedSpec.primary)
                            onClicked: page.setPrimary(page.selected)
                        }
                    }

                    VitrailSettingRow {
                        icon: "power_settings_new"
                        label: page.t("monitors.enabled")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.selectedSpec ? !page.selectedSpec.disabled : false
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.patch(page.selected, { disabled: !value })
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("md")
                        enabled: page.selectedSpec && !page.selectedSpec.disabled
                                 && page.selectedSpec.mirror === ""
                        opacity: !page.selectedSpec || page.selectedSpec.disabled
                                 || page.selectedSpec.mirror !== "" ? 0.35 : 1

                        VitrailSelect {
                            Layout.fillWidth: true
                            label: page.t("monitors.mode")
                            current: page.selectedSpec ? page.selectedSpec.mode : ""
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            options: page.selectedMonitor
                                     ? View.modes(page.selectedMonitor).map(function (mode) {
                                         return {
                                             key: mode,
                                             label: mode === "preferred"
                                                    ? page.t("monitors.mode.preferred")
                                                    : View.modeLabel(mode)
                                         }
                                     })
                                     : []
                            onSelected: function (key) {
                                page.patch(page.selected, { mode: key })
                            }
                        }

                        VitrailSegmented {
                            objectName: "rotation"
                            Layout.alignment: Qt.AlignVCenter
                            // The icon of each choice is the monitor itself,
                            // turned to the angle the choice applies.
                            options: [
                                { key: "0", label: "0°", icon: "monitor" },
                                { key: "90", label: "90°", icon: "monitor", rotation: 90 },
                                { key: "180", label: "180°", icon: "monitor", rotation: 180 },
                                { key: "270", label: "270°", icon: "monitor", rotation: 270 }
                            ]
                            current: page.selectedSpec ? String(View.degreesOf(page.selectedSpec.transform)) : "0"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: function (key) {
                                page.patch(page.selected, { transform: View.transformOf(key) })
                            }
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("monitors.scale")
                        suffix: "×"
                        from: 0.5
                        to: 3.0
                        stepSize: 0.25
                        // A monitor scale is a stepped value, not a continuum.
                        snap: true
                        decimals: 2
                        value: page.selectedSpec ? page.selectedSpec.scale : 1
                        enabled: page.selectedSpec && !page.selectedSpec.disabled
                                 && page.selectedSpec.mirror === ""
                        opacity: !page.selectedSpec || page.selectedSpec.disabled
                                 || page.selectedSpec.mirror !== "" ? 0.35 : 1
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.patch(page.selected, { scale: value })
                    }

                    VitrailSettingRow {
                        icon: "open_with"
                        label: page.t("monitors.position.auto")
                        description: page.t("monitors.position.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.selectedSpec
                                     && String(page.selectedSpec.position).indexOf("auto") === 0
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            enabled: page.selectedSpec && !page.selectedSpec.disabled
                                     && page.selectedSpec.mirror === ""
                            onToggled: function (value) {
                                var monitor = page.monitorOf(page.selected)
                                page.patch(page.selected, {
                                    position: value ? "auto"
                                                    : (monitor ? monitor.x + "x" + monitor.y : "0x0")
                                })
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("md")
                        enabled: page.selectedSpec && !page.selectedSpec.disabled
                                 && page.selectedSpec.mirror === ""
                                 && String(page.selectedSpec.position).indexOf("auto") !== 0
                        opacity: !page.selectedSpec || page.selectedSpec.disabled
                                 || page.selectedSpec.mirror !== ""
                                 || String(page.selectedSpec.position).indexOf("auto") === 0 ? 0.35 : 1

                        VitrailField {
                            id: posX

                            Layout.fillWidth: true
                            label: page.t("monitors.position.x")
                            text: page.selectedSpec
                                  ? String(View.position(page.selectedSpec).x) : "0"
                            onAccepted: page.setPosition(page.selected, text, posY.text)
                            onActiveFocusChanged: {
                                if (!activeFocus && page.selectedSpec
                                        && String(page.selectedSpec.position).indexOf("auto") !== 0)
                                    page.setPosition(page.selected, text, posY.text)
                            }
                        }

                        VitrailField {
                            id: posY

                            Layout.fillWidth: true
                            label: page.t("monitors.position.y")
                            text: page.selectedSpec
                                  ? String(View.position(page.selectedSpec).y) : "0"
                            onAccepted: page.setPosition(page.selected, posX.text, text)
                            onActiveFocusChanged: {
                                if (!activeFocus && page.selectedSpec
                                        && String(page.selectedSpec.position).indexOf("auto") !== 0)
                                    page.setPosition(page.selected, posX.text, text)
                            }
                        }
                    }

                    VitrailSelect {
                        Layout.fillWidth: true
                        label: page.t("monitors.mirror")
                        current: page.selectedSpec ? page.selectedSpec.mirror : ""
                        enabled: page.selectedSpec && !page.selectedSpec.disabled
                        opacity: !page.selectedSpec || page.selectedSpec.disabled ? 0.35 : 1
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        options: [{ key: "", label: page.t("monitors.mirror.individual") }].concat(
                            View.others(page.live, page.selected).map(function (name) {
                                return { key: name, label: name }
                            }))
                        onSelected: function (key) {
                            page.patch(page.selected, { mirror: key })
                        }
                    }

                    RowLayout {
                        objectName: "detailsLast"
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "label"
                            text: page.t("monitors.reset.help")
                            color: page.palette.muted
                            wrapMode: Text.WordWrap
                        }

                        VitrailButton {
                            text: page.t("monitors.reset")
                            variant: "outlined"
                            tone: "secondary"
                            onClicked: page.resetDraft(page.selected)
                        }
                    }
                }

                // Room for the floating bar: the details scroll behind it, and
                // the last row can still come fully above it.
                Item {
                    id: detailsSpacer

                    objectName: "detailsSpacer"
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.dirty
                                           ? applyBar.height + 2 * VitrailTokens.gap("md") : 0
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: page.selected === "" || page.live.length === 0
                    variant: "body"
                    text: page.t("monitors.none")
                    color: page.palette.muted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // The floating Apply / Discard bar: only while the draft differs.
    VitrailSurface {
        id: applyBar

        objectName: "applyBar"
        z: 20
        visible: page.dirty
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: VitrailTokens.gap("md")
        // The card is only as wide as its controls; the content scrolls
        // visibly around it.
        width: Math.min(page.width - 2 * VitrailTokens.gap("md"),
                        applyRow.implicitWidth + 2 * VitrailTokens.gap("md"))
        height: applyRow.implicitHeight + 2 * VitrailTokens.gap("md")
        tint: page.palette.surfaceHigh
        opacityLevel: VitrailTokens.opacity
        radius: VitrailTokens.radius

        RowLayout {
            id: applyRow

            objectName: "applyRow"
            anchors.fill: parent
            anchors.margins: VitrailTokens.gap("md")
            spacing: VitrailTokens.gap("md")

            VitrailIcon {
                icon: "edit_note"
                size: "md"
                color: page.palette.primary
            }

            ColumnLayout {
                id: applySummary

                readonly property real maxWidth: VitrailTokens.size("display") * 10

                objectName: "applySummary"
                Layout.maximumWidth: applySummary.maxWidth
                Layout.preferredWidth: Math.min(applySummary.implicitWidth, applySummary.maxWidth)
                spacing: 0

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    text: page.changes === 1
                          ? page.t("monitors.draft.summary.one")
                          : page.t("monitors.draft.summary.many").replace("%1", page.changes)
                    color: page.palette.foreground
                    elide: Text.ElideRight
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: page.error !== ""
                    variant: "label"
                    text: page.error
                    color: page.palette.error
                    wrapMode: Text.WordWrap
                }
            }

            VitrailButton {
                text: page.t("monitors.discard")
                icon: "undo"
                variant: "text"
                tone: "secondary"
                enabled: !page.pending
                onClicked: page.discardDraft()
            }

            VitrailButton {
                text: page.t("monitors.apply")
                icon: "check"
                busy: page.pending
                enabled: !page.pending
                onClicked: page.applyDraft()
            }
        }
    }
}
