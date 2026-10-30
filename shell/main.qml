import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.settings 1.1
import "../kit"
import "../kit/base"
import "../kit/args.js" as Args
import "pages"

// Vitrail settings window: category rail on the left, category screens on the
// right, each with its own subcategory tabs.
Window {
    id: app

    width: 1000
    height: 680
    minimumWidth: 760
    minimumHeight: 540
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: app.t("app.title")

    readonly property string configFile: Args.value("--config", "settings.ini")
    readonly property var i18n: Args.json("--i18n", ({ languages: [], strings: {} }))
    readonly property var languages: app.i18n.languages || []
    readonly property var strings: (app.i18n.strings || {})[prefs.language] || ({})
    readonly property var palettes: Args.json("--palette", ({}))
    readonly property var plugins: Args.json("--plugins", ([]))
    readonly property bool daytime: {
        var hour = new Date().getHours()
        return hour >= 7 && hour < 19
    }
    // The column fraction is derived from the screen: N columns fill its width.
    readonly property int screenWidth: app.screen ? app.screen.width : 1920
    readonly property real columnWidth: prefs.visibleColumns > 0
                                        ? 1.0 / prefs.visibleColumns
                                        : 0.5
    readonly property bool dark: prefs.appearance === "dark"
                                  || (prefs.appearance === "auto" && !app.daytime)

    property string category: Args.value("--category", "appearance")
    property bool sidebarCollapsed: false

    Settings {
        id: prefs

        fileName: app.configFile
        category: "appearance"

        property string appearance: "auto"
        property string surfaceStyle: "glass"
        property real surfaceOpacity: 0.9
        property real radius: 14
        property real opacityFocused: 0.97
        property real opacityUnfocused: 0.88
        property int blurStrength: 6
        property bool focusFollowsMouse: true
        property int borderWidth: 2
        property string language: "en"
        property string keyboardLayouts: "us:"
        property string keyboardSwitch: "grp:alt_shift_toggle"
        property string windowLayout: "dwindle"
        property int visibleColumns: 2
        property string tabStyle: "capsule"
        property bool tabIcons: true
        property bool tabNumbers: false
        property string terminalScheme: "system"
        property int fontSize: 13
        property int terminalPadding: 6
        property bool followFocus: true
        property bool wrapFocus: false
        property int spacing: 12
        property int fontBase: 13
        property string barEdge: "left"
        property string barScreens: "primary"
        property string barStyle: ""
        property string frameStyle: ""
        property int barSize: VitrailTokens.ranges.bar.value
        property int frameSize: VitrailTokens.ranges.frame.value
        property int panelSize: VitrailTokens.ranges.panel.value
        property bool panelPush: false
        property bool barOpacityFollow: true
        property real barOpacity: VitrailTokens.ranges.opacity.value
        property string notificationPosition: "top-right"
        property int notificationMax: VitrailTokens.ranges.notifications.value
        property string wallpaper: ""
        property string wallpaperMode: ""
        property string wallpaperDir: ""
        // One kind at a time; several of it rotate every wallpaperInterval min.
        property string wallpaperType: ""
        property string wallpaperSelection: ""
        property int wallpaperInterval: 30
        property string wallpaperOrder: "sequential"
        // Adaptive SVGs: seed colour of the palette, "" takes the SVG's own.
        property string wallpaperSeed: ""
        // Written by the smoke test, never by the UI.
        property string selftest: ""
    }

    // Settings that are not applied live: edited here, written on Save.
    QtObject {
        id: draft

        property string language: prefs.language
    }

    VitrailPalette {
        id: palette
        dark: app.dark
        data: app.paletteData
    }

    readonly property var paletteData: (app.dark ? app.palettes.dark : app.palettes.light) || ({})

    // Grouped from what the user sees most to how the system behaves.
    readonly property var categories: [
        { key: "appearance", group: "look", glyph: "contrast", label: app.t("nav.appearance"), badge: app.t("badge.live") },
        { key: "wallpaper", group: "look", glyph: "wallpaper", label: app.t("section.wallpaper"), badge: app.t("badge.live") },
        { key: "colors", group: "look", glyph: "palette", label: app.t("section.colors"), badge: "" },
        { key: "design", group: "look", glyph: "design_services", label: app.t("section.design"), badge: app.t("badge.live") },
        { key: "bar", group: "desktop", glyph: "toolbar", label: app.t("section.bar"), badge: app.t("badge.live") },
        { key: "windows", group: "desktop", glyph: "view_quilt", label: app.t("section.windows"), badge: app.t("badge.live") },
        { key: "terminal", group: "desktop", glyph: "terminal", label: app.t("section.terminal"), badge: app.t("badge.live") },
        { key: "input", group: "system", glyph: "keyboard", label: app.t("section.input"), badge: app.t("badge.live") },
        { key: "language", group: "system", glyph: "translate", label: app.t("section.language"), badge: app.t("badge.saved") },
        { key: "plugins", group: "system", glyph: "extension", label: app.t("section.plugins"), badge: "" }
    ]
    readonly property var groups: ({
        look: app.t("nav.group.look"),
        desktop: app.t("nav.group.desktop"),
        system: app.t("nav.group.system")
    })
    readonly property var currentCategory: app.categories.find(function (category) {
        return category.key === app.category
    }) || app.categories[0]

    // Tokens drive every default in kit/. Reconfigure them whenever the
    // palette, the surface mode or a user-tuned value changes.
    readonly property var tokenValues: ({
        spacing: prefs.spacing,
        radius: prefs.radius,
        blur: prefs.blurStrength,
        opacity: prefs.surfaceOpacity,
        fontBase: prefs.fontBase,
        frame: prefs.frameSize,
        bar: prefs.barSize,
        panel: prefs.panelSize
    })

    onTokenValuesChanged: app.syncTokens()
    onDarkChanged: app.syncTokens()

    function syncTokens() {
        VitrailTokens.configure(palette, app.dark, prefs.surfaceStyle, app.tokenValues)
    }

    function t(key) {
        var value = app.strings[key]
        return value === undefined ? key : value
    }

    Component.onCompleted: {
        app.syncTokens()
        if (Qt.application.arguments.indexOf("--selftest") !== -1) {
            prefs.selftest = new Date().toISOString()
            selftestTimer.start()
        }
    }

    Timer {
        id: selftestTimer

        interval: 600
        onTriggered: {
            var directory = app.configFile.substring(0, app.configFile.lastIndexOf("/"))
            frame.grabToImage(function (result) {
                result.saveToFile(directory + "/selftest.png")
                Qt.quit()
            })
        }
    }

    VitrailSurface {
        id: frame

        anchors.fill: parent
        style: prefs.surfaceStyle
        radius: prefs.radius
        tint: palette.surface
        opacityLevel: prefs.surfaceOpacity

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: VitrailTokens.gap("md")
            spacing: VitrailTokens.gap("sm")

            // Title bar: drag to move, title centred, close on the right.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                DragHandler {
                    target: null
                    onActiveChanged: if (active) app.startSystemMove()
                }

                Text {
                    anchors.centerIn: parent
                    text: app.t("app.title")
                    color: palette.foreground
                    font.pixelSize: 20
                    font.family: VitrailTokens.fontFamily
                    font.weight: Font.Medium
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: VitrailTokens.gap("sm")
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.t("status.saved")
                    color: palette.muted
                    font.pixelSize: 11
                    font.family: VitrailTokens.fontFamily
                }

                VitrailButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "plain"
                    tone: "secondary"
                    icon: "close"
                    onClicked: app.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: VitrailTokens.gap("md")

                VitrailSidebar {
                    Layout.fillHeight: true
                    items: app.categories
                    groups: app.groups
                    current: app.category
                    collapsed: app.sidebarCollapsed
                    action: app.t("action.configFile")
                    actionIcon: "edit"
                    foreground: palette.foreground
                    accent: palette.primary
                    onSelected: app.category = key
                    onCollapsedChanged: app.sidebarCollapsed = collapsed
                    onActionTriggered: Qt.openUrlExternally("file://" + app.configFile)
                }

                // Content card: the category's icon and name, then its page.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: prefs.radius
                    color: Qt.rgba(palette.surfaceHigh.r, palette.surfaceHigh.g, palette.surfaceHigh.b, 0.55)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: VitrailTokens.gap("lg")
                        spacing: VitrailTokens.gap("md")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            Text {
                                text: app.currentCategory.glyph
                                color: palette.primary
                                font.family: VitrailTokens.iconFamily
                                font.variableAxes: ({ "FILL": 1 })
                                font.pixelSize: 26
                            }

                            Text {
                                text: app.currentCategory.label
                                color: palette.foreground
                                font.pixelSize: 22
                                font.family: VitrailTokens.fontFamily
                                font.weight: Font.Medium
                            }

                            Rectangle {
                                visible: app.currentCategory.badge !== ""
                                implicitWidth: badgeText.implicitWidth + 14
                                implicitHeight: 20
                                radius: height / 2
                                color: Qt.rgba(palette.primary.r, palette.primary.g, palette.primary.b, 0.18)

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: app.currentCategory.badge
                                    color: palette.primary
                                    font.pixelSize: 10
                                    font.family: VitrailTokens.fontFamily
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                                AppearancePage {
                                    anchors.fill: parent
                                    visible: app.category === "appearance"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                }

                                WindowsPage {
                                    anchors.fill: parent
                                    visible: app.category === "windows"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                    screenWidth: app.screenWidth
                                    tab: Args.value("--tab", "border")
                                }

                                InputPage {
                                    anchors.fill: parent
                                    visible: app.category === "input"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                }

                                DesignPage {
                                    anchors.fill: parent
                                    visible: app.category === "design"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                }

                                WallpaperPage {
                                    anchors.fill: parent
                                    visible: app.category === "wallpaper"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                    home: Args.value("--home", "")
                                }

                                BarPage {
                                    anchors.fill: parent
                                    visible: app.category === "bar"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                }

                                LanguagePage {
                                    anchors.fill: parent
                                    visible: app.category === "language"
                                    palette: palette
                                    prefs: prefs
                                    draft: draft
                                    strings: app.strings
                                    languages: app.languages
                                }

                                TerminalPage {
                                    anchors.fill: parent
                                    visible: app.category === "terminal"
                                    palette: palette
                                    prefs: prefs
                                    strings: app.strings
                                }

                                PluginsPage {
                                    anchors.fill: parent
                                    visible: app.category === "plugins"
                                    palette: palette
                                    plugins: app.plugins
                                    strings: app.strings
                                }

                                ColorsPage {
                                    anchors.fill: parent
                                    visible: app.category === "colors"
                                    palette: palette
                                    strings: app.strings
                                }

                        }
                    }
                }
            }
        }
    }
}
