import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "../../kit"
import "../../kit/base"

// Wallpaper category: a library with one folder per kind (images, adaptive
// SVGs, videos) and settings shared by all three. The selection holds one
// kind only: several of it take turns; picking another kind starts over.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string home: ""

    readonly property string library: page.prefs.wallpaperDir || page.home + "/Pictures/Wallpapers"
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
    // Seed presets for adaptive SVGs, besides the automatic one.
    readonly property var seeds: ["#6750a4", "#0061a4", "#006a6a", "#386a20", "#8b5000", "#b3261e"]
    property string browse: page.activeKind || "image"

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

    function kindOf(path) {
        if (/\.svg$/i.test(path || ""))
            return "svg"
        if (/\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(path || ""))
            return "video"
        return path ? "image" : ""
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

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            Section {
                Layout.fillWidth: true
                icon: "photo_library"
                title: page.t("wallpaper.library")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailTabs {
                    Layout.fillWidth: true
                    tabs: page.kinds.map(function (kind) {
                        return { key: kind.key, label: page.t("wallpaper.kind." + kind.key) }
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
                        variant: "outlined"
                        tone: "secondary"
                        icon: "folder_open"
                        text: page.t("wallpaper.openFolder")
                        onClicked: Qt.openUrlExternally("file://" + page.library + "/" + page.browsed.folder)
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
                            property string preview: page.browse === "image" ? "file://" + tile.filePath : ""

                            Component.onCompleted: {
                                if (page.browse === "svg")
                                    page.adaptive(tile.filePath, function (url) { tile.preview = url })
                            }

                            width: 168
                            height: 104

                            Rectangle {
                                anchors.fill: parent
                                radius: VitrailTokens.radius * 0.75
                                color: page.palette.surfaceHigh
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    visible: page.browse !== "video"
                                    source: tile.preview
                                    sourceSize: Qt.size(336, 208)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Column {
                                    anchors.centerIn: parent
                                    visible: page.browse === "video"
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "play_circle"
                                        color: page.palette.foreground
                                        font.family: VitrailTokens.iconFamily
                                        font.pixelSize: 30
                                    }

                                    Text {
                                        width: tile.width - 16
                                        horizontalAlignment: Text.AlignHCenter
                                        text: tile.fileName
                                        color: page.palette.muted
                                        elide: Text.ElideMiddle
                                        font.pixelSize: 10
                                        font.family: VitrailTokens.fontFamily
                                    }
                                }
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
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.choose(tile.filePath, page.browse)
                            }
                        }
                    }
                }
            }

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
                            return { key: key, label: page.t("wallpaper.fit." + key) }
                        })
                        current: page.prefs.wallpaperMode || VitrailStyle.defaults.wallpaper
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.prefs.wallpaperMode = key
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
                            { key: "sequential", label: page.t("wallpaper.order.sequential") },
                            { key: "random", label: page.t("wallpaper.order.random") }
                        ]
                        current: page.prefs.wallpaperOrder
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.prefs.wallpaperOrder = key
                    }
                }

                VitrailSlider {
                    Layout.fillWidth: true
                    label: page.t("wallpaper.interval")
                    suffix: " min"
                    icon: "timer"
                    from: 1
                    to: 120
                    stepSize: 1
                    value: page.prefs.wallpaperInterval
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.wallpaperInterval = value
                }

                VitrailSettingRow {
                    icon: "colorize"
                    label: page.t("wallpaper.seed")
                    description: page.t("wallpaper.seed.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailButton {
                        variant: page.prefs.wallpaperSeed === "" ? "inset" : "outlined"
                        tone: "secondary"
                        text: page.t("wallpaper.seed.auto")
                        onClicked: page.prefs.wallpaperSeed = ""
                    }

                    Repeater {
                        model: page.seeds

                        delegate: Rectangle {
                            required property string modelData

                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: modelData
                            border.width: page.prefs.wallpaperSeed === modelData ? 3 : 0
                            border.color: page.palette.foreground

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.prefs.wallpaperSeed = parent.modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
