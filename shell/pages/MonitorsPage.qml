import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "../../kit"
import "../../kit/base"
import "../../bar/effects.js" as Effects
import "../../bar/barview.js" as BarView
import "../monitorsview.js" as View
import "../../bar/wallpapermonitors.js" as Wallpaper

// Monitors category: one card per Hyprland output, with the mode, scale,
// rotation, position, mirror and enabled state the user wants it to keep.
//
// The window cannot run commands: `bin/vitrail-settings` injects the live
// state as `--monitors`, and `vitrail-monitors apply` rewrites
// monitor-state.json after every change (the path unit runs it through
// apply-settings.sh). The page polls that file while it waits, then adopts it.
// The overrides are one JSON document in monitors.ini; an output without an
// entry follows Hyprland's defaults.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string configDir: ""
    // { available, monitors: [...], overrides } as injected at launch.
    property var monitors: ({ available: false, monitors: [] })

    property var live: page.monitors && page.monitors.monitors ? page.monitors.monitors : []
    property bool available: page.monitors && page.monitors.available === true
    // A change is on its way to the compositor; poll until the state answers.
    property bool pending: false
    property double sent: 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    // --- the wallpaper of one output -----------------------------------------
    readonly property string library: page.prefs.wallpaperDir || page.configDir + "/wallpapers"
    readonly property var imageFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
    readonly property var videoFilters: ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.avi"]

    // The pictures of the library, images first: a per-monitor effect only
    // makes sense over a picture, but a video may fill one output. A folder
    // may report its first count while the page is still being built.
    property bool ready: false

    function syncPictures() {
        if (!page.ready)
            return
        pictures.clear()
        var models = [imageFiles, videoFiles]
        models.forEach(function (model) {
            for (var i = 0; i < model.count; i++)
                pictures.append({ path: model.get(i, "filePath") })
        })
    }

    function entryOf(name) {
        return Wallpaper.of(page.prefs.wallpaperMonitors || "", name)
    }

    // The picture this output shows: its own, or the global one.
    function pictureOf(name) {
        return page.entryOf(name).wallpaper || page.prefs.wallpaper || ""
    }

    function canEffect(name) {
        return Effects.isImage(page.pictureOf(name))
    }

    function pictureOptions(name) {
        var out = [{ key: "", label: page.t("wallpaper.monitors.global") }]
        var seen = {}
        var chosen = page.entryOf(name).wallpaper
        for (var i = 0; i < pictures.count; i++) {
            var path = pictures.get(i).path
            seen[path] = true
            out.push({ key: path, label: path.split("/").pop() })
        }
        if (chosen !== "" && !seen[chosen])
            out.push({ key: chosen, label: chosen.split("/").pop() })
        return out
    }

    function effectOptions() {
        var out = [{ key: "", label: page.t("wallpaper.monitors.effect.global") }]
        Effects.NAMES.forEach(function (name) {
            out.push({ key: name, label: page.t("wallpaper.effect." + name) })
        })
        return out
    }

    function setWallpaper(monitor, patch) {
        var text = Wallpaper.update(page.prefs.wallpaperMonitors || "", monitor.name, patch)
        if (text === null)
            return
        page.prefs.wallpaperMonitors = text
    }

    FolderListModel {
        id: imageFiles

        folder: "file://" + page.library + "/images"
        nameFilters: page.imageFilters
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: page.syncPictures()
    }

    FolderListModel {
        id: videoFiles

        folder: "file://" + page.library + "/videos"
        nameFilters: page.videoFilters
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: page.syncPictures()
    }

    ListModel {
        id: pictures
    }

    function document() {
        return View.parse(page.prefs.monitorOverrides || "")
    }

    // What the card shows: the saved override, or the live state.
    function spec(monitor) {
        return View.override(page.document(), monitor.name) || View.seed(monitor)
    }

    function set(name, patch, monitor) {
        var text = View.update(page.prefs.monitorOverrides || "", name, patch, monitor)
        if (text === null)
            return
        page.prefs.monitorOverrides = text
        page.wait()
    }

    function reset(name) {
        var text = View.remove(page.prefs.monitorOverrides || "", name)
        if (text === null)
            return
        page.prefs.monitorOverrides = text
        page.wait()
    }

    // The bar's own overrides: one JSON object keyed by output name. Only the
    // edge and the style may differ from the global bar.
    function barOf(monitor) {
        return BarView.override(BarView.document(page.prefs.barMonitors || ""), monitor.name)
    }

    function barEdgeOf(monitor) {
        var entry = page.barOf(monitor)
        return entry && typeof entry.edge === "string" && entry.edge !== ""
               ? entry.edge : (page.prefs.barEdge || "left")
    }

    function barStyleOf(monitor) {
        var entry = page.barOf(monitor)
        return entry && typeof entry.style === "string" ? entry.style : ""
    }

    function setBar(monitor, patch) {
        var text = BarView.update(page.prefs.barMonitors || "", monitor.name, patch)
        if (text === null)
            return
        page.prefs.barMonitors = text
    }

    // A typed position, committed when the field is accepted or loses focus.
    function setPosition(monitor, x, y) {
        var left = Number(x)
        var top = Number(y)
        if (isNaN(left) || isNaN(top))
            return
        page.set(monitor.name, { position: Math.round(left) + "x" + Math.round(top) }, monitor)
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
        request.open("GET", "file://" + page.configDir + "/monitor-state.json")
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
        page.live = data.monitors || []
        page.available = data.available === true
        page.pending = false
        poller.stop()
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
        onTriggered: page.pending = false
    }

    Component.onCompleted: {
        page.ready = true
        page.syncPictures()
        page.poll()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        Text {
            Layout.fillWidth: true
            text: page.t("monitors.help")
            color: page.palette.muted
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: !page.available
            text: page.t("monitors.unavailable")
            color: page.palette.muted
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
            wrapMode: Text.WordWrap
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

                Repeater {
                    model: page.live

                    delegate: Section {
                        id: card

                        required property var modelData

                        readonly property var shown: page.spec(card.modelData)
                        readonly property var place: View.position(card.shown)
                        readonly property var others: View.others(page.live, card.modelData.name)

                        Layout.fillWidth: true
                        title: card.modelData.name
                        icon: "monitor"
                        badge: page.t("badge.live")
                        foreground: page.palette.foreground
                        accent: page.palette.primary

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.description
                            color: page.palette.muted
                            font.pixelSize: 12
                            font.family: VitrailTokens.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.t("monitors.current") + " " + View.label(card.modelData)
                            color: page.palette.muted
                            font.pixelSize: 12
                            font.family: VitrailTokens.fontFamily
                        }

                        VitrailSettingRow {
                            icon: "power_settings_new"
                            label: page.t("monitors.enabled")
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSwitch {
                                checked: !card.shown.disabled
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onToggled: function (value) {
                                    page.set(card.modelData.name, { disabled: !value }, card.modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("md")
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1

                            VitrailSelect {
                                Layout.fillWidth: true
                                label: page.t("monitors.mode")
                                current: card.shown.mode
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                options: View.modes(card.modelData).map(function (mode) {
                                    return {
                                        key: mode,
                                        label: mode === "preferred" ? page.t("monitors.mode.preferred")
                                                                    : View.modeLabel(mode)
                                    }
                                })
                                onSelected: function (key) {
                                    page.set(card.modelData.name, { mode: key }, card.modelData)
                                }
                            }

                            VitrailSelect {
                                Layout.preferredWidth: 150
                                label: page.t("monitors.rotation")
                                current: String(View.degreesOf(card.shown.transform))
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                options: [
                                    { key: "0", label: "0°" },
                                    { key: "90", label: "90°" },
                                    { key: "180", label: "180°" },
                                    { key: "270", label: "270°" }
                                ]
                                onSelected: function (key) {
                                    page.set(card.modelData.name, { transform: View.transformOf(key) },
                                             card.modelData)
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
                            value: card.shown.scale
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onMoved: page.set(card.modelData.name, { scale: value }, card.modelData)
                        }

                        VitrailSettingRow {
                            icon: "open_with"
                            label: page.t("monitors.position.auto")
                            description: page.t("monitors.position.help")
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSwitch {
                                checked: card.place.auto
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onToggled: function (value) {
                                    page.set(card.modelData.name, {
                                        position: value ? "auto" : card.place.x + "x" + card.place.y
                                    }, card.modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("md")
                            enabled: !card.shown.disabled && !card.place.auto
                            opacity: card.shown.disabled || card.place.auto ? 0.35 : 1

                            VitrailField {
                                id: posX

                                Layout.fillWidth: true
                                label: page.t("monitors.position.x")
                                text: String(card.place.x)
                                onAccepted: page.setPosition(card.modelData, text, posY.text)
                                onActiveFocusChanged: {
                                    if (!activeFocus)
                                        page.setPosition(card.modelData, text, posY.text)
                                }
                            }

                            VitrailField {
                                id: posY

                                Layout.fillWidth: true
                                label: page.t("monitors.position.y")
                                text: String(card.place.y)
                                onAccepted: page.setPosition(card.modelData, posX.text, text)
                                onActiveFocusChanged: {
                                    if (!activeFocus)
                                        page.setPosition(card.modelData, posX.text, text)
                                }
                            }
                        }

                        VitrailSelect {
                            Layout.fillWidth: true
                            label: page.t("monitors.mirror")
                            current: card.shown.mirror
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            options: [{ key: "", label: page.t("monitors.mirror.none") }].concat(
                                card.others.map(function (name) { return { key: name, label: name } }))
                            onSelected: function (key) {
                                page.set(card.modelData.name, { mirror: key }, card.modelData)
                            }
                        }

                        VitrailSettingRow {
                            icon: "wallpaper"
                            label: page.t("wallpaper.monitors.wallpaper")
                            description: page.t("wallpaper.monitors.wallpaper.help")
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSelect {
                                Layout.preferredWidth: 220
                                current: page.entryOf(card.modelData.name).wallpaper
                                options: page.pictureOptions(card.modelData.name)
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                panel: page.palette.surfaceHigh
                                onSelected: function (key) {
                                    page.setWallpaper(card.modelData, { wallpaper: key })
                                }
                            }
                        }

                        VitrailSettingRow {
                            icon: "auto_awesome"
                            label: page.t("wallpaper.monitors.effect")
                            description: page.canEffect(card.modelData.name) ? ""
                                         : page.t("wallpaper.monitors.effect.imageOnly")
                            enabled: !card.shown.disabled && page.canEffect(card.modelData.name)
                            opacity: card.shown.disabled || !page.canEffect(card.modelData.name) ? 0.35 : 1
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSelect {
                                Layout.preferredWidth: 220
                                current: page.entryOf(card.modelData.name).effect
                                options: page.effectOptions()
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                panel: page.palette.surfaceHigh
                                onSelected: function (key) {
                                    page.setWallpaper(card.modelData, { effect: key })
                                }
                            }
                        }

                        VitrailSettingRow {
                            icon: "dock_to_left"
                            label: page.t("bar.monitors.edge")
                            description: page.t("bar.monitors.help")
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSegmented {
                                options: [
                                    { key: "left", label: page.t("bar.edge.left"), icon: "left_panel_open" },
                                    { key: "top", label: page.t("bar.edge.top"), icon: "top_panel_open" },
                                    { key: "right", label: page.t("bar.edge.right"), icon: "right_panel_open" },
                                    { key: "bottom", label: page.t("bar.edge.bottom"), icon: "bottom_panel_open" }
                                ]
                                current: page.barEdgeOf(card.modelData)
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onSelected: function (key) {
                                    page.setBar(card.modelData, { edge: key })
                                }
                            }
                        }

                        VitrailSettingRow {
                            icon: "style"
                            label: page.t("bar.monitors.style")
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSelect {
                                Layout.preferredWidth: 180
                                current: page.barStyleOf(card.modelData)
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                options: [{ key: "", label: page.t("bar.monitors.style.global") }].concat(
                                    Object.keys(VitrailVariants.bar).map(function (key) {
                                        return { key: key, label: page.t("bar.style." + key) }
                                    }))
                                onSelected: function (key) {
                                    page.setBar(card.modelData, { style: key })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            Text {
                                Layout.fillWidth: true
                                text: page.t("monitors.reset.help")
                                color: page.palette.muted
                                font.pixelSize: 12
                                font.family: VitrailTokens.fontFamily
                                wrapMode: Text.WordWrap
                            }

                            VitrailButton {
                                text: page.t("monitors.reset")
                                variant: "outlined"
                                tone: "secondary"
                                onClicked: page.reset(card.modelData.name)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.live.length === 0
                    text: page.t("monitors.none")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
