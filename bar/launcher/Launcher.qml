import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../kit"
import "../kit/base"
import "query.js" as Query
import "search.js" as Search
import "apps.js" as Apps
import "history.js" as History
import "results.js" as Results
import "engine.js" as Engine
import "actions.js" as Actions
import "commands.js" as Commands

// Vitrail's application launcher, the content of the "launcher" popout.
// Empty query: favourites, recent apps and every app by category. Typing: a
// result list; a prefix picks a mode (? = > / @ : ;), Tab cycles through them.
// The logic is in query.js / engine.js (tested); this file is the surface.
FocusScope {
    id: root

    property var strings: ({})
    // The preferences (bar/prefs.js merges the files).
    property var prefs: ({})
    // LauncherStore: usage, favourites and hidden apps.
    property var store: null
    // A mode to start in (`launcher open <mode>`).
    property string initialMode: ""
    // popout or fullscreen: see the `launcher` variants.
    property string variant: "popout"
    property real screenWidth: 1920
    property real screenHeight: 1080
    property string binDir: Quickshell.env("HOME") + "/.local/bin"
    // What is typed in the search field.
    property alias query: field.text
    property bool expanded: false
    property int current: 0
    property string tab: "all"
    // A menu of one app, or null.
    property var menu: null
    property int menuCurrent: 0

    signal done()
    signal openPopup(string kind)
    signal openSession()

    readonly property var style: VitrailStyle.resolve("launcher", root.variant)
    readonly property var metrics: VitrailTokens.launcher[root.style.metrics]
    readonly property bool fullscreen: root.style.fill
    readonly property real gapSize: VitrailTokens.gap(root.style.gap)
    // The content block: the card itself, or centred on the screen.
    readonly property real edge: root.gapSize * root.metrics.margin
    readonly property real contentWidth: root.fullscreen ? Math.min(root.width - 2 * root.edge, root.metrics.content) : root.width
    // The field, the lists and the footer, narrower than the grid.
    readonly property real narrowWidth: root.metrics.narrow > 0 ? Math.min(root.contentWidth, root.metrics.narrow) : root.contentWidth
    readonly property string home: Quickshell.env("HOME")
    readonly property var enabled: {
        var raw = root.prefs.launcherModes
        return raw === undefined ? Query.MODES : String(raw).split("|").filter(function (mode) {
            return Query.MODES.indexOf(mode) >= 0
        })
    }
    readonly property string engine: root.prefs.launcherEngine || "duckduckgo"
    readonly property var bangs: Query.bangs(root.prefs.launcherBangs || "")
    readonly property bool listView: root.prefs.launcherView === "list"
    readonly property var state: root.store ? root.store.state : History.empty()

    readonly property var parsed: Query.parse(field.text, { enabled: root.enabled, bangs: root.bangs })
    readonly property bool browsing: root.parsed.mode === "all" && field.text.trim() === ""

    // --- data ------------------------------------------------------------------
    readonly property var appItems: Apps.items(DesktopEntries.applications.values, root.state.hidden)
    readonly property var actionItems: Actions.toItems(root.t)
    readonly property var windowItems: Hyprland.toplevels.values.map(function (top) {
        var ipc = top.lastIpcObject || ({})
        return Engine.windowItem(top.address, top.title, ipc["class"] || "", ipc.workspace ? ipc.workspace.name : "")
    })
    property string calcQuery: ""
    property string calcText: ""
    property string fileQuery: ""
    property var fileItems: []
    property var clips: []
    property string filesTool: "fd"

    readonly property var shown: Engine.build(root.parsed, {
        apps: root.appItems, actions: root.actionItems, windows: root.windowItems,
        history: root.state.history, favourites: root.state.favourites, now: Date.now(),
        engine: root.engine, bangs: root.bangs,
        calc: { query: root.calcQuery, text: root.calcText, busy: calcRun.busy },
        files: { query: root.fileQuery, items: root.fileItems, busy: fileRun.busy },
        clips: root.clips, t: root.t, home: root.home
    })

    // The browse view: favourites, recent, then the category's apps.
    readonly property int columns: root.expanded || root.fullscreen
                                   ? Math.max(root.metrics.columns, Math.floor(root.contentWidth / root.metrics.tileMin))
                                   : root.metrics.columns
    readonly property var appsById: {
        var map = {}
        root.appItems.forEach(function (item) { map[item.id] = item })
        return map
    }
    readonly property var tabList: Apps.tabs(root.appItems)
    readonly property var browseSections: {
        var all = root.tab === "all"
        var favourites = all ? root.state.favourites.map(function (id) { return root.appsById[id] })
                                 .filter(function (item) { return item !== undefined }) : []
        var recent = all ? Search.recent(root.appItems, { history: root.state.history, now: Date.now(),
                                                         limit: root.columns, skip: root.state.favourites }) : []
        var parts = [{ key: "favourites", items: favourites }, { key: "recent", items: recent },
                     { key: "apps", items: Apps.inCategory(root.appItems, root.tab) }]
        var offset = 0
        parts.forEach(function (part) {
            part.offset = offset
            offset += part.items.length
        })
        return parts
    }
    readonly property var lengths: root.browseSections.map(function (part) { return part.items.length })
    readonly property int count: root.browsing ? Results.total(root.lengths) : root.shown.list.length
    readonly property var currentApp: {
        if (root.browsing) {
            for (var i = 0; i < root.browseSections.length; i++) {
                var part = root.browseSections[i]
                if (root.current >= part.offset && root.current < part.offset + part.items.length)
                    return part.items[root.current - part.offset]
            }
            return null
        }
        var result = root.shown.list[root.current]
        return result && result.run.kind === "app" ? result.run.item : null
    }

    implicitWidth: root.fullscreen ? root.screenWidth
                   : root.expanded ? Math.max(root.metrics.width, Math.round(root.screenWidth * VitrailTokens.launcher.expand)) : root.metrics.width
    implicitHeight: root.fullscreen ? root.screenHeight
                    : root.expanded ? Math.max(root.metrics.height, Math.round(root.screenHeight * VitrailTokens.launcher.expand)) : root.metrics.height

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // --- running things --------------------------------------------------------
    function detach(command) {
        Quickshell.execDetached(command)
    }

    function launchApp(item) {
        item.entry.execute()
        if (root.store)
            root.store.record(item.id)
        root.done()
    }

    function carryOut(run, shift) {
        switch (run.kind) {
        case "app":
            root.launchApp(run.item)
            return
        case "appAction":
            run.action.execute()
            if (root.store)
                root.store.record(run.item.id)
            break
        case "web":
            root.detach(Commands.open(run.url))
            break
        case "calc":
            if (run.text === "")
                return
            root.detach(Commands.copy(run.text))
            break
        case "run":
            root.detach(shift ? Commands.runDetached(run.command) : Commands.runInTerminal(run.command))
            break
        case "file":
            root.detach(shift ? Commands.openFolder(run.path) : Commands.open(run.path))
            break
        case "window":
            Hyprland.dispatch("focuswindow address:0x" + String(run.address).replace(/^0x/, ""))
            break
        case "clip":
            root.detach(Commands.clipCopy(run.id))
            break
        case "fill":
            field.text = run.text
            return
        case "cli":
            Quickshell.execDetached({ command: Commands.cli(run.args), environment: { PYTHONPATH: Quickshell.shellDir + "/.." } })
            break
        case "exec":
            root.detach(run.command)
            break
        case "settings":
            root.detach(Commands.settings(root.binDir, run.category))
            break
        case "popup":
            root.openPopup(run.popup)
            return
        case "session":
            root.openSession()
            return
        case "pin":
            root.store.togglePin(run.id)
            root.menu = null
            return
        case "hide":
            root.store.hide(run.id)
            root.menu = null
            return
        case "folder":
            root.detach(Commands.openProgramFolder(run.exec))
            break
        }
        root.done()
    }

    function activate(shift) {
        if (root.menu) {
            root.carryOut(root.menu.rows[root.menuCurrent].run, shift)
            return
        }
        if (root.browsing) {
            if (root.currentApp)
                root.launchApp(root.currentApp)
            return
        }
        var result = root.shown.list[root.current]
        if (result)
            root.carryOut(result.run, shift)
    }

    function openMenu(item) {
        if (!item || !root.store)
            return
        var pinned = History.isPinned(root.state, item.id)
        var rows = (item.actions || []).map(function (action) {
            return { title: action.name, appIcon: action.icon, glyph: "play_arrow", run: { kind: "appAction", action: action, item: item } }
        })
        rows.push({ title: root.t(pinned ? "launcher.unpin" : "launcher.pin"), glyph: pinned ? "keep_off" : "keep",
                    run: { kind: "pin", id: item.id } })
        rows.push({ title: root.t("launcher.hide"), glyph: "visibility_off", run: { kind: "hide", id: item.id } })
        rows.push({ title: root.t("launcher.openFolder"), glyph: "folder_open", run: { kind: "folder", exec: item.exec } })
        root.menuCurrent = 0
        root.menu = { item: item, rows: rows }
    }

    function move(direction) {
        if (root.menu) {
            if (direction === "up" || direction === "down")
                root.menuCurrent = Results.step(root.menuCurrent, root.menu.rows.length, direction === "down" ? 1 : -1)
            else if (direction === "left")
                root.menu = null
            return
        }
        if (root.browsing && !root.listView) {
            root.current = Results.gridMove(root.lengths, root.columns, root.current, direction)
        } else if (direction === "up" || direction === "down") {
            root.current = Results.step(root.current, root.count, direction === "down" ? 1 : -1)
        } else if (direction === "right") {
            root.openMenu(root.currentApp)
        }
    }

    function dismiss() {
        if (root.menu)
            root.menu = null
        else if (field.text !== "")
            field.text = ""
        else
            root.done()
    }

    // A page of the grid: a few rows at a time.
    function page(direction) {
        for (var i = 0; i < 3; i++)
            root.current = Results.gridMove(root.lengths, root.columns, root.current, direction)
    }

    function stepTab(delta) {
        if (!root.browsing)
            return
        var keys = root.tabList.map(function (entry) { return entry.key })
        root.tab = keys[Results.step(Math.max(0, keys.indexOf(root.tab)), keys.length, delta)]
        root.current = 0
    }

    function cycleMode(delta) {
        field.text = Query.cycle(field.text, root.enabled, delta)
    }

    function press(event) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        var key = event.key
        event.accepted = true
        if (key === Qt.Key_Escape)
            root.dismiss()
        else if (key === Qt.Key_Tab && !root.menu)
            root.cycleMode(1)
        else if (key === Qt.Key_Backtab && !root.menu)
            root.cycleMode(-1)
        else if (key === Qt.Key_Return || key === Qt.Key_Enter)
            root.activate(shift)
        else if (ctrl && key === Qt.Key_E && !root.fullscreen)
            root.expanded = !root.expanded
        else if (ctrl && key === Qt.Key_K || key === Qt.Key_Menu)
            root.openMenu(root.currentApp)
        else if (ctrl && key === Qt.Key_Left)
            root.stepTab(-1)
        else if (ctrl && key === Qt.Key_Right)
            root.stepTab(1)
        else if (ctrl && key >= Qt.Key_1 && key <= Qt.Key_9 && !root.browsing) {
            var result = root.shown.list[key - Qt.Key_1]
            if (result)
                root.carryOut(result.run, shift)
        } else if (key === Qt.Key_PageDown && root.browsing && !root.listView)
            root.page("down")
        else if (key === Qt.Key_PageUp && root.browsing && !root.listView)
            root.page("up")
        else if (key === Qt.Key_Up)
            root.move("up")
        else if (key === Qt.Key_Down)
            root.move("down")
        else if (key === Qt.Key_Left && (root.browsing || field.cursorPosition === 0 || root.menu))
            root.move("left")
        else if (key === Qt.Key_Right && (root.browsing || field.cursorPosition === field.text.length))
            root.move("right")
        else
            event.accepted = false
    }

    // --- async searches ----------------------------------------------------------
    function search() {
        var text = root.parsed.text
        if (text === "")
            return
        if (root.parsed.mode === "calc" || (root.parsed.mode === "all" && Query.looksLikeMath(text)))
            calcRun.run(Commands.calc(text), text)
        if (root.parsed.mode === "files")
            fileRun.run(Commands.files(root.filesTool, text, VitrailTokens.launcher.maxFiles, root.home), text)
    }

    onParsedChanged: {
        if (root.parsed.mode === "clipboard" && !clipRun.busy && root.clips.length === 0)
            clipRun.run(Commands.clipList(), "")
        debounce.restart()
    }

    Timer {
        id: debounce

        interval: VitrailTokens.duration("debounce")
        onTriggered: root.search()
    }

    AsyncRun {
        id: calcRun

        onFinished: function (tag, output) {
            root.calcText = output.split("\n")[0].trim()
            root.calcQuery = tag
        }
    }

    AsyncRun {
        id: fileRun

        onFinished: function (tag, output) {
            var limit = VitrailTokens.launcher.maxFiles
            root.fileItems = root.filesTool === "plocate" ? Commands.parseFiles(output, root.home, limit)
                                                           : output.split("\n").filter(function (line) { return line !== "" }).slice(0, limit)
            root.fileQuery = tag
        }
    }

    AsyncRun {
        id: clipRun

        onFinished: function (tag, output) {
            root.clips = Commands.parseClips(output, 200)
        }
    }

    AsyncRun {
        id: probe

        onFinished: function (tag, output) {
            root.filesTool = output.trim() === "plocate" ? "plocate" : "fd"
        }
    }

    onCurrentChanged: if (!root.browsing) results.positionViewAtIndex(root.rowOf(root.current), ListView.Contain)
    onCountChanged: root.current = Results.clamp(root.current, root.count)

    function rowOf(index) {
        for (var i = 0; i < root.shown.rows.length; i++) {
            if (root.shown.rows[i].index === index)
                return i
        }
        return 0
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        probe.run(Commands.probeFiles(), "")
        if (root.initialMode && Query.PREFIXES[root.initialMode])
            field.text = Query.PREFIXES[root.initialMode]
        field.forceActiveFocus()
    }

    // `launcher open <mode>` while it is already open.
    onInitialModeChanged: if (root.initialMode && Query.PREFIXES[root.initialMode]) field.text = Query.PREFIXES[root.initialMode]

    // --- tooltips ----------------------------------------------------------------
    property Item tipTarget: null

    function hover(item, on) {
        if (on)
            root.tipTarget = item
        else if (root.tipTarget === item)
            root.tipTarget = null
    }

    function placeTip() {
        if (!root.tipTarget)
            return
        var corner = root.tipTarget.mapToItem(root, 0, 0)
        var gap = VitrailTokens.gap("sm")
        var below = corner.y + root.tipTarget.height + gap
        tip.x = Math.max(0, Math.min(corner.x + root.tipTarget.width / 2 - tip.width / 2, root.width - tip.width))
        tip.y = below + tip.height > root.height ? corner.y - tip.height - gap : below
    }

    onTipTargetChanged: root.placeTip()

    Binding {
        target: tip
        property: "text"
        value: root.tipTarget ? root.tipTarget.tooltip : ""
        when: root.tipTarget !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: tip
        property: "detail"
        value: root.tipTarget ? root.tipTarget.tooltipDetail || "" : ""
        when: root.tipTarget !== null
        restoreMode: Binding.RestoreNone
    }

    // --- layout --------------------------------------------------------------------
    // Clicks between the blocks are not the backdrop's (fullscreen).
    MouseArea {
        anchors.fill: layout
        enabled: root.fullscreen
    }

    ColumnLayout {
        id: layout

        x: (root.width - root.contentWidth) / 2
        y: root.edge
        width: root.contentWidth
        height: root.height - 2 * root.edge
        spacing: root.gapSize

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: root.narrowWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: 0
            spacing: VitrailTokens.gap("sm")

            VitrailField {
                id: field

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                size: root.style.field
                leadingIcon: "search"
                placeholder: root.t("launcher.placeholder")
                focus: true
                // The launcher's keys come before the text's own (Ctrl+E, Ctrl+K).
                onKeyPressed: function (event) { root.press(event) }
                onTextChanged: {
                    root.current = 0
                    root.menu = null
                }
            }

            // The mode, and a way to change it with the pointer.
            Item {
                id: chip

                property string tooltip: root.t("launcher.chip").replace("%1", chipLabel.text)
                property string tooltipDetail: root.t("launcher.chipHint")
                readonly property bool hovered: chipHover.hovered
                readonly property var glyphs: ({ all: "apps", web: "language", calc: "calculate", run: "terminal", files: "folder",
                                                 windows: "web_asset", actions: "bolt", clipboard: "content_paste" })

                implicitWidth: chipRow.implicitWidth + 2 * VitrailTokens.gap("md")
                implicitHeight: chipRow.implicitHeight + 2 * VitrailTokens.gap("sm")
                onHoveredChanged: root.hover(chip, chip.hovered)

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: VitrailTokens.color("primary")
                    opacity: chip.hovered ? 0.3 : 0.18

                    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                }

                HoverHandler {
                    id: chipHover
                }

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: VitrailTokens.gap("xs")

                    VitrailText {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "icon"
                        text: chip.glyphs[root.parsed.mode]
                        color: VitrailTokens.color("primary")
                    }

                    VitrailText {
                        id: chipLabel

                        anchors.verticalCenter: parent.verticalCenter
                        variant: "label"
                        color: VitrailTokens.color("primary")
                        opacity: 1
                        text: root.parsed.bang ? "!" + root.parsed.bang.key + " " + root.parsed.bang.name
                                               : root.t("launcher.mode." + root.parsed.mode)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cycleMode(1)
                        field.forceActiveFocus()
                    }
                }
            }

            VitrailButton {
                id: expand

                visible: !root.fullscreen
                property string tooltip: root.t(root.expanded ? "launcher.collapse" : "launcher.expand")
                property string tooltipDetail: "Ctrl+E"

                variant: "plain"
                tone: "secondary"
                icon: root.expanded ? "close_fullscreen" : "open_in_full"
                onHoveredChanged: root.hover(expand, expand.hovered)
                onClicked: {
                    root.expanded = !root.expanded
                    field.forceActiveFocus()
                }
            }
        }

        Item {
            id: body

            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- browse: favourites, recent and the category's apps ------------
            Flickable {
                id: browse

                anchors.fill: parent
                visible: root.browsing
                contentHeight: browseColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                // The selection scrolls into view with a glide.
                function reveal(item) {
                    var top = item.mapToItem(browseColumn, 0, 0).y
                    var pad = VitrailTokens.gap("sm")
                    var target = browse.contentY
                    if (top - pad < browse.contentY)
                        target = Math.max(0, top - pad)
                    else if (top + item.height + pad > browse.contentY + browse.height)
                        target = top + item.height + pad - browse.height
                    if (target !== browse.contentY) {
                        glide.to = target
                        glide.restart()
                    }
                }

                NumberAnimation {
                    id: glide

                    target: browse
                    property: "contentY"
                    duration: VitrailTokens.duration(root.style.motion)
                    easing.type: Easing.OutCubic
                }

                Column {
                    id: browseColumn

                    width: browse.width
                    spacing: root.gapSize

                    Repeater {
                        model: root.browseSections

                        delegate: Column {
                            id: section

                            required property var modelData

                            width: browseColumn.width
                            spacing: VitrailTokens.gap("xs")
                            visible: section.modelData.items.length > 0 || section.modelData.key === "apps"

                            VitrailText {
                                visible: section.modelData.key !== "apps" || root.tab === "all"
                                variant: "label"
                                font.weight: Font.DemiBold
                                text: root.t(section.modelData.key === "favourites" ? "launcher.favourites"
                                             : section.modelData.key === "recent" ? "launcher.recent" : "launcher.allApps")
                            }

                            // Many categories: the strip scrolls sideways.
                            Flickable {
                                id: strip

                                visible: section.modelData.key === "apps"
                                width: parent.width
                                height: categories.implicitHeight
                                contentWidth: categories.width
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                WheelHandler {
                                    onWheel: function (event) {
                                        strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - event.angleDelta.y))
                                    }
                                }

                                VitrailTabs {
                                    id: categories

                                    width: Math.max(implicitWidth, strip.width)
                                    tabs: root.tabList.map(function (entry) { return { key: entry.key, label: root.t(entry.label) } })
                                    current: root.tab
                                    onSelected: function (key) {
                                        root.tab = key
                                        root.current = 0
                                        field.forceActiveFocus()
                                    }
                                }
                            }

                            Flow {
                                visible: !root.listView
                                width: parent.width

                                Repeater {
                                    model: root.listView ? [] : section.modelData.items

                                    delegate: AppTile {
                                        id: tile

                                        required property var modelData
                                        required property int index

                                        width: Math.floor(browseColumn.width / root.columns)
                                        iconSize: root.metrics.tileIcon
                                        labelVariant: root.style.label
                                        lines: root.style.lines
                                        name: tile.modelData.name
                                        detail: tile.modelData.genericName || tile.modelData.comment
                                        icon: tile.modelData.icon
                                        pinned: History.isPinned(root.state, tile.modelData.id)
                                        selected: root.current === section.modelData.offset + tile.index
                                        onSelectedChanged: if (tile.selected) browse.reveal(tile)
                                        onHoveredChanged: root.hover(tile, tile.hovered)
                                        onClicked: root.launchApp(tile.modelData)
                                        onContextRequested: root.openMenu(tile.modelData)
                                    }
                                }
                            }

                            Column {
                                visible: root.listView
                                width: parent.width

                                Repeater {
                                    model: root.listView ? section.modelData.items : []

                                    delegate: ResultRow {
                                        id: line

                                        required property var modelData
                                        required property int index

                                        width: section.width
                                        iconSize: root.metrics.rowIcon
                                        title: line.modelData.name
                                        subtitle: line.modelData.genericName || line.modelData.comment
                                        appIcon: line.modelData.icon
                                        hasMenu: true
                                        pinned: History.isPinned(root.state, line.modelData.id)
                                        selected: root.current === section.modelData.offset + line.index
                                        onSelectedChanged: if (line.selected) browse.reveal(line)
                                        onHoveredChanged: root.hover(line, line.hovered)
                                        onClicked: root.launchApp(line.modelData)
                                        onContextRequested: root.openMenu(line.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- results: grouped by what they are ------------------------------
            ListView {
                id: results

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.narrowWidth
                visible: !root.browsing
                model: root.shown.rows
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                spacing: VitrailTokens.gap("xs") / 2

                delegate: Item {
                    id: entry

                    required property var modelData

                    width: ListView.view.width
                    height: entry.modelData.header ? heading.implicitHeight + VitrailTokens.gap("sm") : result.implicitHeight

                    VitrailText {
                        id: heading

                        visible: entry.modelData.header === true
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: VitrailTokens.gap("sm")
                        variant: "label"
                        font.weight: Font.DemiBold
                        text: entry.modelData.header ? root.t("launcher.group." + entry.modelData.group) : ""
                    }

                    ResultRow {
                        id: result

                        readonly property var data: entry.modelData.result || ({})

                        visible: entry.modelData.header !== true
                        width: parent.width
                        iconSize: root.metrics.rowIcon
                        title: result.data.title || ""
                        subtitle: result.data.subtitle || ""
                        appIcon: result.data.appIcon || ""
                        glyph: result.data.icon || "apps"
                        busy: result.data.busy === true
                        hasMenu: result.data.group === "apps"
                        pinned: result.data.group === "apps" && History.isPinned(root.state, result.data.item ? result.data.item.id : "")
                        hint: entry.modelData.index !== undefined && entry.modelData.index < 9 ? "Ctrl+" + (entry.modelData.index + 1) : ""
                        selected: entry.modelData.index === root.current
                        onHoveredChanged: root.hover(result, result.hovered)
                        onClicked: root.carryOut(result.data.run, false)
                        onContextRequested: if (result.data.run && result.data.run.kind === "app") root.openMenu(result.data.run.item)
                    }
                }
            }

            VitrailText {
                anchors.centerIn: parent
                width: parent.width - 2 * VitrailTokens.gap("lg")
                visible: !root.browsing && root.shown.list.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: (fileRun.busy && root.parsed.mode === "files") || (calcRun.busy && root.parsed.mode === "calc")
                      ? root.t("launcher.searching") : root.t("launcher.empty." + root.parsed.mode)
            }

            // --- the menu of an app ---------------------------------------------
            MouseArea {
                anchors.fill: parent
                visible: root.menu !== null
                onClicked: root.menu = null
            }

            Item {
                id: menuCard

                anchors.top: parent.top
                x: root.fullscreen ? (parent.width - width) / 2 : parent.width - width
                width: Math.min(parent.width, VitrailTokens.size("display") * 8)
                height: menuColumn.implicitHeight + 2 * VitrailTokens.gap("sm")
                visible: root.menu !== null

                VitrailSurface {
                    anchors.fill: parent
                    opacityLevel: VitrailTokens.opacity
                }

                Column {
                    id: menuColumn

                    x: VitrailTokens.gap("sm")
                    y: VitrailTokens.gap("sm")
                    width: parent.width - 2 * VitrailTokens.gap("sm")

                    Repeater {
                        model: root.menu ? root.menu.rows : []

                        delegate: ResultRow {
                            id: option

                            required property var modelData
                            required property int index

                            width: menuColumn.width
                            title: option.modelData.title
                            appIcon: option.modelData.appIcon || ""
                            glyph: option.modelData.glyph
                            selected: root.menuCurrent === option.index
                            onHoveredChanged: if (option.hovered) root.menuCurrent = option.index
                            onClicked: root.carryOut(option.modelData.run, false)
                        }
                    }
                }
            }
        }

        // Keys, for whoever has not learned them.
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: root.narrowWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: 0
            spacing: VitrailTokens.gap("md")

            component Hint: Row {
                property string keys: ""
                property string label: ""

                spacing: VitrailTokens.gap("xs")

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: cap.implicitWidth + VitrailTokens.gap("sm")
                    height: cap.implicitHeight + VitrailTokens.gap("xs")

                    Rectangle {
                        anchors.fill: parent
                        radius: VitrailTokens.radius / 3
                        color: VitrailTokens.color("foreground")
                        opacity: 0.12
                    }

                    VitrailText {
                        id: cap

                        anchors.centerIn: parent
                        variant: "label"
                        color: VitrailTokens.color("foreground")
                        opacity: 1
                        text: parent.parent.keys
                    }
                }

                VitrailText {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "label"
                    text: parent.label
                }
            }

            Hint { keys: "↑↓←→"; label: root.t("launcher.hint.navigate") }
            Hint { keys: "↵"; label: root.t("launcher.hint.open") }
            Hint { keys: "Tab"; label: root.t("launcher.hint.mode") }
            Hint { keys: "Ctrl+K"; label: root.t("launcher.hint.actions") }
            Hint { keys: "Esc"; label: root.t("launcher.hint.close") }
        }
    }

    VitrailTooltip {
        id: tip

        z: 10
        active: root.tipTarget !== null
        opacityLevel: VitrailTokens.opacity
        onWidthChanged: root.placeTip()
        onHeightChanged: root.placeTip()
    }
}
