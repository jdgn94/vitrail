import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import Qt.labs.folderlistmodel
import "../../kit"
import "../../kit/base"
import "../../kit/composed"
import "../../bar/effects.js" as Effects
import "../../bar/wallpapermonitors.js" as Wallpaper
import "../reorder.js" as Reorder

// Wallpaper category: the settings shared by every kind (fit, rotation, the
// colour of the system) on top, then one block per output for its own picture
// and effect, then the library with one folder per kind (images, videos). The
// selection holds one kind only: several of it take turns, in the order of the
// strip; picking another kind starts over.
//
// The library is Vitrail's own folder in ~/.config, apart from the user's
// pictures. This window cannot copy or delete files: it writes a request
// (wallpaperImport / wallpaperRemove = "<nonce>|path…") that
// `vitrail wallpaper sync` carries out.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string configDir: ""
    // Where apply-settings leaves the effect previews (the shell's cache).
    property string cacheDir: ""
    // Hyprland's outputs as injected at launch; the per-monitor block below
    // only matters when there is more than one.
    property var monitors: ({ available: false, monitors: [] })

    readonly property var live: page.monitors && page.monitors.monitors ? page.monitors.monitors : []

    readonly property var fitIcons: ({ frame: "filter_frames", screen: "fullscreen" })

    readonly property string library: page.prefs.wallpaperDir || page.configDir + "/wallpapers"
    readonly property var kinds: [
        { key: "image", folder: "images", icon: "image", filters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"] },
        { key: "video", folder: "videos", icon: "movie", filters: ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.avi"] }
    ]
    readonly property var browsed: page.kinds.find(function (kind) { return kind.key === page.browse }) || page.kinds[0]
    // The kind on screen; an older single wallpaper still counts as one, and an
    // unknown kind (an old SVG type) reads as none.
    readonly property string activeKind: {
        var kind = page.prefs.wallpaperType || page.kindOf(page.prefs.wallpaper)
        return page.kinds.some(function (entry) { return entry.key === kind }) ? kind : ""
    }
    readonly property var selection: {
        // An old selection may still name an SVG: the strip never shows it.
        var list = (page.prefs.wallpaperSelection || "").split("|").filter(function (path) { return path !== "" && !/\.svg$/i.test(path) })
        return list.length === 0 && page.prefs.wallpaper && !/\.svg$/i.test(page.prefs.wallpaper)
               ? [page.prefs.wallpaper] : list
    }
    // Material's main colours, one per hue (the 500 tones): a palette, not a
    // set of steps.
    readonly property var materialColors: [
        "#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3",
        "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39",
        "#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#795548", "#9e9e9e", "#607d8b"
    ]
    // A system colour that is none of the presets is the custom one.
    readonly property bool customColor: page.prefs.systemColor !== ""
                                        && page.materialColors.indexOf(String(page.prefs.systemColor).toLowerCase()) < 0
    property string browse: page.activeKind || "image"
    // Minutes between wallpapers; a value from an older slider stays listed.
    readonly property var intervals: [1, 5, 10, 15, 30, 60, 120, 360, 720, 1440]
    readonly property int intervalNow: Number(page.prefs.wallpaperInterval) || 30
    readonly property var intervalOptions: {
        var list = page.intervals.indexOf(page.intervalNow) >= 0
                   ? page.intervals : page.intervals.concat([page.intervalNow]).sort(function (a, b) { return a - b })
        return list.map(function (minutes) {
            return { key: String(minutes), label: page.duration(minutes) }
        })
    }

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function duration(minutes) {
        return minutes % 60 === 0 ? page.t("wallpaper.interval.hour").replace("%1", minutes / 60)
                                  : page.t("wallpaper.interval.min").replace("%1", minutes)
    }

    function request(paths) {
        return [Date.now()].concat(paths).join("|")
    }

    // Leaves the selection first, so nothing points at the file once it goes.
    function remove(path) {
        var list = page.selection.filter(function (item) { return item !== path })
        page.prefs.wallpaperSelection = list.join("|")
        if (page.prefs.wallpaper === path)
            page.prefs.wallpaper = list.length > 0 ? list[0] : ""
        if (list.length === 0)
            page.prefs.wallpaperType = ""
        page.prefs.wallpaperRemove = page.request([path])
    }

    function kindOf(path) {
        if (/\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(path || ""))
            return "video"
        return path ? "image" : ""
    }

    // --- one output's own picture -------------------------------------------
    // The library files, images first: an effect only makes sense over a
    // picture, but a video may fill one output.
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

    // Bumped after a picture changes: the previews of the new one land a few
    // seconds later and a new URL is the only way to make QML reload them.
    property int previewRevision: 0

    // The effect previews are rendered from the picture the whole screen
    // shows; apply-settings publishes one per recipe under previews/global.
    // The picker builds its own `file://` URL, so this is a plain path.
    function previewArt(effect) {
        if (page.cacheDir === "")
            return ""
        return page.cacheDir + "/previews/global/" + effect + ".png?v=" + page.previewRevision
    }

    function effectOptions() {
        return Effects.NAMES.map(function (name) {
            return {
                key: name,
                label: page.t("wallpaper.effect." + name),
                icons: [page.previewArt(name)]
            }
        })
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
        nameFilters: page.kinds[0].filters
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: page.syncPictures()
    }

    FolderListModel {
        id: videoFiles

        folder: "file://" + page.library + "/videos"
        nameFilters: page.kinds[1].filters
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: page.syncPictures()
    }

    ListModel {
        id: pictures
    }

    Component.onCompleted: {
        page.ready = true
        page.syncPictures()
    }

    // A wallpaper's picture inside a rounded tile: the whole image fits (never
    // cropped), centred on the tile colour, and the corners really clip it.
    // Videos keep a placeholder.
    component Thumb: Item {
        id: thumb

        property string path: ""
        readonly property string kind: page.kindOf(thumb.path)
        readonly property real corner: VitrailTokens.radius * 0.75
        property string preview: thumb.kind === "image" ? "file://" + thumb.path : ""

        Item {
            id: art

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                color: page.palette.surfaceHigh
            }

            Image {
                anchors.fill: parent
                visible: thumb.kind !== "video"
                source: thumb.preview
                sourceSize: Qt.size(thumb.width * 2, thumb.height * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Column {
                anchors.centerIn: parent
                visible: thumb.kind === "video"
                spacing: 2

                VitrailIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "play_circle"
                    color: page.palette.foreground
                    pixelSize: 30
                }

                Text {
                    width: thumb.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    text: thumb.path.split("/").pop()
                    color: page.palette.muted
                    elide: Text.ElideMiddle
                    font.pixelSize: 10
                    font.family: VitrailTokens.fontFamily
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: art
            maskEnabled: true
            maskSource: mask
        }

        Item {
            id: mask

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: thumb.corner
                color: "black"
            }
        }
    }

    // Automatic: the same circle as the presets, carrying the first letter of
    // its own name.
    component AutoSwatch: Item {
        id: automatic

        readonly property bool chosen: page.prefs.systemColor === ""

        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: page.palette.surfaceHigh
            border.width: automatic.chosen ? 3 : 1
            border.color: automatic.chosen ? page.palette.foreground : page.palette.muted
        }

        Text {
            anchors.centerIn: parent
            text: page.t("wallpaper.systemColor.auto").charAt(0)
            color: page.palette.foreground
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: VitrailTokens.fontFamily
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.prefs.systemColor = ""
        }
    }

    // One Material colour: a circle, ringed when it is the one in use.
    component Swatch: Rectangle {
        id: swatch

        property string value: ""

        readonly property bool chosen: page.prefs.systemColor !== ""
                                        && String(page.prefs.systemColor).toLowerCase() === swatch.value.toLowerCase()

        width: 26
        height: 26
        radius: 13
        color: swatch.value
        border.width: swatch.chosen ? 3 : 0
        border.color: page.palette.foreground

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.prefs.systemColor = swatch.value
        }
    }

    // The custom colour: the palette glyph until one is picked, then the
    // colour itself, ringed like a preset.
    component CustomSwatch: Item {
        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: page.customColor ? String(page.prefs.systemColor) : page.palette.surfaceHigh
            border.width: page.customColor ? 3 : 1
            border.color: page.customColor ? page.palette.foreground : page.palette.muted
        }

        VitrailIcon {
            anchors.centerIn: parent
            visible: !page.customColor
            icon: "palette"
            color: page.palette.foreground
            pixelSize: 15
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: colorDialog.show()
        }
    }

    // Same kind: add or remove it (one always stays). Another kind: it
    // becomes the whole selection.
    function choose(path, kind) {
        var list = page.selection.slice()
        if (page.activeKind !== kind) {
            list = [path]
        } else {
            var at = list.indexOf(path)
            if (at >= 0 && list.length === 1)
                return
            if (at >= 0)
                list.splice(at, 1)
            else
                list.push(path)
        }
        page.prefs.wallpaperType = kind
        page.prefs.wallpaperSelection = list.join("|")
        if (list.indexOf(path) >= 0)
            page.prefs.wallpaper = path
        else if (page.prefs.wallpaper === path)
            page.prefs.wallpaper = list[0]
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

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
                    icon: "tune"
                    title: page.t("wallpaper.settings")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "fit_screen"
                        label: page.t("wallpaper.fit")
                        description: page.t("wallpaper.fit.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: Object.keys(VitrailVariants.wallpaper).map(function (key) {
                                return { key: key, icon: page.fitIcons[key], label: page.t("wallpaper.fit." + key) }
                            })
                            current: page.prefs.wallpaperMode || VitrailStyle.defaults.wallpaper
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.wallpaperMode = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "auto_awesome"
                        label: page.t("wallpaper.effect")
                        description: page.canEffect("") ? page.t("wallpaper.effect.help")
                                                         : page.t("wallpaper.effect.imageOnly")
                        enabled: page.canEffect("")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "effectPicker"
                            Layout.preferredWidth: 220
                            label: page.t("wallpaper.effect")
                            triggerPreview: false
                            cellArtWidth: 112
                            cellArtHeight: 64
                            cellWidth: 132
                            cellHeight: 108
                            current: Effects.of(page.prefs.wallpaperEffect)
                            options: page.effectOptions()
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: function (key) { page.prefs.wallpaperEffect = key }
                        }
                    }

                    // Only the drawn styles have a detail to choose: how big
                    // the dots are, how many characters span the picture.
                    VitrailSettingRow {
                        objectName: "effectDetailRow"
                        visible: Effects.detailed(page.prefs.wallpaperEffect)
                        icon: "grid_view"
                        label: page.t("wallpaper.effectDetail")
                        description: page.t("wallpaper.effectDetail.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: ["fine", "normal", "bold"].map(function (key) {
                                return { key: key, label: page.t("wallpaper.effectDetail." + key) }
                            })
                            current: Effects.detail(page.prefs.wallpaperEffectDetail)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.wallpaperEffectDetail = key
                        }
                    }

                    VitrailSettingRow {
                        objectName: "pauseFullscreenRow"
                        icon: "fullscreen"
                        label: page.t("wallpaper.pauseFullscreen")
                        description: page.t("wallpaper.pauseFullscreen.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "pauseFullscreenSwitch"
                            checked: page.prefs.wallpaperPauseFullscreen
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.wallpaperPauseFullscreen = value
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "auto_awesome"
                        label: page.t("wallpaper.transition")
                        description: page.t("wallpaper.transition.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 220
                            current: page.prefs.wallpaperTransition || "random"
                            options: ["random", "none", "fade", "ink", "outline"].map(function (name) {
                                return { key: name, label: page.t("wallpaper.transition." + name) }
                            })
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.wallpaperTransition = key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("wallpaper.transition.time")
                        suffix: " ms"
                        from: VitrailTokens.ranges.transition.min
                        to: VitrailTokens.ranges.transition.max
                        stepSize: VitrailTokens.ranges.transition.step
                        snap: true
                        value: Number(page.prefs.wallpaperTransitionTime)
                               || VitrailTokens.ranges.transition.value
                        enabled: (page.prefs.wallpaperTransition || "random") !== "none"
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.wallpaperTransitionTime = value
                    }

                    // The colour of the whole system: automatic, a Material
                    // hue, or one of the user's own. The swatches wrap, so a
                    // narrow window keeps them in rows.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        VitrailSettingRow {
                            icon: "colorize"
                            label: page.t("wallpaper.systemColor")
                            description: page.t("wallpaper.systemColor.help")
                            foreground: page.palette.foreground
                            muted: page.palette.muted
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.leftMargin: 32
                            spacing: VitrailTokens.gap("xs")

                            AutoSwatch {
                                objectName: "autoColor"
                            }

                            Repeater {
                                model: page.materialColors

                                delegate: Swatch {
                                    required property string modelData

                                    value: modelData
                                }
                            }

                            CustomSwatch {
                                objectName: "customColor"
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "shuffle"
                        label: page.t("wallpaper.order")
                        description: page.t("wallpaper.order.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "sequential", icon: "format_list_numbered", label: page.t("wallpaper.order.sequential") },
                                { key: "random", icon: "shuffle", label: page.t("wallpaper.order.random") }
                            ]
                            current: page.prefs.wallpaperOrder
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.wallpaperOrder = key
                        }
                    }

                    VitrailSelect {
                        Layout.fillWidth: true
                        label: page.t("wallpaper.interval")
                        options: page.intervalOptions
                        current: String(page.intervalNow)
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        panel: page.palette.surfaceHigh
                        onSelected: page.prefs.wallpaperInterval = Number(key)
                    }

                    // The turn of each selected wallpaper: drag to reorder.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: page.selection.length > 1
                        spacing: VitrailTokens.gap("sm")

                        VitrailSettingRow {
                            icon: "swap_horiz"
                            label: page.t("wallpaper.sequence")
                            description: page.prefs.wallpaperOrder === "random"
                                         ? page.t("wallpaper.sequence.random") : page.t("wallpaper.sequence.help")
                            foreground: page.palette.foreground
                            muted: page.palette.muted
                        }

                        Item {
                            id: strip

                            objectName: "strip"

                            readonly property real thumbW: 112
                            readonly property real thumbH: 70
                            readonly property real gap: VitrailTokens.gap("sm")
                            readonly property int columns: Math.max(1, Math.floor((strip.width + strip.gap) / (strip.thumbW + strip.gap)))
                            readonly property int rows: Math.ceil(page.selection.length / strip.columns)
                            // The order shown while a chip is being dragged.
                            property var dragOrder: null
                            readonly property var shown: strip.dragOrder || page.selection

                            // The pictures in the strip, by identity: a reorder moves
                            // them, only a different selection builds new ones.
                            function sync() {
                                var have = []
                                for (var i = 0; i < members.count; i++)
                                    have.push(members.get(i).path)
                                if (have.slice().sort().join("|") === page.selection.slice().sort().join("|"))
                                    return
                                members.clear()
                                page.selection.forEach(function (path) { members.append({ path: path }) })
                            }

                            function commit() {
                                if (strip.dragOrder && strip.dragOrder.join("|") !== page.selection.join("|"))
                                    page.prefs.wallpaperSelection = strip.dragOrder.join("|")
                                strip.dragOrder = null
                            }

                            Layout.fillWidth: true
                            implicitHeight: strip.rows * (strip.thumbH + strip.gap) - strip.gap
                            Component.onCompleted: strip.sync()

                            ListModel {
                                id: members
                            }

                            Connections {
                                target: page

                                function onSelectionChanged() {
                                    strip.sync()
                                }
                            }

                            Repeater {
                                model: members

                                delegate: Item {
                                    id: chip

                                    required property string path

                                    readonly property int slot: strip.shown.indexOf(chip.path)
                                    readonly property real slotX: (chip.slot % strip.columns) * (strip.thumbW + strip.gap)
                                    readonly property real slotY: Math.floor(chip.slot / strip.columns) * (strip.thumbH + strip.gap)

                                    objectName: "chip"
                                    width: strip.thumbW
                                    height: strip.thumbH
                                    z: grab.active ? 1 : 0
                                    scale: grab.active ? 1.06 : 1

                                    Binding on x { when: !grab.active; value: chip.slotX }
                                    Binding on y { when: !grab.active; value: chip.slotY }

                                    Behavior on x { enabled: !grab.active; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
                                    Behavior on y { enabled: !grab.active; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast") } }

                                    Thumb {
                                        anchors.fill: parent
                                        path: chip.path
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: VitrailTokens.radius * 0.75
                                        color: "transparent"
                                        border.width: grab.active ? 2 : 0
                                        border.color: page.palette.primary
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: VitrailTokens.gap("xs")
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: page.palette.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(chip.slot + 1)
                                            color: page.palette.accentForeground
                                            font.family: VitrailTokens.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    HoverHandler {
                                        cursorShape: grab.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    }

                                    DragHandler {
                                        id: grab

                                        xAxis.minimum: 0
                                        xAxis.maximum: Math.max(0, strip.width - strip.thumbW)
                                        yAxis.minimum: 0
                                        yAxis.maximum: Math.max(0, strip.height - strip.thumbH)
                                        onActiveChanged: if (!grab.active) strip.commit()
                                        onTranslationChanged: {
                                            if (!grab.active)
                                                return
                                            var column = Math.floor((chip.x + strip.thumbW / 2) / (strip.thumbW + strip.gap))
                                            var row = Math.floor((chip.y + strip.thumbH / 2) / (strip.thumbH + strip.gap))
                                            var target = Math.max(0, Math.min(page.selection.length - 1, row * strip.columns + column))
                                            strip.dragOrder = Reorder.move(page.selection, page.selection.indexOf(chip.path), target)
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                // One block per output, where a picture belongs: its own
                // picture and effect, with the global choice as the default.
                Repeater {
                    model: page.live

                    delegate: Section {
                        required property var modelData

                        Layout.fillWidth: true
                        visible: page.live.length > 1
                        icon: "monitor"
                        title: modelData.name
                        foreground: page.palette.foreground
                        accent: page.palette.primary

                        VitrailSettingRow {
                            icon: "wallpaper"
                            label: page.t("wallpaper.monitors.wallpaper")
                            description: page.t("wallpaper.monitors.wallpaper.help")
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSelect {
                                Layout.preferredWidth: VitrailTokens.size("display") * 10
                                current: page.entryOf(modelData.name).wallpaper
                                options: page.pictureOptions(modelData.name)
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                panel: page.palette.surfaceHigh
                                onSelected: function (key) {
                                    page.setWallpaper(modelData, { wallpaper: key })
                                }
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    icon: "photo_library"
                    title: page.t("wallpaper.library")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailTabs {
                        Layout.fillWidth: true
                        tabs: page.kinds.map(function (kind) {
                            return { key: kind.key, icon: kind.icon, label: page.t("wallpaper.kind." + kind.key) }
                        })
                        current: page.browse
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.browse = key
                    }

                    VitrailSettingRow {
                        icon: "folder"
                        label: page.t("wallpaper.kindHelp." + page.browse)
                        description: page.library + "/" + page.browsed.folder
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: "tonal"
                            icon: "add_photo_alternate"
                            text: page.t("wallpaper.add")
                            onClicked: picker.open()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: files.count === 0
                        text: page.t("wallpaper.empty")
                        color: page.palette.muted
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        Repeater {
                            model: FolderListModel {
                                id: files

                                folder: "file://" + page.library + "/" + page.browsed.folder
                                nameFilters: page.browsed.filters
                                showDirs: false
                                sortField: FolderListModel.Name
                            }

                            delegate: Item {
                                id: tile

                                required property string filePath
                                required property string fileName

                                readonly property int order: page.activeKind === page.browse
                                                             ? page.selection.indexOf(tile.filePath) : -1
                                readonly property bool chosen: tile.order >= 0
                                readonly property bool onScreen: page.prefs.wallpaper === tile.filePath
                                // First click arms the delete button, the second deletes.
                                property bool confirming: false

                                width: 168
                                height: 104

                                Thumb {
                                    anchors.fill: parent
                                    path: tile.filePath
                                }

                                // Selection ring, drawn over the picture.
                                Rectangle {
                                    anchors.fill: parent
                                    radius: VitrailTokens.radius * 0.75
                                    color: "transparent"
                                    border.width: tile.chosen ? 3 : (hover.hovered ? 1 : 0)
                                    border.color: tile.chosen ? page.palette.primary : page.palette.foreground

                                    Behavior on border.width { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                                }

                                // Rotation order; the one on screen shows a filled check.
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: VitrailTokens.gap("xs")
                                    visible: tile.chosen
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: page.palette.primary

                                    Text {
                                        anchors.centerIn: parent
                                        text: tile.onScreen ? "check" : String(tile.order + 1)
                                        color: page.palette.accentForeground
                                        font.family: tile.onScreen ? VitrailTokens.iconFamily : VitrailTokens.fontFamily
                                        font.pixelSize: tile.onScreen ? 16 : 12
                                        font.weight: Font.DemiBold
                                    }
                                }

                                HoverHandler {
                                    id: hover

                                    onHoveredChanged: if (!hovered) tile.confirming = false
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.choose(tile.filePath, page.browse)
                                }

                                VitrailButton {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: VitrailTokens.gap("xs")
                                    visible: hover.hovered || tile.confirming
                                    size: "sm"
                                    variant: tile.confirming ? "flat" : "tonal"
                                    tone: "error"
                                    icon: tile.confirming ? "delete_forever" : "delete"
                                    text: tile.confirming ? page.t("wallpaper.delete") : ""
                                    onClicked: {
                                        if (tile.confirming)
                                            page.remove(tile.filePath)
                                        tile.confirming = !tile.confirming
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    FileDialog {
        id: picker

        title: page.t("wallpaper.add")
        fileMode: FileDialog.OpenFiles
        nameFilters: [page.t("wallpaper.kind." + page.browse) + " (" + page.browsed.filters.join(" ") + ")"]
        onAccepted: page.prefs.wallpaperImport = page.request(picker.selectedFiles.map(function (url) {
            return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
        }))
    }

    // The custom system colour: the kit's colour picker in a modal over the page.
    Popup {
        id: colorDialog

        function show() {
            colorPick.adopt(page.prefs.systemColor !== "" ? String(page.prefs.systemColor)
                                                       : String(page.palette.primary))
            colorDialog.open()
        }

        function accept() {
            if (!colorPick.valid)
                return
            page.prefs.systemColor = colorPick.hex
            colorDialog.close()
        }

        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        // No scrim: the platform style's dim washes a dark window white.
        dim: false
        padding: VitrailTokens.gap("lg")
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: VitrailTokens.colorPicker.dialog + 2 * colorDialog.padding
        height: contentItem.implicitHeight + 2 * colorDialog.padding

        onOpened: colorPick.focusCode()

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: VitrailTokens.motion.smooth.scale; to: 1; duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: VitrailTokens.duration("fast") }
        }

        background: Rectangle {
            radius: VitrailTokens.radius
            color: page.palette.surfaceHigh
            border.width: 1
            border.color: Qt.rgba(page.palette.foreground.r, page.palette.foreground.g, page.palette.foreground.b, 0.12)
        }

        contentItem: ColumnLayout {
            spacing: VitrailTokens.gap("md")

            Keys.onReturnPressed: colorDialog.accept()
            Keys.onEnterPressed: colorDialog.accept()

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: page.t("wallpaper.systemColor.custom")
                elide: Text.ElideRight
            }

            VitrailColorPicker {
                id: colorPick

                Layout.fillWidth: true
                placeholder: page.t("wallpaper.systemColor.hex")
                onEscaped: colorDialog.close()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                Item {
                    Layout.fillWidth: true
                }

                VitrailButton {
                    variant: "outlined"
                    tone: "secondary"
                    size: "sm"
                    text: page.t("dialog.cancel")
                    onClicked: colorDialog.close()
                }

                VitrailButton {
                    variant: "flat"
                    size: "sm"
                    enabled: colorPick.valid
                    text: page.t("wallpaper.systemColor.use")
                    onClicked: colorDialog.accept()
                }
            }
        }
    }

    // The previews of a new picture land a few seconds after the preference
    // (apply-settings runs magick): a new revision is the only way to make QML
    // reload a picture it already showed.
    Timer {
        id: previewTimer

        interval: 4000
        repeat: true

        property int ticks: 0

        onTriggered: {
            page.previewRevision++
            previewTimer.ticks++
            if (previewTimer.ticks >= 3)
                previewTimer.stop()
        }
    }

    Connections {
        target: page.prefs

        function onWallpaperChanged() {
            previewTimer.ticks = 0
            previewTimer.restart()
        }

        function onWallpaperMonitorsChanged() {
            previewTimer.ticks = 0
            previewTimer.restart()
        }
    }
}
