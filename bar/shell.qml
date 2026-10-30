import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import "kit"
import "kit/base"
import "kit/composed"
import "kit/frame.js" as Frame
import "network"
import "notifications"

// Vitrail desktop layer, per monitor: wallpaper, screen frame, system bar and
// side panel. settings.ini is watched, so the settings window applies live.
//
//   vitrail-bar ipc call panel toggle full      (or overlay)
//   vitrail-bar ipc call panel close
ShellRoot {
    id: shell

    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME")
                                          || Quickshell.env("HOME") + "/.config") + "/vitrail/settings.ini"
    property var prefs: ({})
    property bool popupOpen: false
    property string popupKind: ""
    property real popupAnchorX: 0
    property real popupAnchorY: 0
    property var strings: ({})

    function openPopup(kind, item) {
        if (item) {
            var point = item.mapToItem(null, item.width / 2, item.height / 2)
            shell.popupAnchorX = point.x
            shell.popupAnchorY = point.y
        }
        shell.popupKind = kind
        shell.popupOpen = true
    }

    function togglePopup(kind, item) {
        if (shell.popupOpen && shell.popupKind === kind)
            shell.closePopup()
        else
            shell.openPopup(kind, item)
    }

    function closePopup() {
        shell.popupOpen = false
    }

    function t(key) {
        var value = shell.strings[key]
        return value === undefined ? key : value
    }
    property var palettes: ({})
    property date now: new Date()
    // Last panel variant opened; it is kept while the panel closes so the
    // closing animation matches the opening one.
    property string panelKind: ""
    property bool panelOpen: false

    readonly property string generatedDir: (Quickshell.env("XDG_CACHE_HOME")
                                            || Quickshell.env("HOME") + "/.cache") + "/vitrail/generated"
    readonly property string themeFile: shell.generatedDir + "/theme-dark.json"
    // Bumped on every new palette: a regenerated SVG of the same name reloads.
    property int paletteVersion: 0
    // An adaptive SVG is shown recoloured for the current mode.
    readonly property string wallpaperSource: {
        var path = shell.prefs.wallpaper || ""
        if (!/\.svg$/i.test(path))
            return path
        return shell.generatedDir + "/wallpaper-" + (shell.dark ? "dark" : "light") + ".svg"
    }
    readonly property int rotationCount: (shell.prefs.wallpaperSelection || "").split("|").filter(function (path) {
        return path !== ""
    }).length

    // The bar follows the opacity of focused windows unless it has its own.
    readonly property real barOpacity: {
        var raw = shell.prefs.barOpacityFollow === "false" ? shell.prefs.barOpacity
                                                           : shell.prefs.opacityFocused
        return raw === undefined || raw === "" ? VitrailTokens.opacity : Number(raw)
    }
    // A framed wallpaper always makes room; a screen one only if asked to.
    readonly property bool panelPush: (shell.prefs.wallpaperMode || VitrailStyle.defaults.wallpaper) === "frame"
                                      || shell.prefs.panelPush === "true"

    // Wayland has no primary output: the top-left monitor plays that role.
    readonly property var primaryScreen: {
        var best = null
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i]
            if (!best || screen.y < best.y || (screen.y === best.y && screen.x < best.x))
                best = screen
        }
        return best
    }

    readonly property bool dark: {
        var mode = shell.prefs.appearance || "auto"
        var hour = shell.now.getHours()
        return mode === "dark" || (mode === "auto" && (hour < 7 || hour >= 19))
    }

    // settings.ini key for each token the bar uses.
    readonly property var tokenKeys: ({
        spacing: "spacing",
        radius: "radius",
        blur: "blurStrength",
        opacity: "surfaceOpacity",
        fontBase: "fontBase",
        frame: "frameSize",
        bar: "barSize",
        panel: "panelSize"
    })

    readonly property var tokenValues: {
        var values = {}
        for (var token in shell.tokenKeys) {
            var raw = shell.prefs[shell.tokenKeys[token]]
            if (raw !== undefined && raw !== "")
                values[token] = Number(raw)
        }
        return values
    }

    onTokenValuesChanged: shell.syncTokens()
    onDarkChanged: {
        shell.syncTokens()
        // The automatic switch at 07:00 / 19:00 reaches the other apps too.
        vitrailCli.exec(["python3", "-m", "vitrail.cli", "theme", "apply", "--mode", shell.dark ? "dark" : "light"])
    }
    Component.onCompleted: shell.syncTokens()

    function syncTokens() {
        VitrailTokens.configure(wallpaper, shell.dark, shell.prefs.surfaceStyle, shell.tokenValues)
    }

    // Reads the [appearance] section; the bar needs nothing else.
    function parseIni(text) {
        var out = {}
        var section = ""
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.startsWith("[")) {
                section = line.slice(1, -1)
            } else if (section === "appearance" && line.indexOf("=") > 0) {
                var at = line.indexOf("=")
                out[line.slice(0, at).trim()] = line.slice(at + 1).trim()
            }
        }
        return out
    }

    VitrailPalette {
        id: wallpaper

        dark: shell.dark
        data: (shell.dark ? shell.palettes.dark : shell.palettes.light) || ({})
    }

    FileView {
        path: shell.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: shell.prefs = shell.parseIni(this.text())
    }

    // `vitrail colors` rewrites the theme when the wallpaper changes.
    FileView {
        path: shell.themeFile
        watchChanges: true
        printErrors: false
        onFileChanged: paletteJson.running = true
    }

    FileView {
        path: Quickshell.shellDir + "/../kit/i18n/" + (shell.prefs.language || "en") + ".json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                shell.strings = JSON.parse(this.text())
            } catch (error) {
                shell.strings = ({})
            }
        }
    }

    IpcHandler {
        target: "panel"

        function toggle(kind: string): void {
            shell.panelOpen = !(shell.panelOpen && shell.panelKind === kind)
            shell.panelKind = kind
        }

        function close(): void {
            shell.panelOpen = false
        }
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: function (notification) {
            notification.tracked = true
            toasts.push(notification)
        }
    }

    NotificationQueue {
        id: toasts

        maximum: Number(shell.prefs.notificationMax) || VitrailTokens.ranges.notifications.value
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            if (shell.popupOpen && shell.popupKind === "network")
                shell.closePopup()
            else
                shell.openPopup("network", null)
        }

        function close(): void {
            shell.closePopup()
        }
    }

    Process {
        id: paletteJson

        command: ["python3", Quickshell.shellDir + "/../scripts/palette-json.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.palettes = JSON.parse(this.text)
                } catch (error) {
                    shell.palettes = ({})
                }
                shell.paletteVersion++
            }
        }
    }

    // Runs the Python side (rotation, system theme) from the repository.
    Process {
        id: vitrailCli

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    // Several wallpapers of one kind take turns; settings.ini changes and the
    // palette follows through apply-settings.
    Timer {
        interval: Math.max(1, Number(shell.prefs.wallpaperInterval) || 30) * 60000
        running: shell.rotationCount > 1
        repeat: true
        onTriggered: vitrailCli.exec(["python3", "-m", "vitrail.cli", "wallpaper", "next"])
    }

    // Re-evaluates the automatic light/dark switch.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: shell.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: monitor

                required property var modelData

                // Until a wallpaper is chosen, whatever draws it today stays.
                PanelWindow {
                    screen: monitor.modelData
                    visible: (shell.prefs.wallpaper || "") !== ""
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-wallpaper"
                    WlrLayershell.layer: WlrLayer.Background
                    mask: Region {}

                    VitrailWallpaper {
                        anchors.fill: parent
                        variant: shell.prefs.wallpaperMode || ""
                        source: shell.wallpaperSource
                        revision: shell.paletteVersion
                        hole: bar.layout.hole
                        radius: bar.layout.radius
                    }
                }

                // The frame, the bar and the panel: a transparent full-screen
                // layer that only takes input on the bar and the open panel.
                PanelWindow {
                    screen: monitor.modelData
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-bar"
                    WlrLayershell.layer: WlrLayer.Top
                    mask: Region {
                        item: bar.showBar ? bar.area : null

                        Region { item: bar.panelArea }
                    }

                    VitrailBar {
                        id: bar

                        anchors.fill: parent
                        edge: shell.prefs.barEdge || "left"
                        variant: shell.prefs.barStyle || ""
                        frameVariant: shell.prefs.frameStyle || ""
                        showBar: shell.prefs.barScreens === "all"
                                 || monitor.modelData === shell.primaryScreen
                        opacityLevel: shell.barOpacity
                        panelVariant: shell.panelKind
                        panelOpen: shell.panelOpen
                        panelPush: shell.panelPush
                        popup: Qt.rect(popupCard.x, popupCard.y, popupCard.width, popupCard.height)
                        popupOpen: shell.popupOpen && monitor.modelData === shell.primaryScreen
                        // Docked, the notification stack is a tab of the frame too.
                        tabs: stackHolder.docked && stackHolder.height > 0
                              ? [{ edge: stackHolder.place.edge, reveal: 1,
                                   rect: Qt.rect(stackHolder.x, stackHolder.y, stackHolder.width, stackHolder.height) }]
                              : []

                        end: BarItems {
                            id: barItems

                            vertical: (shell.prefs.barEdge || "bottom") === "left"
                                      || (shell.prefs.barEdge || "bottom") === "right"
                            open: shell.popupOpen
                            openKind: shell.popupKind
                            onNetworkClicked: shell.togglePopup("network", barItems)
                            onBarHovered: function (kind) { shell.openPopup(kind, barItems) }
                        }
                    }
                }

                // Popup layer: one full-screen surface so the card can sit
                // exactly under the button that opened it and travel between
                // bar buttons without recreating a surface.
                PanelWindow {
                    id: popupLayer

                    screen: monitor.modelData
                    visible: shell.popupOpen && monitor.modelData === shell.primaryScreen
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-popup"
                    WlrLayershell.layer: WlrLayer.Overlay

                    // Any click outside the card closes it.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.closePopup()
                    }

                    Item {
                        id: popupCard

                        property bool entered: false
                        readonly property int margin: VitrailTokens.gap("md")
                        readonly property string barEdge: bar.layout.edge
                        readonly property bool docked: bar.style.docked
                        readonly property var hole: bar.layout.hole
                        // Docked, the card is a tab of the frame, flush with
                        // its edge; floating, an island a gap past the bar.
                        readonly property real offset: popupCard.docked ? popupCard.hole[popupCard.barEdge]
                                                                        : bar.reserve[popupCard.barEdge] + popupCard.margin

                        width: (popupContent.item ? popupContent.item.implicitWidth : 360) + 2 * popupCard.margin
                        height: (popupContent.item ? popupContent.item.implicitHeight : 220) + 2 * popupCard.margin
                        // Opens from the button that invoked it: sideways for a
                        // vertical bar, above or below for a horizontal one.
                        x: {
                            if (popupCard.barEdge === "left")
                                return popupCard.offset
                            if (popupCard.barEdge === "right")
                                return popupLayer.width - popupCard.offset - popupCard.width
                            return Frame.popupAlong(shell.popupAnchorX, popupCard.width, popupCard.hole.left,
                                                    popupLayer.width - popupCard.hole.right, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }
                        y: {
                            if (popupCard.barEdge === "top")
                                return popupCard.offset
                            if (popupCard.barEdge === "bottom")
                                return popupLayer.height - popupCard.offset - popupCard.height
                            return Frame.popupAlong(shell.popupAnchorY, popupCard.height, popupCard.hole.top,
                                                    popupLayer.height - popupCard.hole.bottom, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }

                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        HoverHandler {
                            id: cardHover

                            onHoveredChanged: {
                                if (cardHover.hovered) {
                                    popupCard.entered = true
                                    popupLeave.stop()
                                } else if (popupCard.entered) {
                                    popupLeave.restart()
                                }
                            }
                        }

                        // Absorbs clicks so they do not reach the outside area.
                        MouseArea {
                            anchors.fill: parent
                        }

                        // Docked, the frame draws the card; see VitrailBar.popup.
                        VitrailSurface {
                            anchors.fill: parent
                            visible: !popupCard.docked
                            style: VitrailTokens.surfaceMode
                            radius: VitrailTokens.radius
                            tint: VitrailTokens.color("surface")
                            opacityLevel: 0.95
                        }

                        Loader {
                            id: popupContent

                            anchors.fill: parent
                            anchors.margins: popupCard.margin
                            opacity: 0
                            sourceComponent: shell.popupKind === "network" ? networkComponent : null

                            onLoaded: opacity = 1
                            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            onSourceComponentChanged: {
                                opacity = 0
                                fadeIn.restart()
                            }
                        }

                        Timer {
                            id: fadeIn
                            interval: 120
                            onTriggered: popupContent.opacity = 1
                        }

                        Timer {
                            id: popupLeave
                            interval: 3000
                            onTriggered: shell.closePopup()
                        }
                    }
                }

                Component {
                    id: networkComponent

                    NetworkPanel {
                        strings: shell.strings
                    }
                }

                // Incoming notifications, on the primary screen, wherever the
                // user put them. Only the stack itself takes input.
                PanelWindow {
                    screen: monitor.modelData
                    visible: monitor.modelData === shell.primaryScreen
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-notifications"
                    WlrLayershell.layer: WlrLayer.Overlay
                    // Typing a reply needs the keyboard; clicking a toast asks for it.
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                    mask: Region { item: stackHolder }

                    Item {
                        id: stackHolder

                        readonly property string position: shell.prefs.notificationPosition || "top-right"
                        readonly property bool docked: bar.style.docked
                        readonly property var place: Frame.stackRect(stackHolder.position, parent.width, parent.height,
                                                                     stack.implicitWidth, stackHolder.height,
                                                                     bar.layout, stackHolder.docked,
                                                                     VitrailTokens.gap("md"))

                        x: stackHolder.place.x
                        y: stackHolder.place.y
                        width: stack.implicitWidth
                        height: stack.implicitHeight
                        clip: true

                        Behavior on height { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

                        NotificationStack {
                            id: stack

                            width: parent.width
                            height: stack.implicitHeight
                            y: stack.atBottom ? parent.height - stack.implicitHeight : 0
                            queue: toasts
                            strings: shell.strings
                            atBottom: stackHolder.place.edge === "bottom"
                            docked: stackHolder.docked
                        }
                    }
                }


                // One invisible panel per edge reserves the space the frame
                // covers, so windows never slide under it.
                Variants {
                    model: ["left", "top", "right", "bottom"]

                    delegate: Component {
                        PanelWindow {
                            required property string modelData

                            screen: monitor.modelData
                            anchors {
                                left: modelData !== "right"
                                right: modelData !== "left"
                                top: modelData !== "bottom"
                                bottom: modelData !== "top"
                            }
                            implicitWidth: 1
                            implicitHeight: 1
                            color: "transparent"
                            exclusiveZone: bar.reserve[modelData]
                            mask: Region {}
                            WlrLayershell.namespace: "vitrail-reserve"
                        }
                    }
                }
            }
        }
    }
}
