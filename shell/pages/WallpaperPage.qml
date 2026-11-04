import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import Qt.labs.folderlistmodel
import "../../kit"
import "../../kit/base"
import "../../kit/effects.js" as Effects
import "../reorder.js" as Reorder

// Wallpaper category: the settings shared by every kind (fit, rotation, the
// colour of the system) on top, then the library with one folder per kind
// (images, adaptive SVGs, videos). The selection holds one kind only: several
// of it take turns, in the order of the strip; picking another kind starts over.
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

    readonly property var fitIcons: ({ frame: "filter_frames", screen: "fullscreen" })

    readonly property string library: page.prefs.wallpaperDir || page.configDir + "/wallpapers"
    readonly property var kinds: [
        { key: "image", folder: "images", icon: "image", filters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"] },
        { key: "svg", folder: "svg", icon: "draw", filters: ["*.svg"] },
        { key: "video", folder: "videos", icon: "movie", filters: ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.avi"] }
    ]
    readonly property var browsed: page.kinds.find(function (kind) { return kind.key === page.browse }) || page.kinds[0]
    // The kind on screen; an older single wallpaper still counts as one.
    readonly property string activeKind: page.prefs.wallpaperType || page.kindOf(page.prefs.wallpaper)
    readonly property var selection: {
        var list = (page.prefs.wallpaperSelection || "").split("|").filter(function (path) { return path !== "" })
        return list.length === 0 && page.prefs.wallpaper ? [page.prefs.wallpaper] : list
    }
    // Colour presets for the system, besides the automatic one.
    readonly property var seeds: ["#6750a4", "#0061a4", "#006a6a", "#386a20", "#8b5000", "#b3261e"]
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

    // An adaptive SVG with its {{role}} placeholders filled from the current
    // palette, as a data URL the preview can show.
    function adaptive(path, done) {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            var data = page.palette.data || ({})
            var filled = request.responseText.replace(/\{\{\s*([a-z_]+)\s*\}\}/g, function (match, role) {
                return data[role] || String(page.palette.foreground)
            })
            done("data:image/svg+xml;utf8," + encodeURIComponent(filled))
        }
        request.open("GET", "file://" + path)
        request.send()
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
        if (/\.svg$/i.test(path || ""))
            return "svg"
        if (/\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(path || ""))
            return "video"
        return path ? "image" : ""
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

        Component.onCompleted: {
            if (thumb.kind === "svg")
                page.adaptive(thumb.path, function (url) { thumb.preview = url })
        }

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

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "play_circle"
                    color: page.palette.foreground
                    font.family: VitrailTokens.iconFamily
                    font.pixelSize: 30
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
                        description: page.activeKind === "image" ? page.t("wallpaper.effect.help")
                                                                 : page.t("wallpaper.effect.imageOnly")
                        enabled: page.activeKind === "image"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 220
                            current: Effects.of(page.prefs.wallpaperEffect)
                            options: Effects.NAMES.map(function (name) {
                                return { key: name, label: page.t("wallpaper.effect." + name) }
                            })
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.wallpaperEffect = key
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

                    VitrailSettingRow {
                        icon: "colorize"
                        label: page.t("wallpaper.systemColor")
                        description: page.t("wallpaper.systemColor.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: page.prefs.systemColor === "" ? "inset" : "outlined"
                            tone: "secondary"
                            text: page.t("wallpaper.systemColor.auto")
                            onClicked: page.prefs.systemColor = ""
                        }

                        Repeater {
                            model: page.seeds

                            delegate: Rectangle {
                                required property string modelData

                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: modelData
                                border.width: page.prefs.systemColor === modelData ? 3 : 0
                                border.color: page.palette.foreground

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.prefs.systemColor = parent.modelData
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
}
