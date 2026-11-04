import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    // The folder with one preference file per area (see Prefs.qml).
    readonly property string configDir: Args.value("--config", ".")
    // The translations, in a file the launcher writes: every language in one
    // argument passes the kernel's 128 KiB limit as the strings grow.
    // `--i18n` still serves a caller with a small bundle.
    readonly property var i18n: {
        var path = Args.value("--i18n-file", "")
        if (path !== "") {
            var request = new XMLHttpRequest()
            try {
                request.open("GET", "file://" + path, false)
                request.send()
                return JSON.parse(request.responseText)
            } catch (error) {
                return ({ languages: [], strings: {} })
            }
        }
        return Args.json("--i18n", ({ languages: [], strings: {} }))
    }
    readonly property var languages: app.i18n.languages || []
    readonly property var strings: (app.i18n.strings || {})[prefs.language] || ({})
    readonly property var palettes: Args.json("--palette", ({}))
    readonly property var plugins: Args.json("--plugins", ([]))
    // Read once at startup (the window cannot run commands): every time zone,
    // the system's zone, and whether it syncs its clock over the network.
    readonly property var zones: Args.json("--zones", ([]))
    readonly property string systemZone: Args.value("--timezone", "")
    readonly property bool systemNtp: Args.value("--ntp", "yes") === "yes"
    // The Connection page: Ethernet, Wi-Fi, VPN and Bluetooth as they were at launch.
    readonly property var network: Args.json("--network", ({}))
    // $XDG_RUNTIME_DIR: a private folder where a password may be left for the helper.
    readonly property string runtimeDir: Args.value("--runtime", "")
    // The VPN's private folder (~/.config/vitrail-vpn): its document lives there.
    readonly property string vpnDir: Args.value("--vpn", app.configDir + "/../vitrail-vpn")
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

    // What the pages bind to. A page declares properties named `prefs`,
    // `palette` and `draft`, so `prefs: prefs` would read the page's own.
    readonly property var store: prefs
    readonly property var theme: palette
    readonly property var pending: draft

    property string category: Args.value("--category", "appearance")
    property bool sidebarCollapsed: false

    Prefs {
        id: prefs

        directory: app.configDir
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
        { key: "launcher", group: "desktop", glyph: "apps", label: app.t("section.launcher"), badge: app.t("badge.live") },
        { key: "input", group: "system", glyph: "keyboard", label: app.t("section.input"), badge: app.t("badge.live") },
        { key: "language", group: "system", glyph: "translate", label: app.t("section.language"), badge: app.t("badge.saved") },
        { key: "datetime", group: "system", glyph: "schedule", label: app.t("section.datetime"), badge: "" },
        { key: "connection", group: "system", glyph: "settings_ethernet", label: app.t("section.connection"), badge: "" },
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
            frame.grabToImage(function (result) {
                result.saveToFile(app.configDir + "/selftest.png")
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
                    foreground: palette.foreground
                    accent: palette.primary
                    onSelected: app.category = key
                    onCollapsedChanged: app.sidebarCollapsed = collapsed
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

                                LazyPage {
                                    shown: app.category === "appearance"

                                    AppearancePage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "windows"

                                    WindowsPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                        screenWidth: app.screenWidth
                                        tab: Args.value("--tab", "border")
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "input"

                                    InputPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "design"

                                    DesignPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "wallpaper"

                                    WallpaperPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                        configDir: app.configDir
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "bar"

                                    BarPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "language"

                                    LanguagePage {
                                        palette: app.theme
                                        prefs: app.store
                                        draft: app.pending
                                        strings: app.strings
                                        languages: app.languages
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "datetime"

                                    DateTimePage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                        zones: app.zones
                                        systemZone: app.systemZone
                                        systemNtp: app.systemNtp
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "terminal"

                                    TerminalPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "launcher"

                                    LauncherPage {
                                        tab: Args.value("--tab", "general")
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "connection"

                                    ConnectionPage {
                                        palette: app.theme
                                        prefs: app.store
                                        strings: app.strings
                                        network: app.network
                                        configDir: app.configDir
                                        runtime: app.runtimeDir
                                        vpnDirectory: app.vpnDir
                                        tab: Args.value("--tab", "internet")
                                        view: Args.value("--view", "")
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "plugins"

                                    PluginsPage {
                                        palette: app.theme
                                        prefs: app.store
                                        plugins: app.plugins
                                        strings: app.strings
                                    }
                                }

                                LazyPage {
                                    shown: app.category === "colors"

                                    ColorsPage {
                                        palette: app.theme
                                        strings: app.strings
                                    }
                                }

                        }
                    }
                }
            }
        }
    }
}
