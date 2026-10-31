import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import "kit"
import "kit/base"
import "kit/composed"
import "kit/frame.js" as Frame
import "prefs.js" as Prefs
import "clock"
import "dialogs"
import "launcher"
import "network"
import "tray"
import "notifications"
import "osd"
import "osd/osd.js" as Osd
import "session"
import "session/actions.js" as Session

// Vitrail desktop layer, per monitor: wallpaper, screen frame, system bar and
// side panel. The preference files are watched, so the settings window applies live.
//
//   vitrail-bar ipc call panel toggle full      (or overlay)
//   vitrail-bar ipc call panel close
ShellRoot {
    id: shell

    // One INI file per area (vitrail/prefs.map), merged into `prefs`.
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME")
                                         || Quickshell.env("HOME") + "/.config") + "/vitrail"
    property var prefFiles: []
    property var prefParts: ({})
    readonly property var prefs: Prefs.merge(shell.prefParts, shell.prefFiles)
    property bool popupOpen: false
    property string popupKind: ""
    // The screen whose bar opened the popup: only its layer shows it.
    property var popupScreen: null
    // The rect (screen coordinates) of the button the popup grows from.
    property rect popupAnchor: Qt.rect(0, 0, 0, 0)
    readonly property real popupAnchorX: shell.popupAnchor.x + shell.popupAnchor.width / 2
    readonly property real popupAnchorY: shell.popupAnchor.y + shell.popupAnchor.height / 2
    // Per screen name, the monitor scope that owns its bar (anchorFor).
    property var monitors: ({})
    property var strings: ({})

    // The mode the next launcher opens in (see the launcher IPC).
    property string launcherMode: ""
    // The full-screen launcher: open, and on which screen.
    property bool launcherOpen: false
    property var launcherScreen: null

    // Left click and Super: the full-screen launcher on that monitor (the
    // focused one without a screen); the popout is the right click.
    function toggleLauncher(screen, mode) {
        var target = screen || shell.focusedScreen
        if (shell.launcherOpen && shell.launcherScreen === target && !mode) {
            shell.launcherOpen = false
            return
        }
        shell.closePopup()
        shell.sessionOpen = false
        shell.launcherMode = ""
        shell.launcherMode = mode || ""
        shell.launcherScreen = target
        shell.launcherOpen = true
    }

    // True for the first frames after a closed popout opens: it appears in
    // place instead of gliding in from wherever the last one was.
    property bool popupOpening: false

    // The button of a popup on a screen's bar, for popups opened without one.
    function anchorOf(kind, screen) {
        var monitor = screen ? shell.monitors[screen.name] : null
        return monitor ? monitor.anchorFor(kind) : null
    }

    // The popup opens on the screen of the bar element that invoked it, or
    // the focused monitor when there is none (IPC), anchored on its own
    // button there.
    function openPopup(kind, item, screen) {
        shell.launcherOpen = false
        var target = screen || shell.focusedScreen
        var anchor = item || shell.anchorOf(kind, target)
        if (!shell.popupOpen) {
            shell.popupOpening = true
            popupSettle.restart()
        }
        if (anchor) {
            var point = anchor.mapToItem(null, 0, 0)
            shell.popupAnchor = Qt.rect(point.x, point.y, anchor.width, anchor.height)
        }
        shell.popupScreen = target
        shell.popupKind = kind
        shell.popupOpen = true
    }

    function togglePopup(kind, item, screen) {
        if (shell.popupOpen && shell.popupKind === kind)
            shell.closePopup()
        else
            shell.openPopup(kind, item, screen)
    }

    // Hovering an element that has a popout moves an open popout to it.
    function hoverPopup(kind, item, screen) {
        if (shell.popupOpen && (shell.popupKind !== kind || shell.popupScreen !== screen))
            shell.openPopup(kind, item, screen)
    }

    function closePopup() {
        shell.popupOpen = false
    }

    // The session menu (lock, log out, power) covers the screen whose button
    // opened it, or the focused monitor.
    property bool sessionOpen: false
    property var sessionScreen: null
    property bool canHibernate: false

    function toggleSession(screen) {
        shell.closePopup()
        shell.launcherOpen = false
        shell.sessionScreen = screen || shell.focusedScreen
        shell.sessionOpen = !shell.sessionOpen
    }

    function runSession(key) {
        var action = Session.find(key)
        shell.sessionOpen = false
        shell.closePopup()
        if (action) {
            sessionRun.command = action.command
            sessionRun.startDetached()
        }
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

    // The primary monitor's bar, which every monitor's OSD follows: one edge
    // and one centring everywhere (see OsdLayer).
    property var primaryBar: null
    readonly property string osdEdge: Osd.edgeFor(shell.prefs.notificationPosition || "top-right",
                                                  shell.primaryBar ? shell.primaryBar.layout.edge : "")
    readonly property var osdReference: !shell.primaryBar ? ({ left: 0, top: 0, right: 0, bottom: 0 })
        : (shell.primaryBar.style.docked ? shell.primaryBar.layout.dock : shell.primaryBar.layout.reserve)

    // The screen of Hyprland's focused monitor.
    readonly property var focusedScreen: {
        var focused = Hyprland.focusedMonitor
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            if (focused && Hyprland.monitorFor(screens[i]) === focused)
                return screens[i]
        }
        return shell.primaryScreen
    }

    // Toasts follow the focused monitor, but stay off a screen showing a
    // fullscreen window: then the primary one, any other free one, and only
    // when every screen is fullscreen the focused one anyway.
    readonly property var notificationScreen: {
        function fullscreen(screen) {
            var monitor = Hyprland.monitorFor(screen)
            return !!(monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen)
        }
        var focused = shell.focusedScreen
        if (!focused || !fullscreen(focused))
            return focused
        if (shell.primaryScreen && !fullscreen(shell.primaryScreen))
            return shell.primaryScreen
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            if (!fullscreen(screens[i]))
                return screens[i]
        }
        return focused
    }

    readonly property bool dark: {
        var mode = shell.prefs.appearance || "auto"
        var hour = shell.now.getHours()
        return mode === "dark" || (mode === "auto" && (hour < 7 || hour >= 19))
    }

    // Preference key for each token the bar uses.
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

    function setPrefPart(name, values) {
        var parts = Object.assign({}, shell.prefParts)
        parts[name] = values
        shell.prefParts = parts
    }

    VitrailPalette {
        id: wallpaper

        dark: shell.dark
        data: (shell.dark ? shell.palettes.dark : shell.palettes.light) || ({})
    }

    // A settings.ini from before the split becomes one file per area; the
    // watchers below pick the new files up.
    Process {
        running: true
        command: ["python3", "-m", "vitrail.cli", "migrate"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    FileView {
        path: Quickshell.shellDir + "/../vitrail/prefs.map"
        printErrors: false
        onLoaded: shell.prefFiles = Prefs.files(this.text())
    }

    Instantiator {
        model: shell.prefFiles

        delegate: FileView {
            required property string modelData

            path: shell.configDir + "/" + modelData + ".ini"
            watchChanges: true
            printErrors: false
            onFileChanged: this.reload()
            onLoaded: shell.setPrefPart(modelData, Prefs.parse(this.text()))
            onLoadFailed: shell.setPrefPart(modelData, ({}))
        }
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
        onFileChanged: this.reload()
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

    // Volume, microphone and brightness: state and the `osd` IPC, once; each
    // monitor draws its own OsdLayer.
    OsdController {
        id: osdController
    }

    NotificationQueue {
        id: toasts

        maximum: Number(shell.prefs.notificationMax) || VitrailTokens.ranges.notifications.value
    }

    // --- system requests ------------------------------------------------------
    // Vitrail answers the system itself: it is the polkit agent (admin
    // passwords), and scripts/hyprland-dialog.sh hands it Hyprland's dialogs
    // (an app not responding, a permission request). Polkit goes first.
    PolkitAgent {
        id: polkit
    }

    // Hyprland dialogs waiting for an answer: [{ id, title, text, buttons }].
    property var hyprDialogs: []
    readonly property var hyprDialog: shell.hyprDialogs.length > 0 ? shell.hyprDialogs[0] : null
    readonly property string dialogDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrail-dialog"

    IpcHandler {
        target: "dialog"

        function ask(id: string, title: string, text: string, buttons: string): void {
            shell.hyprDialogs = shell.hyprDialogs.concat([{
                id: id, title: title, text: text,
                buttons: buttons.split(";").filter(function (button) { return button !== "" })
            }])
        }

        // Answers the question on screen, as its button would.
        function answer(label: string): void {
            if (shell.hyprDialog)
                shell.answerHyprDialog(shell.hyprDialog.id, label)
        }

        // Hyprland gave up on the question (the app recovered).
        function dismiss(id: string): void {
            shell.hyprDialogs = shell.hyprDialogs.filter(function (dialog) { return dialog.id !== id })
        }
    }

    // The shim waits for this file and prints it back to Hyprland.
    function answerHyprDialog(id, label) {
        dialogAnswer.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2.part\" && mv \"$2.part\" \"$2\"",
                                "answer", label, shell.dialogDir + "/" + id]
        dialogAnswer.startDetached()
        shell.hyprDialogs = shell.hyprDialogs.filter(function (dialog) { return dialog.id !== id })
    }

    Process {
        id: dialogAnswer
    }

    // Session commands run detached, once the menu is gone.
    Process {
        id: sessionRun
    }

    // Hibernation is offered only where the system can do it.
    Process {
        command: ["systemctl", "--dry-run", "hibernate"]
        running: true
        onExited: function (exitCode) { shell.canHibernate = exitCode === 0 }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            shell.toggleSession(null)
        }
    }

    // Hyprland may kill the shim outright: a question whose shim is gone
    // (its id starts with the shim's pid) leaves the screen.
    Timer {
        interval: 1000
        running: shell.hyprDialogs.length > 0
        repeat: true
        onTriggered: {
            dialogWatch.command = ["sh", "-c", "for id; do kill -0 \"${id%%-*}\" 2>/dev/null || echo \"$id\"; done", "watch"]
                .concat(shell.hyprDialogs.map(function (dialog) { return dialog.id }))
            dialogWatch.running = true
        }
    }

    Process {
        id: dialogWatch

        stdout: StdioCollector {
            onStreamFinished: {
                var gone = this.text.split("\n")
                shell.hyprDialogs = shell.hyprDialogs.filter(function (dialog) { return gone.indexOf(dialog.id) < 0 })
            }
        }
    }

    // The application launcher, shared by the bar button and Super alone:
    //   vitrail-bar ipc call launcher toggle     full screen, focused monitor
    //   vitrail-bar ipc call launcher open <web|calc|run|files|windows|actions|clipboard>
    //   vitrail-bar ipc call launcher popout     the compact card under the bar
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            shell.toggleLauncher(null, "")
        }

        function open(mode: string): void {
            shell.toggleLauncher(null, mode)
        }

        function popout(): void {
            shell.launcherOpen = false
            shell.launcherMode = ""
            shell.togglePopup("launcher", null, null)
        }
    }

    // What the launcher remembers; one for every monitor's launcher.
    LauncherStore {
        id: launcherStore

        clearRequest: shell.prefs.launcherClear || ""
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            shell.togglePopup("network", null, null)
        }

        function close(): void {
            shell.closePopup()
        }
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void {
            shell.togglePopup("vpn", null, null)
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

    Timer {
        id: popupSettle

        // Long enough for the popout to load and report its size.
        interval: VitrailTokens.duration("fast")
        onTriggered: shell.popupOpening = false
    }

    // Runs the Python side (rotation, system theme) from the repository.
    Process {
        id: vitrailCli

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    // Several wallpapers of one kind take turns; wallpaper.ini changes and the
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

                // The popup button of each kind on this monitor's bar.
                function anchorFor(kind) {
                    switch (kind) {
                    case "network": return barItems.networkButton
                    case "vpn": return barItems.vpnButton
                    case "power": return barItems.powerButton
                    case "launcher": return launcherButton
                    case "clock": return clockButton
                    default: return null
                    }
                }

                Binding {
                    target: shell
                    property: "primaryBar"
                    value: bar
                    when: monitor.modelData === shell.primaryScreen
                    restoreMode: Binding.RestoreNone
                }

                Component.onCompleted: shell.monitors[monitor.modelData.name] = monitor
                Component.onDestruction: delete shell.monitors[monitor.modelData.name]

                // The popup and the notification stack open and close like a
                // drop of liquid (glass) or a smooth fade (solid).
                VitrailLiquid {
                    id: popupLiquid

                    open: shell.popupOpen && monitor.modelData === shell.popupScreen
                }

                VitrailLiquid {
                    id: stackLiquid

                    open: monitor.modelData === shell.notificationScreen && toasts.shown.count > 0
                }

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
                        item: bar.showBar && !bar.islands ? bar.area : null

                        Region { item: bar.startMask }
                        Region { item: bar.centerMask }
                        Region { item: bar.endMask }
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
                        popupLook: popupLiquid.shown ? popupLiquid.look : null
                        popupOrigin: shell.popupAnchor
                        popupLag: popupCard.lag
                        // Docked, the notification stack and the OSD are tabs of the frame too.
                        tabs: (stackHolder.docked && stackLiquid.shown && stackHolder.height > 0
                              ? [{ edge: stackHolder.place.edge, reveal: stackLiquid.look.reveal,
                                   swell: stackLiquid.look.swell,
                                   rect: Frame.liquidRect(Qt.rect(stackHolder.x, stackHolder.y, stackHolder.width, stackHolder.height),
                                                          stackHolder.place.edge, stackHolder.origin,
                                                          stackLiquid.look.spread, 0, 0) }]
                              : []).concat(osd.tabs)

                        start: LauncherButton {
                            id: launcherButton

                            strings: shell.strings
                            opened: (shell.popupOpen && shell.popupKind === "launcher" && shell.popupScreen === monitor.modelData)
                                    || (shell.launcherOpen && shell.launcherScreen === monitor.modelData)
                            onClicked: shell.toggleLauncher(monitor.modelData, "")
                            onMenuRequested: {
                                shell.launcherOpen = false
                                shell.launcherMode = ""
                                shell.togglePopup("launcher", launcherButton, monitor.modelData)
                            }
                            onHoveredChanged: tooltips.hover(launcherButton, hovered)
                        }

                        center: ClockButton {
                            id: clockButton

                            vertical: bar.vertical
                            language: shell.prefs.language || "en"
                            opened: shell.popupOpen && shell.popupKind === "clock" && shell.popupScreen === monitor.modelData
                            onClicked: shell.togglePopup("clock", clockButton, monitor.modelData)
                            onHoveredChanged: {
                                tooltips.hover(clockButton, hovered)
                                if (hovered)
                                    shell.hoverPopup("clock", clockButton, monitor.modelData)
                            }
                        }

                        end: BarItems {
                            id: barItems

                            vertical: bar.vertical
                            open: shell.popupOpen && shell.popupScreen === monitor.modelData
                            openKind: shell.popupKind
                            strings: shell.strings
                            onClicked: function (kind, item) { shell.togglePopup(kind, item, monitor.modelData) }
                            onHovered: function (kind, item) { shell.hoverPopup(kind, item, monitor.modelData) }
                            onTipHovered: function (item, on) { tooltips.hover(item, on) }
                            onSessionRequested: shell.toggleSession(monitor.modelData)
                        }
                    }
                }

                // Tooltips of the bar's elements: one host per monitor.
                TooltipLayer {
                    id: tooltips

                    screen: monitor.modelData
                    edge: bar.layout.edge
                    offset: bar.style.docked ? bar.layout.dock[bar.layout.edge] : bar.reserve[bar.layout.edge]
                    opacityLevel: shell.barOpacity
                }

                // Volume, microphone and brightness, on the edge opposite the
                // notifications, at the same spot on every monitor.
                OsdLayer {
                    id: osd

                    screen: monitor.modelData
                    controller: osdController
                    layout: bar.layout
                    docked: bar.style.docked
                    edge: shell.osdEdge
                    reference: shell.osdReference
                    focused: monitor.modelData === shell.focusedScreen
                    strings: shell.strings
                    opacityLevel: shell.barOpacity
                }

                // Popup layer: one full-screen surface so the card can sit
                // exactly under the button that opened it and travel between
                // bar buttons without recreating a surface.
                PanelWindow {
                    id: popupLayer

                    screen: monitor.modelData
                    // Stays up while the popup closes.
                    visible: popupLiquid.shown
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
                    // The launcher is typed into: it takes the keyboard while open.
                    WlrLayershell.keyboardFocus: popupLiquid.open && shell.popupKind === "launcher" ? WlrKeyboardFocus.Exclusive
                                                                                                       : WlrKeyboardFocus.None

                    // Any click outside the card closes it.
                    MouseArea {
                        anchors.fill: parent
                        enabled: popupLiquid.open
                        onClicked: shell.closePopup()
                    }

                    // Floating, the card is an island that leaves the bar
                    // (joined by a liquid neck in glass); docked, the frame
                    // draws it (see VitrailBar.popupLook).
                    VitrailLiquidSkin {
                        anchors.fill: parent
                        visible: !popupCard.docked
                        edge: popupCard.barEdge
                        rect: Qt.rect(popupCard.x, popupCard.y, popupCard.width, popupCard.height)
                        origin: shell.popupAnchor
                        source: popupCard.source
                        look: popupLiquid.look
                        gap: popupCard.margin
                        lag: popupCard.lag
                        opacityLevel: shell.barOpacity
                    }

                    Item {
                        id: popupCard

                        property bool entered: false
                        readonly property int margin: VitrailTokens.gap("md")
                        readonly property string barEdge: bar.layout.edge
                        readonly property bool docked: bar.style.docked
                        readonly property var hole: bar.layout.hole
                        // Docked, the card is a tab of the frame, flush with
                        // its edge (past the islands of an islands bar);
                        // floating, an island a gap past the bar.
                        readonly property real offset: popupCard.docked ? bar.layout.dock[popupCard.barEdge]
                                                                        : bar.reserve[popupCard.barEdge] + popupCard.margin

                        // Sized to the popout being shown; switching glides to the
                        // next size while the contents cross-fade. It keeps its
                        // size while the popup closes.
                        readonly property real wantWidth: popouts.current ? popouts.current.implicitWidth + 2 * popupCard.margin : 0
                        readonly property real wantHeight: popouts.current ? popouts.current.implicitHeight + 2 * popupCard.margin : 0
                        property real keptWidth: 0
                        property real keptHeight: 0
                        onWantWidthChanged: if (popupCard.wantWidth > 0) popupCard.keptWidth = popupCard.wantWidth
                        onWantHeightChanged: if (popupCard.wantHeight > 0) popupCard.keptHeight = popupCard.wantHeight

                        // The island or bar a floating card leaves, for its neck.
                        readonly property var source: {
                            if (popupCard.docked)
                                return null
                            if (bar.islands)
                                return Frame.nearestRect(bar.islandRects, shell.popupAnchorX, shell.popupAnchorY)
                            return Qt.rect(bar.area.x, bar.area.y, bar.area.width, bar.area.height)
                        }
                        // Where the card is heading along the bar, minus where it
                        // is: it stretches that way while gliding to a button.
                        readonly property real lag: bar.vertical ? popupCard.targetY - popupCard.y
                                                                 : popupCard.targetX - popupCard.x

                        width: popupCard.wantWidth > 0 ? popupCard.wantWidth : popupCard.keptWidth
                        height: popupCard.wantHeight > 0 ? popupCard.wantHeight : popupCard.keptHeight
                        // Opens from the button that invoked it: sideways for a
                        // vertical bar, above or below for a horizontal one.
                        x: popupCard.targetX
                        y: popupCard.targetY
                        readonly property real targetX: {
                            if (popupCard.barEdge === "left")
                                return popupCard.offset
                            if (popupCard.barEdge === "right")
                                return popupLayer.width - popupCard.offset - popupCard.width
                            return Frame.popupAlong(shell.popupAnchorX, popupCard.width, popupCard.hole.left,
                                                    popupLayer.width - popupCard.hole.right, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }
                        readonly property real targetY: {
                            if (popupCard.barEdge === "top")
                                return popupCard.offset
                            if (popupCard.barEdge === "bottom")
                                return popupLayer.height - popupCard.offset - popupCard.height
                            return Frame.popupAlong(shell.popupAnchorY, popupCard.height, popupCard.hole.top,
                                                    popupLayer.height - popupCard.hole.bottom, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }

                        // Glides only between buttons; opening snaps into place.
                        Behavior on x { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on y { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on width { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on height { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }

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

                        // One popout per element; only the current one is loaded.
                        Item {
                            id: popouts

                            readonly property string name: shell.popupOpen ? shell.popupKind : ""
                            // The popout being shown, while the previous one fades out.
                            readonly property Item current: {
                                for (var i = 0; i < popouts.children.length; i++) {
                                    if (popouts.children[i].shouldBeActive)
                                        return popouts.children[i]
                                }
                                return null
                            }

                            anchors.fill: parent
                            anchors.margins: popupCard.margin
                            // The content waits for the shape and leaves first.
                            opacity: popupLiquid.look.content

                            Popout {
                                name: "launcher"
                                current: popouts.name
                                sourceComponent: launcherComponent
                            }

                            Popout {
                                name: "network"
                                current: popouts.name
                                sourceComponent: networkComponent
                            }

                            Popout {
                                name: "vpn"
                                current: popouts.name
                                sourceComponent: vpnComponent
                            }

                            Popout {
                                name: "clock"
                                current: popouts.name
                                sourceComponent: clockComponent
                            }

                            Popout {
                                name: "power"
                                current: popouts.name
                                sourceComponent: powerComponent
                            }

                            Repeater {
                                model: SystemTray.items

                                delegate: Popout {
                                    id: trayPopout

                                    required property var modelData

                                    name: "tray:" + trayPopout.modelData.id
                                    current: popouts.name
                                    sourceComponent: Component {
                                        TrayMenu {
                                            handle: trayPopout.modelData.menu
                                            strings: shell.strings
                                            onDone: shell.closePopup()
                                        }
                                    }
                                }
                            }
                        }

                        Timer {
                            id: popupLeave
                            interval: 3000
                            // The launcher stays until it is dismissed.
                            onTriggered: if (shell.popupKind !== "launcher") shell.closePopup()
                        }
                    }
                }

                Component {
                    id: clockComponent

                    ClockPanel {
                        strings: shell.strings
                        language: shell.prefs.language || "en"
                    }
                }

                Component {
                    id: launcherComponent

                    Launcher {
                        strings: shell.strings
                        prefs: shell.prefs
                        store: launcherStore
                        initialMode: shell.launcherMode
                        screenWidth: monitor.modelData.width
                        screenHeight: monitor.modelData.height
                        onDone: shell.closePopup()
                        onOpenPopup: function (kind) { shell.openPopup(kind, null, monitor.modelData) }
                        onOpenSession: shell.toggleSession(monitor.modelData)
                    }
                }

                Component {
                    id: powerComponent

                    SessionPopout {
                        strings: shell.strings
                        canHibernate: shell.canHibernate
                        onChosen: function (key) { shell.runSession(key) }
                    }
                }

                Component {
                    id: networkComponent

                    NetworkPanel {
                        strings: shell.strings
                    }
                }

                Component {
                    id: vpnComponent

                    VpnPanel {
                        strings: shell.strings
                    }
                }

                // System requests: a dimmed screen and one dialog in the middle
                // that takes the keyboard until it is answered.
                PanelWindow {
                    id: dialogLayer

                    readonly property var flow: polkit.isActive ? polkit.flow : null
                    readonly property var request: dialogLayer.flow ? null : shell.hyprDialog
                    // Hyprland's own labels are the answers; only their text is ours.
                    readonly property var labels: ({ "Terminate": shell.t("dialog.terminate"), "Wait": shell.t("dialog.wait") })

                    screen: monitor.modelData
                    visible: monitor.modelData === shell.primaryScreen && (dialogLayer.flow !== null || dialogLayer.request !== null)
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-dialog"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                    onVisibleChanged: if (visible) Qt.callLater(systemDialog.focusInput)

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: dialogLayer.visible ? 0.4 : 0

                        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base") } }
                    }

                    SystemDialog {
                        id: systemDialog

                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        focus: true
                        icon: dialogLayer.flow ? "admin_panel_settings"
                              : dialogLayer.request && /respond/i.test(dialogLayer.request.title) ? "hourglass_top"
                              : "shield"
                        title: dialogLayer.flow ? shell.t("dialog.auth.title")
                               : dialogLayer.request ? dialogLayer.request.title : ""
                        message: dialogLayer.flow ? dialogLayer.flow.message
                                 : dialogLayer.request ? dialogLayer.request.text : ""
                        secret: dialogLayer.flow !== null
                        reveal: dialogLayer.flow ? dialogLayer.flow.responseVisible : false
                        prompt: dialogLayer.flow ? dialogLayer.flow.inputPrompt : ""
                        detail: dialogLayer.flow ? dialogLayer.flow.supplementaryMessage : ""
                        error: dialogLayer.flow ? (dialogLayer.flow.supplementaryIsError || dialogLayer.flow.failed) : false
                        busy: dialogLayer.flow ? !dialogLayer.flow.isResponseRequired : false
                        cancelKey: dialogLayer.flow ? "cancel"
                                   : dialogLayer.request && dialogLayer.request.buttons.indexOf("Wait") >= 0 ? "Wait"
                                   : dialogLayer.request ? dialogLayer.request.buttons[dialogLayer.request.buttons.length - 1] : ""
                        buttons: {
                            if (dialogLayer.flow)
                                return [{ key: "cancel", label: shell.t("dialog.cancel"), variant: "outlined", tone: "secondary" },
                                        { key: "submit", label: shell.t("dialog.auth.submit"), variant: "flat" }]
                            if (!dialogLayer.request)
                                return []
                            var list = dialogLayer.request.buttons
                            return list.map(function (label, index) {
                                return {
                                    key: label,
                                    label: dialogLayer.labels[label] || label,
                                    variant: index === list.length - 1 ? "flat" : "outlined",
                                    tone: label === "Terminate" ? "error" : (index === list.length - 1 ? "primary" : "secondary")
                                }
                            })
                        }

                        onAnswered: function (key, response) {
                            if (dialogLayer.flow) {
                                if (key === "cancel")
                                    dialogLayer.flow.cancelAuthenticationRequest()
                                else
                                    dialogLayer.flow.submit(response)
                            } else if (dialogLayer.request) {
                                shell.answerHyprDialog(dialogLayer.request.id, key)
                            }
                        }
                    }
                }

                // Full-screen launcher: the same kind of layer as the session menu.
                PanelWindow {
                    id: launcherLayer

                    readonly property bool shown: shell.launcherOpen && shell.launcherScreen === monitor.modelData

                    screen: monitor.modelData
                    // Stays up while it fades out.
                    visible: launcherLayer.shown || launcherFull.opacity > 0
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-launcher"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: launcherLayer.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                    LauncherScreen {
                        id: launcherFull

                        anchors.fill: parent
                        open: launcherLayer.shown
                        strings: shell.strings
                        prefs: shell.prefs
                        store: launcherStore
                        initialMode: shell.launcherMode
                        onDismissed: shell.launcherOpen = false
                        onOpenPopup: function (kind) { shell.openPopup(kind, null, monitor.modelData) }
                        onOpenSession: shell.toggleSession(monitor.modelData)
                    }
                }

                // Session menu: a dimmed full-screen layer that takes the keyboard.
                PanelWindow {
                    id: sessionLayer

                    readonly property bool shown: shell.sessionOpen && shell.sessionScreen === monitor.modelData

                    screen: monitor.modelData
                    // Stays up while it fades out.
                    visible: sessionLayer.shown || sessionMenu.opacity > 0
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-session"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: sessionLayer.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                    SessionMenu {
                        id: sessionMenu

                        anchors.fill: parent
                        open: sessionLayer.shown
                        strings: shell.strings
                        user: Quickshell.env("USER") || ""
                        now: shell.now
                        canHibernate: shell.canHibernate
                        onChosen: function (key) { shell.runSession(key) }
                        onDismissed: shell.sessionOpen = false
                    }
                }

                // Incoming notifications, on the focused monitor (see
                // notificationScreen), wherever the user put them. Only the
                // stack itself takes input.
                PanelWindow {
                    screen: monitor.modelData
                    // Stays up while the stack closes (or the screen changes).
                    visible: monitor.modelData === shell.notificationScreen || stackLiquid.shown
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
                    mask: Region { item: stackLiquid.shown ? stackHolder : null }

                    // Floating, the stack is an island that leaves the bar (a
                    // liquid neck in glass); docked, the frame draws it.
                    VitrailLiquidSkin {
                        anchors.fill: parent
                        visible: !stackHolder.docked
                        edge: stackHolder.place.edge
                        rect: Qt.rect(stackHolder.x, stackHolder.y, stackHolder.width, stackHolder.height)
                        origin: stackHolder.origin
                        source: stackHolder.source
                        look: stackLiquid.look
                        gap: VitrailTokens.gap("md")
                        opacityLevel: shell.barOpacity
                    }

                    Item {
                        id: stackHolder

                        // Height of the last stack shown: it keeps it while it closes.
                        property real keptHeight: 0

                        readonly property string position: shell.prefs.notificationPosition || "top-right"
                        readonly property bool docked: bar.style.docked
                        readonly property var place: Frame.stackRect(stackHolder.position, parent.width, parent.height,
                                                                     stack.implicitWidth, stackHolder.height,
                                                                     bar.layout, stackHolder.docked,
                                                                     VitrailTokens.gap("md"),
                                                                     bar.showBar ? bar.islandRects : [])
                        // It grows from a drop as wide as the bar, at its middle.
                        readonly property var origin: Qt.rect(stackHolder.x + (stackHolder.width - VitrailTokens.bar) / 2,
                                                              stackHolder.y, VitrailTokens.bar, stackHolder.height)
                        // The bar or island a floating stack leaves, when the bar is on its edge.
                        readonly property var source: {
                            if (stackHolder.docked || !bar.showBar || bar.layout.edge !== stackHolder.place.edge)
                                return null
                            if (bar.islands)
                                return Frame.nearestRect(bar.islandRects, stackHolder.x + stackHolder.width / 2, 0)
                            return Qt.rect(bar.area.x, bar.area.y, bar.area.width, bar.area.height)
                        }

                        x: stackHolder.place.x
                        y: stackHolder.place.y
                        width: stack.implicitWidth
                        height: stack.implicitHeight > 0 ? stack.implicitHeight : stackHolder.keptHeight
                        clip: true

                        // Only a stack that is fully open grows and shrinks with its cards.
                        Behavior on height { enabled: stackLiquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

                        NotificationStack {
                            id: stack

                            width: parent.width
                            height: stack.implicitHeight
                            y: stack.atBottom ? parent.height - stack.implicitHeight : 0
                            opacity: stackLiquid.look.content
                            queue: toasts
                            strings: shell.strings
                            atBottom: stackHolder.place.edge === "bottom"
                            onImplicitHeightChanged: if (stack.implicitHeight > 0) stackHolder.keptHeight = stack.implicitHeight
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
