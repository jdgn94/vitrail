import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/base"
import "kit/composed"
import "kit/frame.js" as Frame
import "effects.js" as Effects
import "prefs.js" as Prefs
import "barview.js" as BarView
import "layouts.js" as Layouts
import "popup.js" as Popup
import "wallpapermonitors.js" as WallpaperMonitors
import "clock"
import "keyboard"
import "keyboard/keyboard.js" as Keyboard
import "keyboard/wtype.js" as Wtype
import "devices"
import "dialogs"
import "launcher"
import "network"
import "tray"
import "notifications"
import "notifications/notifications.js" as Notifications
import "notes/notes.js" as Notes
import "clipboard"
import "dashboard"
import "desktop"
import "binds"
import "media"
import "launcher/commands.js" as Commands
import "launcher/desktop.js" as LauncherDesktop
import "clipboard/clipboard.js" as Clipboard
import Quickshell.Services.Mpris
import "clipboard/colors.js" as Colors
import "toggles/toggles.js" as Toggles
import "network/connection.js" as Connection
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

    // A start-up trace, off unless asked for: VITRAIL_STARTUP_TRACE=1
    // vitrail-bar, then read the "[startup]" lines.
    readonly property bool startupTrace: Quickshell.env("VITRAIL_STARTUP_TRACE") === "1"
    readonly property real startupAt: Date.now()
    function startupMark(label) {
        if (shell.startupTrace)
            console.log("[startup]", Date.now() - shell.startupAt, label)
    }

    // One INI file per area (vitrail/prefs.map), merged into `prefs`.
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME")
                                         || Quickshell.env("HOME") + "/.config") + "/vitrail"
    property var prefFiles: []
    property var prefParts: ({})
    onPrefPartsChanged: {
        if (shell.prefFiles.length > 0
                && Object.keys(shell.prefParts).length === shell.prefFiles.length)
            shell.startupMark("preferences ready")
    }
    readonly property var prefs: Prefs.merge(shell.prefParts, shell.prefFiles)
    property bool popupOpen: false
    property string popupKind: ""
    // The tray app whose menu is open beside the tray popup (a card of its own).
    // Another popup kind or screen, or closing the popup, closes it.
    property var trayMenuItem: null
    onPopupKindChanged: shell.trayMenuItem = null
    onPopupScreenChanged: shell.trayMenuItem = null
    // The screen whose bar opened the popup: only its layer shows it.
    property var popupScreen: null
    // The rect (screen coordinates) of the button the popup grows from.
    property rect popupAnchor: Qt.rect(0, 0, 0, 0)
    readonly property real popupAnchorX: shell.popupAnchor.x + shell.popupAnchor.width / 2
    readonly property real popupAnchorY: shell.popupAnchor.y + shell.popupAnchor.height / 2
    // Where the pointer last was, in screen coordinates, on the popup layer
    // and on the bar, and which screen saw it. The popup closes only when the
    // pointer is on neither (or on the bar, away from its own button): over an
    // app it is on no tracked surface, which is exactly "outside".
    property var popupPointerScreen: null
    property point popupPointerAt: Qt.point(-1, -1)
    property var barPointerScreen: null
    property point barPointerAt: Qt.point(-1, -1)
    // Per screen name, the monitor scope that owns its bar (anchorFor).
    property var monitors: ({})
    property var strings: ({})
    property bool notificationsOpen: false
    // Do Not Disturb: arrivals are listed, never toasted. Writable, because
    // the panel's button flips it; the preference keeps it across reloads.
    property bool dnd: Notifications.enabled(shell.prefs.notificationDnd)
    // The quick-notes widget's text: one JSON array on a single line.
    property string notes: shell.prefs.quickNotes || ""
    // The monitor the panel was opened on. It stays there whatever the focus
    // does, until it is opened on another one.
    property var notificationsScreen: null

    // What the notification centre remembers, in its own file
    // (vitrail/notify.py): the rows, the per-app counts and the snoozes. A
    // snoozed notification leaves the list and comes back when its time is up;
    // the file is written on the process's stdin, out of the argument limit.
    readonly property string notifyStore: (Quickshell.env("XDG_STATE_HOME")
                                           || Quickshell.env("HOME") + "/.local/state") + "/vitrail/notifications.json"
    readonly property bool snoozeEnabled: shell.prefs.notificationSnooze === undefined
                                           || Notifications.enabled(shell.prefs.notificationSnooze)
    property string storedNotifications: ""
    property bool restoringNotifications: false
    // The two lists the panel opens (so the IPC drives them).
    property bool notificationsMutedShown: false
    property bool notificationsStatsShown: false

    // The clipboard history: the card opens at the pointer on the focused
    // monitor, with the keyboard while it is up.
    property bool clipboardOpen: false
    property var clipboardScreen: null
    property int clipboardX: 0
    property int clipboardY: 0
    property var clipboardEntries: []
    property var clipboardThumbs: ({})
    property var clipboardPending: ({})
    // The other two tabs: the emoji set, and the colour tab's state.
    property var clipboardEmojis: []
    // Loaded the first time the emoji tab opens: assets/emoji.json is 520 KB
    // and parsing it is no part of drawing the bar.
    property string emojiPath: ""
    property var clipboardRecent: Colors.recentFrom(shell.prefs.clipboardColors)
    property string clipboardColor: ""
    property string clipboardFormat: "hex"
    // The tab the next opening shows: the IPC picks it.
    property string clipboardMode: "history"

    // The quick toggles: the system's own state, read back after every change.
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool airplaneOn: false

    // The power profile the connection chip shows.
    property string powerProfile: "balanced"

    // The live keyboards (`hyprctl devices -j`), for the layout chip, its
    // switcher and the on-screen keyboard, and the keys waiting to be typed.
    property var keyboards: []
    property var keyQueue: []
    readonly property bool keyboardShown: shell.prefBool("barKeyboard", true)
    // The floating on-screen keyboard and the screen it was opened on.
    property bool keyboardOskOpen: false
    property var keyboardOskScreen: null

    // The link's latency and traffic, read once for the whole bar (the two
    // chips and the two popups show the same measure). The preference turns
    // the reading off, not just the line.
    property var linkStats: ({})
    readonly property bool linkStatsShown: shell.prefBool("networkMetrics", true)
    onLinkStatsShownChanged: if (!shell.linkStatsShown) shell.linkStats = ({})

    // Bluetooth: `vitrail.network bluetooth` prints the adapter, its power and
    // its devices; the chip and the connection popup's Bluetooth tab share it.
    property var bluetoothDevices: ({})

    function refreshPowerProfile() {
        powerRead.run(Commands.powerProfile(), "")
    }

    function refreshKeyboards() {
        if (!keyboardRead.running)
            keyboardRead.running = true
    }

    function readKeyboards(text) {
        shell.keyboards = Keyboard.parse(text)
    }

    // The chosen layout goes first, so it becomes the active one while the
    // other layouts stay a switch away.
    function applyKeyboardLayout(layout) {
        var order = Keyboard.orderFor(shell.keyboards, layout)
        keyboardWrite.run(Keyboard.switchCommand(order.layout, order.variant), layout)
    }

    // Keys arrive faster than one `wtype` exits: they wait their turn, so
    // "hola" never reaches the focused window out of order.
    function typeKey(argv) {
        if (!argv || argv.length === 0)
            return
        shell.keyQueue.push(argv)
        if (!oskType.running)
            shell.runNextKey()
    }

    function typeText(text) {
        if (String(text || "") !== "")
            shell.typeKey(Wtype.typed(text))
    }

    function typeKeyName(name) {
        if (String(name || "") !== "")
            shell.typeKey(Wtype.key(name))
    }

    function runNextKey() {
        var next = shell.keyQueue.shift()
        if (!next)
            return
        oskType.command = next
        oskType.running = true
    }

    // The floating keyboard: bottom centre of the focused screen, independent
    // of the bar and its button. It never takes the keyboard focus.
    function openKeyboardOsk() {
        var target = shell.focusedScreen || shell.primaryScreen
        if (!target)
            return
        shell.closePopup()
        shell.keyboardOskScreen = target
        shell.keyboardOskOpen = true
        shell.refreshKeyboards()
        shell.grabKeyboardEscape(true)
    }

    function closeKeyboardOsk() {
        if (!shell.keyboardOskOpen)
            return
        shell.keyboardOskOpen = false
        shell.keyboardOskScreen = null
        shell.grabKeyboardEscape(false)
    }

    function toggleKeyboardOsk() {
        if (shell.keyboardOskOpen)
            shell.closeKeyboardOsk()
        else
            shell.openKeyboardOsk()
    }

    // Without keyboard focus the window cannot see Escape, so a Hyprland bind
    // closes it while it is up. The bind is reused and only enabled meanwhile.
    function grabKeyboardEscape(active) {
        oskEscape.run(["hyprctl", "eval", active
            ? 'if _vitrail_osk_esc then _vitrail_osk_esc:set_enabled(true) else _vitrail_osk_esc = hl.bind("ESCAPE", hl.dsp.exec_cmd("vitrail-bar ipc -i ' + Quickshell.instanceId + ' call keyboard close"), { description = "vitrail/keyboard-close" }) end'
            : 'if _vitrail_osk_esc then _vitrail_osk_esc:set_enabled(false) end'], "")
    }

    function refreshToggles() {
        wifiRead.run(Commands.wifiState(), "")
        btRead.run(Commands.bluetoothState(), "")
        micRead.run(Commands.micState(), "")
        airplaneRead.run(Commands.airplaneState(), "")
    }

    function toggleQuick(key) {
        if (key === "wifi")
            wifiWrite.run(Commands.wifiSet(!shell.wifiOn), "")
        else if (key === "bluetooth")
            btWrite.run(Commands.bluetoothSet(!shell.bluetoothOn), "")
        else if (key === "mic")
            micWrite.run(Commands.micToggle(), "")
        else if (key === "airplane")
            airplaneWrite.run(Commands.airplaneSet(!shell.airplaneOn), "")
        else if (key === "dnd") {
            shell.dnd = !shell.dnd
            shell.setPref("notificationDnd", shell.dnd ? "true" : "false")
        }
    }

    // Now playing: the players the bar follows, one per application. An app
    // can expose several MPRIS services (Firefox: its own, the browser
    // integration, and the playerctld proxy); they share a desktop entry, so
    // that keys the app (then the identity, then the bus name), lowercased. The
    // playerctld proxy only mirrors whichever player is active, so it is
    // skipped. Of the instances of one app, the one playing wins.
    readonly property var mprisPlayers: {
        var all = Mpris.players.values
        var at = ({})
        var out = []
        for (var i = 0; i < all.length; i++) {
            var item = all[i]
            if ((item.dbusName || "").indexOf("playerctld") >= 0)
                continue
            var key = (item.desktopEntry || item.identity || item.dbusName || "").trim().toLowerCase()
            if (at[key] === undefined) {
                at[key] = out.length
                out.push(item)
            } else if (item.isPlaying && !out[at[key]].isPlaying) {
                out[at[key]] = item
            }
        }
        return out
    }
    property int mprisIndex: 0
    readonly property var mprisPlayer: shell.mprisPlayers.length > 0
                                        ? shell.mprisPlayers[Math.min(shell.mprisIndex, shell.mprisPlayers.length - 1)]
                                        : null
    onMprisPlayersChanged: if (shell.mprisIndex >= shell.mprisPlayers.length)
        shell.mprisIndex = 0

    // The mode the next launcher opens in (see the launcher IPC).
    property string launcherMode: ""
    // The full-screen launcher: open, and on which screen.
    property bool launcherOpen: false
    // What the last scan found when the launcher opened: its list, plus any
    // app installed while the shell was running.
    property var launcherScanned: []
    property var launcherScreen: null

    // Left click and Super: the full-screen launcher on that monitor (the
    // focused one without a screen); the popout is the right click.
    function toggleLauncher(screen, mode) {
        var target = screen || shell.focusedScreen
        if (shell.launcherOpen && shell.launcherScreen === target && !mode) {
            shell.launcherOpen = false
            return
        }
        // Every opening re-reads the application folders, so an app installed
        // while the shell was running shows up.
        launcherScan.run(Commands.scanDesktop(), "")
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
    // The open popup was moved there by hovering its button: the next click on
    // that button confirms it instead of closing it.
    property bool popupByHover: false

    // Opens the panel on `screen` (the monitor whose hot zone asked, or the
    // focused one), and moves it there if it was open somewhere else.
    function openNotifications(screen) {
        var target = screen || shell.focusedScreen || shell.primaryScreen
        if (target)
            shell.notificationsScreen = target
        shell.notificationsOpen = true
    }

    // The bell beside the launcher: open on this monitor, close the same one.
    function toggleNotifications(screen) {
        if (shell.notificationsOpen && shell.notificationsScreen === screen)
            shell.notificationsOpen = false
        else
            shell.openNotifications(screen)
    }

    // A right click on the bell: silence for an hour (or turn it off when it
    // was already on). The preference keeps it across a reload; the timer
    // below ends it.
    function toggleNotificationMute() {
        if (shell.dnd) {
            shell.dnd = false
            shell.setPref("notificationDnd", "false")
            shell.setPref("notificationMuteUntil", "0")
            return
        }
        shell.dnd = true
        shell.setPref("notificationDnd", "true")
        shell.setPref("notificationMuteUntil", String(Date.now() + 60 * 60 * 1000))
    }

    function expireNotificationMute() {
        var until = Number(shell.prefs.notificationMuteUntil || 0)
        if (!(until > 0) || Date.now() < until)
            return
        shell.setPref("notificationMuteUntil", "0")
        if (shell.dnd) {
            shell.dnd = false
            shell.setPref("notificationDnd", "false")
        }
    }

    // The muted list and the stats share the panel's second slot.
    function toggleNotificationList(which) {
        if (which === "muted") {
            shell.notificationsMutedShown = !shell.notificationsMutedShown
            if (shell.notificationsMutedShown)
                shell.notificationsStatsShown = false
        } else {
            shell.notificationsStatsShown = !shell.notificationsStatsShown
            if (shell.notificationsStatsShown)
                shell.notificationsMutedShown = false
        }
    }

    // --- notifications: what their buttons ask for ---------------------------
    // copy, snooze, mute, mark as read, open an attachment. The id is the row
    // the card belongs to.
    function notificationAction(kind, value, id) {
        var row = toasts.row(id)
        if (kind === "copy") {
            var text = row ? row.summary + (row.body ? "\n" + row.body : "") : ""
            if (text !== "") {
                shell.copyText(text)
                toasts.markActed(id)
            }
        } else if (kind === "snooze") {
            if (shell.snoozeEnabled)
                toasts.snooze(id, value)
        } else if (kind === "mute") {
            shell.toggleMute(row ? row.appName : "")
            toasts.markActed(id)
        } else if (kind === "unmute") {
            shell.toggleMute(value)
        } else if (kind === "read") {
            toasts.dismiss(id)
        } else if (kind === "open") {
            shell.openAttachment(value)
        }
    }

    // The app goes in or out of the muted list (comma-separated preference).
    function toggleMute(app) {
        if (!app)
            return
        var apps = Notifications.list(shell.prefs.notificationMuted)
        var at = apps.indexOf(app)
        if (at >= 0)
            apps.splice(at, 1)
        else
            apps.push(app)
        shell.setPref("notificationMuted", Notifications.joined(apps))
    }

    // What the store keeps of the centre, as one JSON text.
    function queueDocument() {
        return JSON.stringify(toasts.snapshot())
    }

    // Writing is debounced: a burst of arrivals is one file.
    function storeNotifications() {
        if (shell.restoringNotifications)
            return
        var text = shell.queueDocument()
        if (text === shell.storedNotifications)
            return
        shell.storedNotifications = text
        notifyWriter.pending = text
        if (!notifyWriter.running)
            notifyWriter.running = true
    }

    // The rows of an earlier session come back into the panel.
    function loadNotifications(text) {
        var document
        try {
            document = JSON.parse(text)
        } catch (error) {
            return
        }
        shell.restoringNotifications = true
        toasts.restore(document)
        shell.restoringNotifications = false
    }

    // The snoozes whose time is up come back as new notifications, one at a
    // time so none is lost.
    function wakeSnoozes() {
        var result = Notifications.dueSnoozes(shell.prefs.notificationSnoozes, Date.now())
        if (result.due.length === 0)
            return
        shell.setPref("notificationSnoozes", result.rest)
        for (var i = 0; i < result.due.length; i++)
            snoozeSend.pending.push(JSON.stringify(result.due[i]))
        shell.sendNextSnooze()
    }

    function sendNextSnooze() {
        if (snoozeSend.running)
            return
        var next = snoozeSend.pending.shift()
        if (next === undefined)
            return
        snoozeSend.exec(["python3", "-m", "vitrail.notify", "send", next])
    }

    // A notification of the bar's own, through the same server (and the same
    // queue) as a snooze that is due: it never takes the focus.
    function postNotification(summary, body, icon) {
        snoozeSend.pending.push(JSON.stringify({
            app: "Vitrail",
            icon: icon || "notifications",
            summary: summary,
            body: body || ""
        }))
        shell.sendNextSnooze()
    }

    // A pomodoro phase or a timer ran out.
    function timerFinished(kind, phase) {
        if (kind === "timer") {
            shell.postNotification(shell.t("dashboard.timer.done"),
                                   shell.t("dashboard.timer.done.body"), "timer")
            return
        }
        if (phase === "work")
            shell.postNotification(shell.t("dashboard.pomodoro.workDone"),
                                   shell.t("dashboard.pomodoro.workDone.body"), "coffee")
        else
            shell.postNotification(shell.t("dashboard.pomodoro.restDone"),
                                   shell.t("dashboard.pomodoro.restDone.body"), "work")
    }

    // A picture or file attachment opens with the desktop's file manager; a
    // web link with the browser.
    function openAttachment(path) {
        var local = String(path || "")
        if (local === "")
            return
        if (local.indexOf("file://") === 0)
            local = decodeURIComponent(local.slice(7))
        if (!/^(\/|~)/.test(local)) {
            Qt.openUrlExternally(local)
            return
        }
        openPath.exec(["python3", "-m", "vitrail.files", "open", local])
    }

    function openClipboard(mode) {
        var screen = shell.focusedScreen
        if (!screen)
            return
        shell.clipboardMode = mode || "history"
        if (shell.clipboardMode === "emoji")
            shell.ensureEmojis()
        shell.clipboardScreen = screen
        shell.clipboardOpen = true
        cursorRun.run(["hyprctl", "cursorpos"], "")
        clipList.run(Commands.clipList(), "")
    }

    // The emoji tab asks for the set when it is shown, however it was opened.
    function ensureEmojis() {
        if (shell.emojiPath === "")
            shell.emojiPath = Quickshell.shellDir + "/../assets/emoji.json"
    }

    // The first time an image entry is on screen, its bytes go to a PNG the
    // Image can load; the path is kept so it is decoded once.
    function requestThumb(id) {
        if (shell.clipboardThumbs[id] || shell.clipboardPending[id])
            return
        shell.clipboardPending[id] = true
        var path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrail-clip-" + id + ".png"
        thumbRun.run(["sh", "-c", "cliphist decode \"$1\" > \"$2\"", "sh", id, path], id + "\t" + path)
    }

    // Enter copies (and pastes if the preference says so), Shift+Enter only
    // copies, Ctrl+Enter copies without the trailing newline for a terminal.
    // Any text to the clipboard: an emoji, a colour.
    function copyText(text) {
        if (String(text || "") === "")
            return
        copyRun.run(Commands.copyText(text), "")
    }

    // The colour tab: remember it, keep the last ten, copy it in the format.
    function useColor(hex) {
        if (!Colors.isColor(hex))
            return
        shell.clipboardColor = hex
        shell.clipboardRecent = Colors.addRecent(shell.clipboardRecent, hex, Colors.RECENT)
        shell.setPref("clipboardColors", JSON.stringify(shell.clipboardRecent))
        shell.copyText(Colors.format(Colors.parse(hex), shell.clipboardFormat))
    }

    // An emoji goes into the clipboard and into the field that had the focus:
    // the panel closes first, then the text is typed where it was.
    function pickEmoji(emoji) {
        if (String(emoji || "") === "")
            return
        shell.copyText(emoji)
        shell.clipboardOpen = false
        emojiDelay.emoji = emoji
        emojiDelay.restart()
    }

    // The colour picker needs the screen to itself: close the panel, wait a
    // frame, then run it.
    function pickColor() {
        shell.clipboardOpen = false
        pickDelay.restart()
    }

    function pickClip(id, mode) {
        var command = mode === "terminal" ? Commands.clipCopyTrimmed(id) : Commands.clipCopy(id)
        clipPick.run(command, id + "\t" + mode)
        shell.clipboardOpen = false
    }

    function removeClip(id) {
        clipRemove.run(Commands.clipDelete(id), id)
    }

    function clearClips() {
        shell.clipboardEntries = []
        clipClear.run(Commands.clipWipe(), "")
    }

    // The button of a popup on a screen's bar, for popups opened without one.
    function anchorOf(kind, screen) {
        var monitor = screen ? shell.monitors[screen.name] : null
        return monitor ? monitor.anchorFor(kind) : null
    }

    // The popup opens on the screen of the bar element that invoked it, or
    // the focused monitor when there is none (IPC), anchored on its own
    // button there.
    function openPopup(kind, item, screen) {
        shell.popupByHover = false
        shell.launcherOpen = false
        if (shell.keyboardOskOpen)
            shell.closeKeyboardOsk()
        // A fresh popup gets its full leave grace, not the one left over from
        // the pointer leaving the previous one.
        popupLeave.stop()
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
        if (kind === "powerprofile")
            shell.refreshPowerProfile()
        if (kind === "keyboard")
            shell.refreshKeyboards()
        if (kind === "network" || kind === "vpn")
            if (!linkRead.running)
                linkRead.running = true
        if (kind === "bluetooth" && !bluetoothRead.running)
            bluetoothRead.running = true
        shell.popupKind = kind
        shell.popupOpen = true
    }

    function togglePopup(kind, item, screen) {
        if (shell.popupOpen && shell.popupKind === kind) {
            // A popup the pointer already brought here: the click confirms it.
            if (shell.popupByHover)
                shell.popupByHover = false
            else
                shell.closePopup()
        } else {
            shell.openPopup(kind, item, screen)
        }
    }

    // Hovering an element that has a popup moves an open popup to it (never
    // opens one from closed).
    function hoverPopup(kind, item, screen) {
        if (shell.popupOpen && (shell.popupKind !== kind || shell.popupScreen !== screen)) {
            shell.openPopup(kind, item, screen)
            shell.popupByHover = true
        }
    }

    function closePopup() {
        shell.popupByHover = false
        shell.trayMenuItem = null
        shell.popupOpen = false
        popupLeave.stop()
    }

    // The one close rule: the popup may close only once the pointer has left
    // the card, the tray app's menu beside it and the button it grew from.
    // The tracked pointer is trusted only on a surface that says where it is
    // (the popup layer or the bar); over an app it is on neither, so "out".
    function pointerInsidePopup() {
        var monitor = shell.popupScreen ? shell.monitors[shell.popupScreen.name] : null
        if (!monitor)
            return false
        // The card and menu handlers are ground truth; the tracked point is
        // the refinement that also covers the gap and the invoking button.
        if (monitor.popupHovered)
            return true
        if (shell.popupPointerScreen === shell.popupScreen)
            return monitor.popupContains(shell.popupPointerAt)
        if (shell.barPointerScreen === shell.popupScreen)
            return monitor.anchorContains(shell.barPointerAt)
        return false
    }

    // The session menu (lock, log out, power) covers the screen whose button
    // opened it, or the focused monitor.
    property bool sessionOpen: false
    property var sessionScreen: null
    property bool canHibernate: false
    // The question an action started: { key, phase: "check"|"problem"|
    // "countdown", jobs, deadline }, and the time its countdown reads.
    property var sessionPending: null
    property real sessionNow: Date.now()

    function toggleSession(screen) {
        shell.closePopup()
        shell.launcherOpen = false
        shell.sessionScreen = screen || shell.focusedScreen
        shell.sessionOpen = !shell.sessionOpen
    }

    // What the menu asks. A lock runs at once; every action that cuts work is
    // checked first, and then asks (the countdown) or runs (log out).
    function runSession(key) {
        var action = Session.find(key)
        if (!action)
            return
        shell.sessionOpen = false
        shell.closePopup()
        if (!Session.interrupting(key)) {
            shell.executeSession(key)
            return
        }
        shell.sessionPending = { key: key, phase: "check", jobs: [] }
        sessionCheck.running = true
    }

    // The guard's answer: what is running turns into the alert; nothing does,
    // and the action goes on.
    function sessionChecked(text) {
        var pending = shell.sessionPending
        if (!pending || pending.phase !== "check")
            return
        var found = []
        try {
            found = JSON.parse(text).jobs || []
        } catch (error) {
            found = []
        }
        if (found.length > 0) {
            shell.sessionPending = { key: pending.key, phase: "problem", jobs: found }
            return
        }
        shell.beginSession(pending.key)
    }

    // After the guard: a countdown when the action asks, otherwise it runs.
    function beginSession(key) {
        if (!Session.confirmable(key)) {
            shell.executeSession(key)
            return
        }
        shell.sessionNow = Date.now()
        shell.sessionPending = {
            key: key, phase: "countdown", jobs: [],
            deadline: shell.sessionNow + Session.SECONDS * 1000
        }
    }

    // "Do it now", "Go ahead", and the end of the countdown.
    function confirmSession() {
        var pending = shell.sessionPending
        if (!pending)
            return
        if (pending.phase === "problem")
            shell.beginSession(pending.key)
        else
            shell.executeSession(pending.key)
    }

    // Cancel stops the action and returns to the menu.
    function cancelSession() {
        var pending = shell.sessionPending
        shell.sessionPending = null
        if (pending && pending.phase !== "check" && shell.sessionScreen)
            shell.sessionOpen = true
    }

    function executeSession(key) {
        var action = Session.find(key)
        shell.sessionPending = null
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
    // A preference that reads as a switch (missing or empty: `fallback`).
    function prefBool(key, fallback) {
        var raw = shell.prefs[key]
        if (raw === undefined || raw === "")
            return fallback
        return String(raw) !== "false" && String(raw) !== "0"
    }
    // Screenshots and recording: the module reads the folders and flags from
    // capture.ini, so the call carries only the mode.
    function captureShot(mode) {
        vitrailCli.exec(["python3", "-m", "vitrail.capture", "shot", mode])
    }

    function toggleRecording() {
        vitrailCli.exec(["python3", "-m", "vitrail.capture", "record", "toggle"])
    }

    function readRecordStatus(text) {
        try {
            var document = JSON.parse(text)
            shell.recording = document.pid !== undefined
            shell.recordPath = document.path || ""
        } catch (error) {
            shell.recording = false
            shell.recordPath = ""
        }
    }

    // A numeric preference; zero is a value, not a missing one.
    function prefNumber(key, fallback) {
        var raw = shell.prefs[key]
        if (raw === undefined || raw === "")
            return fallback
        var value = Number(raw)
        return isNaN(value) ? fallback : value
    }
    property var palettes: ({})
    property date now: new Date()
    // Last panel variant opened; it is kept while the panel closes so the
    // closing animation matches the opening one.
    property string panelKind: ""
    property bool panelOpen: false

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME")
                                        || Quickshell.env("HOME") + "/.cache") + "/vitrail"
    readonly property string generatedDir: shell.cacheDir + "/generated"
    // The audio visualiser's spectrum: the runtime file vitrail.visualiser
    // writes, and whether there is anything to draw.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property var visualiserValues: []
    readonly property bool visualiserEnabled: shell.prefBool("visualiserEnabled", false)
    readonly property bool audioPlaying: osdController.outputApps.length > 0
    readonly property string visualiserVariant: shell.prefs.visualiserVariant || VitrailStyle.defaults.visualiser
    readonly property bool visualiserActive: shell.visualiserEnabled && shell.audioPlaying
                                             && shell.visualiserValues.length > 0
    // Whether any monitor places a desktop widget; the data services run only
    // then, and an empty document costs nothing.
    readonly property bool desktopWidgetsActive: Layouts.desktopCount(shell.prefs.desktopLayout || "") > 0
    onVisualiserEnabledChanged: if (!shell.visualiserEnabled) shell.visualiserValues = []
    onAudioPlayingChanged: if (!shell.audioPlaying) shell.visualiserValues = []
    // The palette both modes use, written with the theme files by
    // `vitrail colors` (`vitrail/colors.py`). Reading it is one small file
    // instead of a Python spawn.
    readonly property string paletteStore: shell.generatedDir + "/palette.json"
    // Bumped on every new palette: a regenerated SVG of the same name reloads.
    property int paletteVersion: 0
    // An adaptive SVG is shown recoloured for the current mode.
    readonly property string wallpaperEffect: Effects.of(shell.prefs.wallpaperEffect)
    // The picture one output draws: its own override (and effect) when it has
    // one, otherwise the global wallpaper.
    function wallpaperFor(name) {
        var global = shell.prefs.wallpaper || ""
        var path = global
        var effect = shell.wallpaperEffect
        var entry = WallpaperMonitors.of(shell.prefs.wallpaperMonitors || "", name)
        // An adaptive SVG is drawn from the generated copy of the global one.
        if (entry.wallpaper !== "" && !/\.svg$/i.test(entry.wallpaper))
            path = entry.wallpaper
        if (entry.effect !== "")
            effect = Effects.of(entry.effect)
        // The effect is baked into a stable file apply-settings writes.
        if (effect !== "none" && Effects.isImage(path))
            return shell.cacheDir + "/" + Effects.shown(name)
        if (!/\.svg$/i.test(path))
            return path
        return shell.generatedDir + "/wallpaper-" + (shell.dark ? "dark" : "light") + ".svg"
    }
    readonly property string wallpaperSource: shell.wallpaperFor("")
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
    readonly property string notificationSide: Notifications.sideFor(
        shell.prefs.notificationPosition, shell.prefs.barEdge || "left")
    readonly property string osdEdge: Osd.edgeFor(shell.notificationSide,
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
    // The screen the toasts appeared on: they stay there until the last one
    // is gone, even if the focus moves, and a new one joins them there.
    property var toastScreen: null

    Connections {
        target: toasts.shown

        function onCountChanged() {
            if (toasts.shown.count === 0)
                shell.toastScreen = null
            else if (!shell.toastScreen)
                shell.toastScreen = shell.notificationScreen
        }
    }

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
        if (shell.prefs.fontSystem)
            values.fontFamily = shell.prefs.fontSystem
        return values
    }

    // The icon family follows `uiIcons` through a binding of its own, so the
    // bar redraws its ligatures the moment the settings window writes
    // fonts.ini: no handler and no token snapshot stands in the way.
    Binding {
        target: VitrailTokens
        property: "iconVariant"
        value: VitrailTokens.font.iconVariantOf(shell.prefs.uiIcons)
    }

    onTokenValuesChanged: shell.syncTokens()
    onDarkChanged: {
        shell.syncTokens()
        // The automatic switch at 07:00 / 19:00 reaches the other apps too.
        vitrailCli.exec(["python3", "-m", "vitrail.cli", "theme", "apply", "--mode", shell.dark ? "dark" : "light"])
    }
    Component.onCompleted: {
        shell.startupMark("configuration complete")
        shell.syncTokens()
        shell.refreshKeyboards()
        // A previous bar may have left the Escape bind of its keyboard enabled.
        shell.grabKeyboardEscape(false)
    }
    Component.onDestruction: if (shell.keyboardOskOpen) shell.grabKeyboardEscape(false)

    // The dashboard's pomodoro and timer: kept here, not in the popup, so a
    // running session goes on while the popup is closed and survives a reload
    // (the state and end time live in misc.ini).
    TimerEngine {
        id: focusTimers

        workMinutes: shell.prefNumber("pomodoroWork", VitrailTokens.ranges.pomodoroWork.value)
        restMinutes: shell.prefNumber("pomodoroRest", VitrailTokens.ranges.pomodoroRest.value)
        cycles: shell.prefNumber("pomodoroCycles", VitrailTokens.ranges.pomodoroCycles.value)
        timerMinutes: shell.prefNumber("timerMinutes", VitrailTokens.ranges.timerMinutes.value)
        savedPomodoro: shell.prefs.pomodoroState || ""
        savedTimer: shell.prefs.timerState || ""
        onPersist: function (key, value) { shell.setPref(key, value) }
        onFinished: function (kind, phase) { shell.timerFinished(kind, phase) }
    }

    // The desktop widgets' services, shared by every monitor (unlike the
    // dashboard popup, which runs them only while its tab is open).
    DesktopData {
        id: desktopData

        active: shell.desktopWidgetsActive
    }

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

    // The clipboard store reads its limit from its own file: keep it in step
    // with the preference at every start.
    Process {
        running: true
        command: ["python3", "-m", "vitrail.cli", "clipboard", "apply"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    // The VPN's login rule is a systemd user unit (`vitrail-vpn-autostart.service`,
    // installed with the dotfiles), not a process of the bar: the tunnel must
    // come up after a login even when Quickshell was never started, and a bar
    // restart must not repeat what the login did.

    // Downloads: the watcher turns the files a downloader is still writing
    // (.part, .crdownload…) into notifications on this same server, replaced
    // in place as they grow, with Cancel and the finished file's buttons
    // (vitrail/downloads.py). It scans once a second and exits with the bar, so a
    // bar restart never leaves an orphan behind.
    Process {
        running: true
        command: ["python3", "-m", "vitrail.downloads", "watch"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    // The visualiser's cava runs only while the preference is on and an app
    // is playing audio; when either stops, the Process ends and the supervisor
    // clears its runtime file.
    Process {
        running: shell.visualiserEnabled && shell.audioPlaying
        command: ["python3", "-m", "vitrail.visualiser", "start"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    // The last frame the supervisor wrote (vitrail/visualiser.py).
    FileView {
        path: shell.runtimeDir + "/vitrail/cava.json"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: {
            try {
                var document = JSON.parse(this.text())
                shell.visualiserValues = document.values || []
            } catch (error) {
                shell.visualiserValues = []
            }
        }
        onLoadFailed: shell.visualiserValues = []
    }

    // The bar reads the preference files with its own parser, so the CLI is
    // what writes them. Writes go one at a time; a newer value for the same
    // key waits its turn.
    Process {
        id: prefWriter

        property var queue: []
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        onExited: shell.writeNextPref()
    }

    function setPref(key, value) {
        prefWriter.queue.push([key, value])
        if (!prefWriter.running)
            shell.writeNextPref()
    }

    // The VPN popup asks for a measurement the way the settings window does:
    // the request first, its counter second (scripts/apply-settings.sh runs it).
    function requestVpnProbe() {
        shell.setPref("connectionRequest", "vpn-probe")
        shell.setPref("connectionSeq", String((Number(shell.prefs.connectionSeq) || 0) + 1))
    }

    function writeNextPref() {
        var next = prefWriter.queue.shift()
        if (!next)
            return
        prefWriter.command = ["python3", "-m", "vitrail.cli", "config", "set", next[0], next[1]]
        prefWriter.running = true
    }

    // What `vitrail.network link` answered: the interface, one echo and the
    // rate since the previous read.
    function readLinkStats(text) {
        try {
            shell.linkStats = JSON.parse(text)
        } catch (error) {
            shell.linkStats = ({})
        }
    }

    function readBluetoothDevices(text) {
        try {
            var document = JSON.parse(text)
            shell.bluetoothDevices = document && typeof document === "object" ? document : ({})
        } catch (error) {
            shell.bluetoothDevices = ({})
        }
    }

    // While the connection popup is up: one echo (a second at most) and two
    // counter files. The chips keep the last reading between openings.
    Process {
        id: linkRead

        command: ["python3", "-m", "vitrail.network", "link"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: shell.readLinkStats(this.text)
        }
    }

    Timer {
        interval: 10000
        running: shell.linkStatsShown && shell.popupOpen
                 && (shell.popupKind === "network" || shell.popupKind === "vpn")
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!linkRead.running) linkRead.running = true
    }

    // The Bluetooth chip and its popup: one read of the adapter and its
    // devices every twenty seconds (without an adapter the command only checks
    // /sys and returns).
    Process {
        id: bluetoothRead

        command: ["python3", "-m", "vitrail.network", "bluetooth"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: shell.readBluetoothDevices(this.text)
        }
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!bluetoothRead.running) bluetoothRead.running = true
    }

    // The clipboard's programs: the history, a thumbnail, a pick, the paste.
    AsyncRun {
        id: clipList

        onFinished: function (tag, output) {
            shell.clipboardEntries = Commands.parseClips(output, Number(shell.prefs.clipboardMax) || 100)
        }
    }

    AsyncRun {
        id: cursorRun

        onFinished: function (tag, output) {
            var parts = String(output).trim().split(",")
            if (parts.length !== 2)
                return
            shell.clipboardX = Number(parts[0])
            shell.clipboardY = Number(parts[1])
        }
    }

    AsyncRun {
        id: thumbRun

        onFinished: function (tag, output) {
            var parts = String(tag).split("\t")
            if (parts.length !== 2)
                return
            delete shell.clipboardPending[parts[0]]
            var next = {}
            for (var key in shell.clipboardThumbs)
                next[key] = shell.clipboardThumbs[key]
            next[parts[0]] = "file://" + parts[1]
            shell.clipboardThumbs = next
        }
    }

    AsyncRun {
        id: clipPick

        onFinished: function (tag, output) {
            var mode = String(tag).split("\t")[1] || "default"
            if (mode === "copy")
                return
            if (Notifications.enabled(shell.prefs.clipboardPaste))
                pasteRun.run(Commands.clipPaste(), "")
        }
    }

    AsyncRun {
        id: copyRun
    }

    // The quick toggles: each reader stores what the tool printed, each writer
    // asks for a fresh read once it is done.
    AsyncRun {
        id: wifiRead

        onFinished: function (tag, output) { shell.wifiOn = Toggles.wifiOn(output) }
    }

    AsyncRun {
        id: wifiWrite

        onFinished: function (tag, output) { shell.refreshToggles() }
    }

    AsyncRun {
        id: btRead

        onFinished: function (tag, output) {
            shell.bluetoothOn = Toggles.bluetoothOn(output)
            shell.bluetoothPresent = Toggles.bluetoothPresent(output)
        }
    }

    AsyncRun {
        id: btWrite

        onFinished: function (tag, output) { shell.refreshToggles() }
    }

    AsyncRun {
        id: powerRead

        onFinished: function (tag, output) { shell.powerProfile = Connection.powerProfile(output) }
    }

    AsyncRun {
        id: powerWrite

        onFinished: function (tag, output) { shell.refreshPowerProfile() }
    }

    // The keyboards Hyprland has added, and the layout switch through its Lua
    // config. The switch reads the keyboards again once it is applied.
    Process {
        id: keyboardRead

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: shell.readKeyboards(this.text)
        }
    }

    Timer {
        interval: 5000
        running: shell.keyboardShown
        repeat: true
        triggeredOnStart: true
        onTriggered: shell.refreshKeyboards()
    }

    AsyncRun {
        id: keyboardWrite

        onFinished: function (tag, output) {
            shell.closePopup()
            shell.refreshKeyboards()
        }
    }

    // One `wtype` at a time, in the order the keys were pressed.
    Process {
        id: oskType

        onExited: shell.runNextKey()
    }

    AsyncRun {
        id: oskEscape
    }

    AsyncRun {
        id: airplaneRead

        onFinished: function (tag, output) { shell.airplaneOn = Toggles.airplaneOn(output) }
    }

    AsyncRun {
        id: airplaneWrite

        onFinished: function (tag, output) { shell.refreshToggles() }
    }

    AsyncRun {
        id: micRead

        onFinished: function (tag, output) { shell.micMuted = Toggles.micMuted(output) }
    }

    AsyncRun {
        id: micWrite

        onFinished: function (tag, output) { shell.refreshToggles() }
    }

    // Opening the panel reads the state at once, and while it is open the
    // state is kept fresh in case something else changes it.
    onNotificationsOpenChanged: if (shell.notificationsOpen)
        shell.refreshToggles()

    // While the panel is open the state is kept fresh, in case something else
    // changes it.
    Timer {
        interval: 3000
        repeat: true
        running: shell.notificationsOpen
        onTriggered: shell.refreshToggles()
    }

    AsyncRun {
        id: launcherScan

        onFinished: function (tag, output) { shell.launcherScanned = LauncherDesktop.parseScan(output) }
    }

    // The application folders, watched so a shortcut installed while the shell
    // runs shows up at once. The listing's fingerprint is compared every two
    // seconds (no extra tool needed); a change triggers the same scan the
    // launcher uses when it opens.
    Process {
        id: desktopWatch

        running: true
        command: ["sh", "-c",
            "last=''; while :; do " +
            "sig=$(find \"$HOME/.local/share/applications\" /usr/local/share/applications /usr/share/applications " +
            "-maxdepth 1 -name '*.desktop' -printf '%p %T@ %s\\n' 2>/dev/null | md5sum); " +
            "if [ \"$sig\" != \"$last\" ]; then [ -n \"$last\" ] && echo changed; last=$sig; fi; sleep 2; done"]
        stdout: SplitParser {
            onRead: function (line) { if (line === "changed") appScanDebounce.restart() }
        }
    }

    Timer {
        id: appScanDebounce

        interval: 400
        onTriggered: launcherScan.run(Commands.scanDesktop(), "")
    }

    // The screen picker: `hyprpicker -f hex` prints the colour and exits.
    Timer {
        id: pickDelay

        interval: VitrailTokens.duration("base")
        onTriggered: colorPick.run(Commands.colorPicker(), "")
    }

    Timer {
        id: emojiDelay

        property string emoji: ""

        interval: VitrailTokens.duration("base")
        onTriggered: {
            if (emoji !== "")
                typeRun.run(Commands.typeText(emoji), "")
            emoji = ""
        }
    }

    AsyncRun {
        id: typeRun
    }

    AsyncRun {
        id: colorPick

        onFinished: function (tag, output) { shell.useColor(String(output).trim()) }
    }

    AsyncRun {
        id: clipRemove

        onFinished: clipList.run(Commands.clipList(), "")
    }

    AsyncRun {
        id: clipClear

        onFinished: clipList.run(Commands.clipList(), "")
    }

    AsyncRun {
        id: pasteRun
    }

    // The emoji set, built from Unicode by scripts/build-emoji.py. Its path is
    // empty until the emoji tab opens (see ensureEmojis), so the 520 KB file is
    // never parsed to draw the bar.
    FileView {
        path: shell.emojiPath
        printErrors: false
        onLoaded: {
            try {
                shell.clipboardEmojis = JSON.parse(this.text())
            } catch (error) {
                shell.clipboardEmojis = []
            }
            shell.startupMark("emojis loaded")
        }
        onLoadFailed: shell.clipboardEmojis = []
    }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrail/record.json"
        watchChanges: true
        printErrors: false
        onLoaded: shell.readRecordStatus(this.text())
        onFileChanged: this.reload()
        onLoadFailed: shell.readRecordStatus("{}")
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

    // The palette as a file, watched: a new wallpaper rewrites it and the bar
    // recolours. Only a cache without it (an upgrade, a fresh profile) falls
    // back to the Python reader, which writes it for the next start.
    FileView {
        path: shell.paletteStore
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: shell.readPalettes(this.text())
        onLoadFailed: if (!paletteJson.running) paletteJson.running = true
    }

    function readPalettes(text) {
        try {
            shell.palettes = JSON.parse(text)
        } catch (error) {
            shell.palettes = ({})
        }
        shell.paletteVersion++
        shell.startupMark("palette ready")
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

        step: shell.prefNumber("osdStep", VitrailTokens.ranges.osdStep.value)
        brightnessStep: shell.prefNumber("osdBrightnessStep", VitrailTokens.ranges.osdBrightnessStep.value)
        appStep: shell.prefNumber("soundStep", VitrailTokens.ranges.soundStep.value)
        showOutputApps: shell.prefBool("soundOutputApps", true)
        showInputApps: shell.prefBool("soundInputApps", true)
        focusApps: shell.prefBool("soundFocusApps", true)
    }

    NotificationQueue {
        id: toasts

        maximum: Number(shell.prefs.notificationMax) || VitrailTokens.ranges.notifications.value
        // The panel lists what arrives while it is open; Do Not Disturb does
        // the same unless the notification is urgent and the bypass is on; a
        // muted app is never toasted.
        panelOpen: shell.notificationsOpen
        dnd: shell.dnd
        urgentBypass: shell.prefs.notificationUrgentBypass === undefined
                      || Notifications.enabled(shell.prefs.notificationUrgentBypass)
        muted: shell.prefs.notificationMuted || ""
        urgent: shell.prefs.notificationUrgentApps || ""
    }

    // The centre's memory: the rows of earlier sessions, the per-app counts and
    // the snoozes. Read once at start; written, debounced, when they change.
    FileView {
        id: notifyFile

        path: shell.notifyStore
        printErrors: false
        onLoaded: {
            shell.loadNotifications(this.text())
            shell.storedNotifications = shell.queueDocument()
        }
    }

    Timer {
        id: notifyWrite

        interval: 400
        onTriggered: shell.storeNotifications()
    }

    Connections {
        target: toasts

        function onRevisionChanged() { notifyWrite.restart() }
        function onSnoozed(row, until) {
            shell.setPref("notificationSnoozes",
                          Notifications.addSnooze(shell.prefs.notificationSnoozes, row, until))
        }
    }

    Process {
        id: notifyWriter

        property string pending: ""

        stdinEnabled: true
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        command: ["python3", "-m", "vitrail.notify", "store"]
        onStarted: if (notifyWriter.pending !== "") {
            notifyWriter.write(notifyWriter.pending + "\n")
            notifyWriter.pending = ""
        }
        onExited: if (notifyWriter.pending !== "") notifyWriter.running = true
    }

    // A snoozed notification comes back as a new one, one at a time.
    Process {
        id: snoozeSend

        property var pending: []

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        onExited: shell.sendNextSnooze()
    }

    // Attachments open with the desktop's file manager (vitrail.files).
    Process {
        id: openPath

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: shell.wakeSnoozes()
    }

    // A one-hour silence from the bell ends by itself.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: shell.expireNotificationMute()
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
    // A recording is running: its state file is written by vitrail-capture.
    property bool recording: false
    property string recordPath: ""

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

    // What a session action would interrupt (vitrail/session.py): the alert
    // stays until the user accepts, and no countdown starts before that.
    Process {
        id: sessionCheck

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        command: ["python3", "-m", "vitrail.session", "check"]
        stdout: StdioCollector {
            onStreamFinished: shell.sessionChecked(this.text)
        }
    }

    // The countdown: the question reads the time and the action runs at zero.
    Timer {
        interval: 200
        running: shell.sessionPending !== null && shell.sessionPending.phase === "countdown"
        repeat: true
        onTriggered: {
            shell.sessionNow = Date.now()
            if (shell.sessionPending && Session.finished(shell.sessionPending.deadline, shell.sessionNow))
                shell.executeSession(shell.sessionPending.key)
        }
    }

    // A check that never answers (python missing, a broken install) must not
    // leave the full-screen layer waiting with nothing on it.
    Timer {
        interval: 2000
        running: shell.sessionPending !== null && shell.sessionPending.phase === "check"
        onTriggered: shell.sessionChecked("")
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

    // The keybind cheatsheet (bin/vitrail-binds, Super+/).
    IpcHandler {
        target: "binds"

        function toggle(): void {
            shell.togglePopup("binds", null, null)
        }

        function close(): void {
            shell.closePopup()
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
        target: "clipboard"

        function toggle(): void {
            if (shell.clipboardOpen)
                shell.clipboardOpen = false
            else
                shell.openClipboard("history")
        }

        function emoji(): void {
            shell.openClipboard("emoji")
        }

        function colors(): void {
            shell.openClipboard("color")
        }

        function pick(): void {
            shell.pickColor()
        }

        function close(): void {
            shell.clipboardOpen = false
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            if (shell.notificationsOpen)
                shell.notificationsOpen = false
            else
                shell.openNotifications(shell.focusedScreen)
        }

        function close(): void {
            shell.notificationsOpen = false
        }

        // The panel's "Clear all", for a script.
        function clear(): void {
            toasts.clear()
        }

        function muted(): void {
            shell.toggleNotificationList("muted")
            shell.openNotifications(shell.focusedScreen)
        }

        function stats(): void {
            shell.toggleNotificationList("stats")
            shell.openNotifications(shell.focusedScreen)
        }
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

    IpcHandler {
        target: "keyboard"

        function open(): void {
            shell.openKeyboardOsk()
        }

        function close(): void {
            shell.closeKeyboardOsk()
        }

        function toggle(): void {
            shell.toggleKeyboardOsk()
        }
    }

    Process {
        id: paletteJson

        // The fallback when palette.json is not there yet; --write leaves it
        // for the next start. Off the start-up path otherwise.
        command: ["python3", Quickshell.shellDir + "/../scripts/palette-json.py", "--write"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: shell.readPalettes(this.text)
        }
    }

    // The popup only takes input on its card, so a click elsewhere reaches
    // the bar or the app under it. An app that takes the focus closes the
    // popup only when the pointer is not on it (or on its button): a focus
    // change while the pointer reads the popup must not make it vanish.
    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            if (shell.popupOpen && !shell.pointerInsidePopup())
                shell.closePopup()
        }
    }

    // After the pointer leaves, the popup waits a moment (crossing the gap to
    // the tray app's menu, or back to the card, must not close it) and then
    // closes unless the pointer is still inside the popup or on its button.
    Timer {
        id: popupLeave

        interval: 3000
        onTriggered: {
            if (shell.pointerInsidePopup())
                popupLeave.restart()
            else
                shell.closePopup()
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

                // The bar elements this monitor loaded, by the id the layout
                // document gives them: a popup opened without a button (IPC)
                // still grows out of the right one.
                property var loaded: ({})

                function register(id, item) {
                    if (id)
                        monitor.loaded[id] = item
                }

                function unregister(id) {
                    if (id)
                        delete monitor.loaded[id]
                }

                function loadedItem(id) {
                    return monitor.loaded[id] === undefined ? null : monitor.loaded[id]
                }

                // The bar's layout document (bar.ini `barLayout`), read only
                // when the preference text changes so a setting elsewhere does
                // not rebuild the elements.
                readonly property string layoutText: shell.prefs.barLayout || ""
                readonly property var barDocument: Layouts.effective(monitor.layoutText, monitor.modelData.name)
                readonly property var hyprMonitor: Hyprland.monitorFor(monitor.modelData)
                readonly property bool fullscreen: !!(hyprMonitor
                    && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
                // A fullscreen window with the bar's own switch on: the bar
                // and the frame leave the screen alone.
                readonly property bool hiddenFullscreen: monitor.barDocument.hideFullscreen && monitor.fullscreen

                // The component of one element id, and of one layout entry (a
                // run of connection buttons draws inside one pill).
                function widgetComponent(id) {
                    switch (id) {
                    case "launcher": return launcherWidget
                    case "notifications": return notificationsWidget
                    case "media": return mediaWidget
                    case "clock": return clockWidget
                    case "capture": return captureWidget
                    case "recording": return recordingWidget
                    case "tray": return trayWidget
                    case "network": return networkWidget
                    case "bluetooth": return bluetoothWidget
                    case "vpn": return vpnWidget
                    case "profile": return profileWidget
                    case "battery": return batteryWidget
                    case "keyboard": return keyboardWidget
                    case "power": return powerWidget
                    default: return null
                    }
                }

                function entryComponent(entry) {
                    return entry && entry.cluster !== undefined ? chipWidget : monitor.widgetComponent(entry.id)
                }

                // Whether an entry has anything to show. The element itself
                // says so when it can (battery, Bluetooth); the rest read the
                // shell's state here, in whatever group the editor put them.
                function entryVisible(entry) {
                    if (!entry || entry.cluster !== undefined)
                        return true
                    switch (entry.id) {
                    case "media": return shell.mprisPlayer !== null
                    case "recording": return shell.recording
                    case "keyboard": return shell.keyboardShown
                    default: return true
                    }
                }

                // --- the bar's elements, one component per id ----------------
                // The layout document picks which of them a group draws and in
                // which order; each keeps the bindings it had when it lived in
                // the bar's markup.

                Component {
                    id: launcherWidget

                    LauncherButton {
                        id: launcherButton

                        strings: shell.strings
                        opened: (shell.popupOpen && shell.popupKind === "launcher" && shell.popupScreen === monitor.modelData)
                                || (shell.launcherOpen && shell.launcherScreen === monitor.modelData)
                        onClicked: {
                            // The popout is already here: the click is for it.
                            if (shell.popupOpen && shell.popupKind === "launcher" && shell.popupScreen === monitor.modelData)
                                shell.togglePopup("launcher", launcherButton, monitor.modelData)
                            else
                                shell.toggleLauncher(monitor.modelData, "")
                        }
                        onMenuRequested: {
                            shell.launcherOpen = false
                            shell.launcherMode = ""
                            shell.togglePopup("launcher", launcherButton, monitor.modelData)
                        }
                        onHoveredChanged: {
                            tooltips.hover(launcherButton, hovered)
                            if (hovered)
                                shell.hoverPopup("launcher", launcherButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: notificationsWidget

                    NotificationButton {
                        id: notificationButton

                        strings: shell.strings
                        opened: shell.notificationsOpen && shell.notificationsScreen === monitor.modelData
                        muted: shell.dnd
                        muteUntil: shell.prefs.notificationMuteUntil || "0"
                        count: toasts.history.count
                        onClicked: shell.toggleNotifications(monitor.modelData)
                        onMutedRequested: shell.toggleNotificationMute()
                        onHoveredChanged: tooltips.hover(notificationButton, hovered)
                    }
                }

                Component {
                    id: mediaWidget

                    MediaButton {
                        id: mediaButton

                        visible: shell.mprisPlayer !== null
                        player: shell.mprisPlayer
                        strings: shell.strings
                        onClicked: shell.togglePopup("media", mediaButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(mediaButton, hovered)
                            if (hovered)
                                shell.hoverPopup("media", mediaButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: clockWidget

                    ClockButton {
                        id: clockButton

                        vertical: bar.vertical
                        language: shell.prefs.language || "en"
                        strings: shell.strings
                        opened: shell.popupOpen && shell.popupKind === "dashboard" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("dashboard", clockButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(clockButton, hovered)
                            if (hovered)
                                shell.hoverPopup("dashboard", clockButton, monitor.modelData)
                        }
                    }
                }

                // A screenshot button the layout keeps out of the bar until it
                // is asked for (the editor's capture element).
                Component {
                    id: captureWidget

                    VitrailButton {
                        id: captureButton

                        variant: "plain"
                        icon: "screenshot_monitor"
                        property string tooltip: shell.t("bar.widget.capture")
                        property string tooltipDetail: shell.t("bar.widget.capture.help")
                        onClicked: shell.captureShot("region")
                        onHoveredChanged: tooltips.hover(captureButton, hovered)
                    }
                }

                // A recording in progress: its chip stops it.
                Component {
                    id: recordingWidget

                    VitrailButton {
                        id: recordingButton

                        visible: shell.recording
                        variant: "plain"
                        tone: "error"
                        icon: "stop_circle"
                        property string tooltip: shell.t("bar.widget.recording")
                        onClicked: shell.toggleRecording()
                        onHoveredChanged: tooltips.hover(recordingButton, hovered)
                    }
                }

                Component {
                    id: trayWidget

                    TrayItems {
                        vertical: bar.vertical
                        barEdge: bar.layout.edge
                        style: shell.prefs.trayStyle || "inline"
                        openKind: shell.popupOpen && shell.popupScreen === monitor.modelData ? shell.popupKind : ""
                        strings: shell.strings
                        onMenuRequested: function (kind, item) { shell.togglePopup(kind, item, monitor.modelData) }
                        onHovered: function (kind, item) { shell.hoverPopup(kind, item, monitor.modelData) }
                        onTipHovered: function (item, on) { tooltips.hover(item, on) }
                    }
                }

                Component {
                    id: networkWidget

                    NetworkButton {
                        id: networkButton

                        strings: shell.strings
                        stats: shell.linkStats
                        opened: shell.popupOpen && shell.popupKind === "network" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("network", networkButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(networkButton, hovered)
                            if (hovered)
                                shell.hoverPopup("network", networkButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: bluetoothWidget

                    BluetoothButton {
                        id: bluetoothButton

                        strings: shell.strings
                        show: shell.prefBool("barBluetoothChip", true)
                        bluetooth: shell.bluetoothDevices
                        opened: shell.popupOpen && shell.popupKind === "bluetooth" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("bluetooth", bluetoothButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(bluetoothButton, hovered)
                            if (hovered)
                                shell.hoverPopup("bluetooth", bluetoothButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: vpnWidget

                    VpnButton {
                        id: vpnButton

                        strings: shell.strings
                        stats: shell.linkStats
                        opened: shell.popupOpen && shell.popupKind === "vpn" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("vpn", vpnButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(vpnButton, hovered)
                            if (hovered)
                                shell.hoverPopup("vpn", vpnButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: profileWidget

                    PowerProfileButton {
                        id: profileButton

                        strings: shell.strings
                        profile: shell.powerProfile
                        opened: shell.popupOpen && shell.popupKind === "powerprofile" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("powerprofile", profileButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(profileButton, hovered)
                            if (hovered)
                                shell.hoverPopup("powerprofile", profileButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: batteryWidget

                    BatteryButton {
                        id: batteryButton

                        strings: shell.strings
                        show: shell.prefBool("barBatteryChip", true)
                        opened: shell.popupOpen && shell.popupKind === "powerprofile" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("powerprofile", batteryButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(batteryButton, hovered)
                            if (hovered)
                                shell.hoverPopup("powerprofile", batteryButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: keyboardWidget

                    KeyboardButton {
                        id: keyboardButton

                        visible: shell.keyboardShown
                        strings: shell.strings
                        keyboards: shell.keyboards
                        opened: shell.popupOpen && shell.popupKind === "keyboard" && shell.popupScreen === monitor.modelData
                        onClicked: shell.togglePopup("keyboard", keyboardButton, monitor.modelData)
                        onRightClicked: shell.toggleKeyboardOsk()
                        onHoveredChanged: {
                            tooltips.hover(keyboardButton, hovered)
                            if (hovered)
                                shell.hoverPopup("keyboard", keyboardButton, monitor.modelData)
                        }
                    }
                }

                Component {
                    id: powerWidget

                    PowerButton {
                        id: powerButton

                        strings: shell.strings
                        opened: shell.popupOpen && shell.popupKind === "power" && shell.popupScreen === monitor.modelData
                        onClicked: shell.toggleSession(monitor.modelData)
                        onMenuRequested: shell.togglePopup("power", powerButton, monitor.modelData)
                        onHoveredChanged: {
                            tooltips.hover(powerButton, hovered)
                            if (hovered)
                                shell.hoverPopup("power", powerButton, monitor.modelData)
                        }
                    }
                }

                // Neighbouring connection buttons share one pill, exactly as
                // they did when the bar had a fixed chip.
                Component {
                    id: chipWidget

                    Rectangle {
                        id: chip

                        property var ids: []
                        implicitWidth: chipRow.implicitWidth
                        implicitHeight: chipRow.implicitHeight + 2
                        radius: height / 2
                        // A soft primary: opaque, so it does not smear over the glass.
                        color: VitrailTokens.solid("primary", 0.14)

                        GridLayout {
                            id: chipRow

                            anchors.centerIn: parent
                            flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                            rowSpacing: 0
                            columnSpacing: 0

                            Repeater {
                                model: chip.ids

                                delegate: BarEntry {
                                    required property string modelData

                                    vertical: bar.vertical
                                    sourceComponent: monitor.widgetComponent(modelData)
                                    onLoaded: monitor.register(modelData, item)
                                    Component.onDestruction: monitor.unregister(modelData)
                                }
                            }
                        }
                    }
                }

                // The popup's "still inside" test in this screen's
                // coordinates: the card, the tray app's menu beside it, and
                // the button that opened it, with the card's own margin of
                // grace (rounded corners and the gap between the surfaces).
                function popupContains(point) {
                    var rects = [Qt.rect(popupCard.x, popupCard.y, popupCard.width, popupCard.height)]
                    if (menuCard.shown)
                        rects.push(Qt.rect(menuCard.x, menuCard.y, menuCard.width, menuCard.height))
                    return Popup.insideAny(point, rects, popupCard.margin)
                }

                function anchorContains(point) {
                    return Popup.inside(point, shell.popupAnchor, popupCard.margin)
                }

                // The existing handlers are the ground truth for "on the
                // popup"; the layer's pointer position is only for the rect.
                readonly property bool popupHovered: cardHover.hovered || menuHover.hovered

                // The popup button of each kind on this monitor's bar. An
                // element the layout hides has none: the popup opens where it
                // last did.
                function anchorFor(kind) {
                    switch (kind) {
                    case "network": return monitor.loadedItem("network")
                    case "bluetooth": return monitor.loadedItem("bluetooth")
                    case "vpn": return monitor.loadedItem("vpn")
                    case "powerprofile": return monitor.loadedItem("profile")
                    case "power": return monitor.loadedItem("power")
                    case "keyboard": return monitor.loadedItem("keyboard")
                    case "dashboard": return monitor.loadedItem("clock")
                    case "launcher": return monitor.loadedItem("launcher")
                    // The cheatsheet has no button: it grows from the bar's centre.
                    case "binds": return monitor.loadedItem("clock")
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

                    open: monitor.modelData === (shell.toastScreen || shell.notificationScreen) && toasts.shown.count > 0
                          && !shell.notificationsOpen
                }

                // Until a wallpaper is chosen, whatever draws it today stays.
                // The audio visualiser shares this background layer.
                PanelWindow {
                    screen: monitor.modelData
                    visible: (shell.prefs.wallpaper || "") !== "" || shell.visualiserActive
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
                        source: shell.wallpaperFor(monitor.modelData.name)
                        revision: shell.paletteVersion
                        hole: bar.layout.hole
                        radius: bar.layout.radius
                    }

                    VitrailVisualiser {
                        id: visualiser

                        readonly property real stripWidth: shell.visualiserVariant === "panel"
                                                          ? VitrailTokens.visualiser.panel.width
                                                          : VitrailTokens.visualiser.width

                        visible: shell.visualiserActive
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: bar.layout.hole.bottom + VitrailTokens.gap("xl")
                        width: Math.min(parent.width * visualiser.stripWidth, VitrailTokens.visualiser.maxWidth)
                        height: shell.prefNumber("visualiserHeight", VitrailTokens.ranges.visualiserHeight.value)
                        variant: shell.visualiserVariant
                        values: shell.visualiserValues
                        tint: VitrailTokens.color("primary")
                        opacityLevel: VitrailTokens.opacity
                    }
                }

                // The desktop's widgets, each a small background window at its
                // point (bar.ini `desktopLayout`, bar → Editor → Desktop). They
                // leave with the bar and frame under a fullscreen window.
                DesktopLayer {
                    screen: monitor.modelData
                    monitor: monitor.modelData.name
                    layoutText: shell.prefs.desktopLayout || ""
                    hiddenFullscreen: monitor.hiddenFullscreen
                    strings: shell.strings
                    language: shell.prefs.language || "en"
                    weather: desktopData.weather
                    resources: desktopData.resources
                    timerEngine: focusTimers
                    mediaPlayer: shell.mprisPlayer
                    mediaPlayers: shell.mprisPlayers
                    mediaIndex: shell.mprisIndex
                    mediaStyle: shell.prefs.mediaStyle || "disc"
                    wifiOn: shell.wifiOn
                    bluetoothOn: shell.bluetoothOn
                    bluetoothPresent: shell.bluetoothPresent
                    micMuted: shell.micMuted
                    airplaneOn: shell.airplaneOn
                    dnd: shell.dnd
                    notes: shell.notes
                    onPlayerChosen: function (index) { shell.mprisIndex = index }
                    onQuickToggled: function (key) { shell.toggleQuick(key) }
                    onNoteAdded: function (note) { shell.notes = Notes.add(shell.notes, note) }
                    onNoteRemoved: function (index) { shell.notes = Notes.remove(shell.notes, index) }
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
                        // With a popup open the window takes the rest of the
                        // screen too, so a click outside the popup lands here
                        // (and closes it) instead of on the app below. The
                        // popup card is an Overlay above, and the bar's own
                        // buttons are above this click area.
                        item: shell.popupOpen || (bar.showBar && !bar.islands) ? bar : null

                        Region { item: bar.startMask }
                        Region { item: bar.centerMask }
                        Region { item: bar.endMask }
                        Region { item: bar.panelArea }
                    }

                    // A click anywhere but the popup card (or a bar button,
                    // which is above this area) closes the popup. This is the
                    // outside-close that does not wait for a focus change: the
                    // bar background, another monitor and the desktop all land
                    // here while a popup is open.
                    MouseArea {
                        anchors.fill: parent
                        enabled: shell.popupOpen
                        acceptedButtons: Qt.AllButtons
                        onClicked: shell.closePopup()
                    }

                    VitrailBar {
                        id: bar

                        // The global bar, with this output's edge and style
                        // (bar.ini `barMonitors`); the thickness stays global.
                        readonly property var barLayout: BarView.forMonitor(
                            shell.prefs.barMonitors, monitor.modelData.name,
                            { edge: shell.prefs.barEdge || "left", style: shell.prefs.barStyle || "" })
                        // What this monitor draws, in which order (bar.ini
                        // `barLayout`, bar → Editor).
                        readonly property var startEntries: Layouts.entries(monitor.barDocument.order.start,
                                                                            monitor.barDocument.hidden)
                        readonly property var centerEntries: Layouts.entries(monitor.barDocument.order.center,
                                                                             monitor.barDocument.hidden)
                        readonly property var endEntries: Layouts.entries(monitor.barDocument.order.end,
                                                                          monitor.barDocument.hidden)

                        anchors.fill: parent
                        edge: bar.barLayout.edge
                        variant: bar.barLayout.style
                        frameVariant: shell.prefs.frameStyle || ""
                        density: monitor.barDocument.density
                        // A fullscreen window takes the bar with it (the
                        // editor's switch, on by default).
                        showBar: !monitor.hiddenFullscreen && (shell.prefs.barScreens === "all"
                                                               || monitor.modelData === shell.primaryScreen)
                        visible: !monitor.hiddenFullscreen
                        opacityLevel: shell.barOpacity
                        panelVariant: shell.panelKind
                        panelOpen: shell.panelOpen
                        panelPush: shell.panelPush
                        popup: Qt.rect(popupCard.x, popupCard.y, popupCard.width, popupCard.height)
                        popupLook: popupLiquid.shown && popupCard.docked ? popupLiquid.look : null
                        popupOrigin: shell.popupAnchor
                        popupLag: popupCard.lag
                        // Docked, the notification stack, the OSD and the notification panel are tabs of the frame too.
                        tabs: (stackHolder.docked && stackLiquid.shown && stackHolder.height > 0
                              ? [{ edge: stackHolder.place.edge, reveal: stackLiquid.look.reveal,
                                   swell: stackLiquid.look.swell,
                                   rect: Frame.liquidRect(Qt.rect(stackHolder.x, stackHolder.y, stackHolder.width, stackHolder.height),
                                                          stackHolder.place.edge, stackHolder.origin,
                                                          stackLiquid.look.spread, 0, 0) }]
                              : []).concat(osd.tabs).concat(notificationLayer.tabs)

                        // Where the pointer is while it is on the bar: over an
                        // app there is no event, and that is what makes it
                        // "outside" the popup. Over the button that opened the
                        // popup it still counts as inside.
                        HoverHandler {
                            id: barHover

                            function notePoint() {
                                shell.barPointerScreen = monitor.modelData
                                shell.barPointerAt = barHover.parent.mapToItem(null, barHover.point.position.x,
                                                                               barHover.point.position.y)
                            }

                            onPointChanged: if (hovered) notePoint()
                            onHoveredChanged: {
                                if (hovered) {
                                    notePoint()
                                } else if (shell.barPointerScreen === monitor.modelData) {
                                    shell.barPointerScreen = null
                                    if (shell.popupOpen)
                                        popupLeave.restart()
                                }
                            }
                        }

                        // The launcher, the notification bell, and whatever the
                        // layout document puts here. Each group draws its
                        // elements in the document's order; a run of connection
                        // buttons shares one pill.
                        start: Item {
                            implicitWidth: startGrid.implicitWidth
                            implicitHeight: startGrid.implicitHeight

                            GridLayout {
                                id: startGrid

                                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                                rowSpacing: bar.gap
                                columnSpacing: bar.gap

                                Repeater {
                                    model: bar.startEntries

                                    delegate: BarEntry {
                                        id: startEntry

                                        required property var modelData

                                        vertical: bar.vertical
                                        contentVisible: monitor.entryVisible(startEntry.modelData)
                                        sourceComponent: monitor.entryComponent(startEntry.modelData)
                                        onLoaded: {
                                            if (startEntry.modelData.cluster !== undefined)
                                                item.ids = startEntry.modelData.ids
                                            else
                                                monitor.register(startEntry.modelData.id, item)
                                        }
                                        Component.onDestruction: monitor.unregister(startEntry.modelData.id)
                                    }
                                }
                            }
                        }

                        center: Item {
                            implicitWidth: centerGrid.implicitWidth
                            implicitHeight: centerGrid.implicitHeight

                            GridLayout {
                                id: centerGrid

                                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                                rowSpacing: bar.gap
                                columnSpacing: bar.gap

                                Repeater {
                                    model: bar.centerEntries

                                    delegate: BarEntry {
                                        id: centerEntry

                                        required property var modelData

                                        vertical: bar.vertical
                                        contentVisible: monitor.entryVisible(centerEntry.modelData)
                                        sourceComponent: monitor.entryComponent(centerEntry.modelData)
                                        onLoaded: {
                                            if (centerEntry.modelData.cluster !== undefined)
                                                item.ids = centerEntry.modelData.ids
                                            else
                                                monitor.register(centerEntry.modelData.id, item)
                                        }
                                        Component.onDestruction: monitor.unregister(centerEntry.modelData.id)
                                    }
                                }
                            }
                        }

                        end: Item {
                            implicitWidth: endGrid.implicitWidth
                            implicitHeight: endGrid.implicitHeight

                            GridLayout {
                                id: endGrid

                                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                                rowSpacing: bar.gapOf("xs")
                                columnSpacing: bar.gapOf("xs")

                                Repeater {
                                    model: bar.endEntries

                                    delegate: BarEntry {
                                        id: endEntry

                                        required property var modelData

                                        Layout.alignment: Qt.AlignHCenter
                                        vertical: bar.vertical
                                        contentVisible: monitor.entryVisible(endEntry.modelData)
                                        sourceComponent: monitor.entryComponent(endEntry.modelData)
                                        onLoaded: {
                                            if (endEntry.modelData.cluster !== undefined)
                                                item.ids = endEntry.modelData.ids
                                            else
                                                monitor.register(endEntry.modelData.id, item)
                                        }
                                        Component.onDestruction: monitor.unregister(endEntry.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // Tooltips of the bar's elements: one host per monitor.
                TooltipLayer {
                    id: tooltips

                    screen: monitor.modelData
                    edge: bar.layout.edge
                    offset: bar.layout.face
                    opacityLevel: shell.barOpacity
                    popupOpen: shell.popupOpen || shell.launcherOpen || shell.sessionOpen
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
                    keysEnabled: shell.prefBool("osdKeys", true)
                    keyTime: shell.prefNumber("osdKeyTime", VitrailTokens.ranges.osdKey.value)
                    hotZone: shell.prefNumber("osdHotZone", VitrailTokens.ranges.osdHot.value)
                    sliderSize: shell.prefs.osdSize || VitrailTokens.osd.size
                }

                // Notifications: a full-height panel that opens from a hot
                // zone on its side, like the volume OSD. It never shows over a
                // fullscreen window; only the OSD may.
                NotificationLayer {
                    id: notificationLayer

                    screen: monitor.modelData
                    layout: bar.layout
                    docked: bar.style.docked
                    side: shell.notificationSide
                    // Every monitor keeps its hot zone; only the pinned one draws the panel.
                    active: !monitor.fullscreen
                    pinned: monitor.modelData === shell.notificationsScreen
                    open: shell.notificationsOpen
                    queue: toasts
                    strings: shell.strings
                    opacityLevel: shell.barOpacity
                    dnd: shell.dnd
                    notes: shell.notes
                    act: shell.notificationAction
                    snoozeEnabled: shell.snoozeEnabled
                    mutedApps: shell.prefs.notificationMuted || ""
                    stats: toasts.stats
                    mutedShown: shell.notificationsMutedShown
                    statsShown: shell.notificationsStatsShown
                    onMutedToggled: shell.toggleNotificationList("muted")
                    onStatsToggled: shell.toggleNotificationList("stats")
                    mediaPlayer: shell.mprisPlayer
                    wifiOn: shell.wifiOn
                    bluetoothOn: shell.bluetoothOn
                    bluetoothPresent: shell.bluetoothPresent
                    micMuted: shell.micMuted
                    airplaneOn: shell.airplaneOn
                    onQuickToggled: function (key) { shell.toggleQuick(key) }
                    recording: shell.recording
                    onShotRequested: function (mode) { shell.captureShot(mode) }
                    onRecordRequested: shell.toggleRecording()
                    mediaStyle: shell.prefs.mediaStyle || "disc"
                    mediaPlayers: shell.mprisPlayers
                    mediaIndex: shell.mprisIndex
                    // The panel's widget order, visibility and per-widget
                    // size/style (bar.ini `panelLayout`, bar → Editor).
                    layoutText: shell.prefs.panelLayout || ""
                    onOpenRequested: shell.openNotifications(notificationLayer.screen)
                    onCloseRequested: shell.notificationsOpen = false
                    onDndToggled: {
                        shell.dnd = !shell.dnd
                        shell.setPref("notificationDnd", shell.dnd ? "true" : "false")
                        // A manual answer wins over the bell's hour.
                        shell.setPref("notificationMuteUntil", "0")
                    }
                    onSessionRequested: function (key) { shell.runSession(key) }
                    onNoteAdded: function (note) {
                        shell.notes = Notes.add(shell.notes, note)
                        shell.setPref("quickNotes", shell.notes)
                    }
                    onNoteRemoved: function (index) {
                        shell.notes = Notes.remove(shell.notes, index)
                        shell.setPref("quickNotes", shell.notes)
                    }
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
                    // The launcher is typed into, so it takes the keyboard when it
                    // opens: exclusive for a beat (the only way to be focused
                    // without a click), then on demand. An exclusive layer keeps
                    // the pointer and the focus to itself, so no bar button could be
                    // hovered and no window clicked while it is open; on demand it
                    // keeps the keyboard until another window takes the focus.
                    // The on-screen keyboard is a separate floating window
                    // (KeyboardWindow) and never takes this layer's keyboard.
                    readonly property bool wantsKeyboard: popupLiquid.open
                    property bool grabbing: false
                    // The tray app under the pointer in the tray popup, and its icon.
                    property var trayTip: null
                    property Item trayCell: null
                    // The icon whose menu is open, which the menu card centres on.
                    property Item menuCell: null
                    onWantsKeyboardChanged: {
                        popupLayer.grabbing = popupLayer.wantsKeyboard
                        if (popupLayer.wantsKeyboard)
                            keyboardGrab.restart()
                    }
                    WlrLayershell.keyboardFocus: !popupLayer.wantsKeyboard ? WlrKeyboardFocus.None
                                                 : popupLayer.grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

                    // Where the pointer is while it is on the popup: the card
                    // and the tray app's menu (the layer's mask), children
                    // included. A handler above them sees every move.
                    HoverHandler {
                        id: popupHover

                        function notePoint() {
                            shell.popupPointerScreen = monitor.modelData
                            shell.popupPointerAt = popupHover.parent.mapToItem(null, popupHover.point.position.x,
                                                                               popupHover.point.position.y)
                        }

                        onPointChanged: if (hovered) notePoint()
                        onHoveredChanged: {
                            if (hovered) {
                                notePoint()
                            } else if (shell.popupPointerScreen === monitor.modelData) {
                                shell.popupPointerScreen = null
                                if (shell.popupOpen)
                                    popupLeave.restart()
                            }
                        }
                    }

                    // A popup left alone closes itself, unless the pointer is
                    // still reading it.
                    Timer {
                        id: popupIdle

                        interval: 10000
                        running: shell.popupOpen
                        onTriggered: {
                            if (shell.pointerInsidePopup())
                                popupIdle.restart()
                            else
                                shell.closePopup()
                        }
                    }

                    Timer {
                        id: keyboardGrab

                        interval: 150
                        onTriggered: popupLayer.grabbing = false
                    }

                    // Input only on the cards (the tray app's menu is one more):
                    // the bar buttons and the apps around them stay clickable
                    // while a popup is open.
                    mask: Region {
                        item: popupLiquid.shown ? popupCard : null

                        Region { item: menuCard.shown ? menuCard : null }
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

                    FocusScope {
                        id: popupCard

                        property bool entered: false
                        readonly property int margin: VitrailTokens.gap("md")
                        readonly property string barEdge: bar.layout.edge
                        // An app's menu always floats, like the OSD's device card.
                        readonly property bool floating: shell.popupKind.indexOf("tray:") === 0
                        readonly property bool docked: bar.style.docked && !popupCard.floating
                        readonly property var hole: bar.layout.hole
                        // Docked, the card is a tab of the frame, flush with
                        // its edge (past the islands of an islands bar);
                        // floating, an island a gap past the bar (past the
                        // frame, when the bar is docked).
                        readonly property real offset: popupCard.docked ? bar.layout.dock[popupCard.barEdge]
                            : (bar.style.docked ? bar.layout.dock[popupCard.barEdge] : bar.reserve[popupCard.barEdge]) + popupCard.margin

                        // Sized to the popout being shown; switching glides to the
                        // next size while the contents fade out, then in. It keeps
                        // its size while the popup closes.
                        readonly property real wantWidth: popouts.current ? popouts.current.implicitWidth + 2 * popupCard.margin : 0
                        readonly property real wantHeight: popouts.current ? popouts.current.implicitHeight + 2 * popupCard.margin : 0
                        property real keptWidth: 0
                        property real keptHeight: 0
                        onWantWidthChanged: if (popupCard.wantWidth > 0) popupCard.keptWidth = popupCard.wantWidth
                        onWantHeightChanged: if (popupCard.wantHeight > 0) popupCard.keptHeight = popupCard.wantHeight
                        // Where the size is heading. The targets below place the
                        // card from this, not from the animated width / height:
                        // placing it from those would make x / y chase a moving
                        // target and leave the card off the bar while it resizes.
                        readonly property real targetWidth: popupCard.wantWidth > 0 ? popupCard.wantWidth : popupCard.keptWidth
                        readonly property real targetHeight: popupCard.wantHeight > 0 ? popupCard.wantHeight : popupCard.keptHeight

                        // The island or bar a floating card leaves, for its neck.
                        readonly property var sourceTarget: {
                            // Docked, the frame has no neck to a floating card.
                            if (bar.style.docked)
                                return null
                            if (bar.islands)
                                return Frame.nearestRect(bar.islandRects, shell.popupAnchorX, shell.popupAnchorY)
                            return Qt.rect(bar.area.x, bar.area.y, bar.area.width, bar.area.height)
                        }
                        // The neck follows the card: switching to a button on
                        // another island glides the source like the card.
                        property real sourceX: popupCard.sourceTarget ? popupCard.sourceTarget.x : 0
                        property real sourceY: popupCard.sourceTarget ? popupCard.sourceTarget.y : 0
                        property real sourceWidth: popupCard.sourceTarget ? popupCard.sourceTarget.width : 0
                        property real sourceHeight: popupCard.sourceTarget ? popupCard.sourceTarget.height : 0
                        readonly property var source: popupCard.sourceTarget
                            ? Qt.rect(popupCard.sourceX, popupCard.sourceY, popupCard.sourceWidth, popupCard.sourceHeight) : null
                        // The anchor along the bar, followed with the card's own
                        // curve. `lag` (where the anchor is, minus where it was
                        // followed to) is how far the tab stretches ahead while the
                        // card glides to another button. It is measured on the
                        // anchor, not on the card's x / y: those also move when the
                        // card only grows (a bottom-flush card rises as it gets
                        // taller), which is no glide and must not stretch the tab.
                        readonly property real anchorAlong: bar.vertical ? shell.popupAnchorY : shell.popupAnchorX
                        property real glideAlong: popupCard.anchorAlong
                        readonly property real lag: popupCard.anchorAlong - popupCard.glideAlong

                        width: popupCard.targetWidth
                        height: popupCard.targetHeight
                        // Nothing draws outside the card while it resizes.
                        clip: true
                        // Opens from the button that invoked it: sideways for a
                        // vertical bar, above or below for a horizontal one.
                        x: popupCard.targetX
                        y: popupCard.targetY
                        readonly property real targetX: {
                            if (popupCard.barEdge === "left")
                                return popupCard.offset
                            if (popupCard.barEdge === "right")
                                return popupLayer.width - popupCard.offset - popupCard.targetWidth
                            return Frame.popupAlong(shell.popupAnchorX, popupCard.targetWidth, popupCard.hole.left,
                                                    popupLayer.width - popupCard.hole.right, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }
                        readonly property real targetY: {
                            if (popupCard.barEdge === "top")
                                return popupCard.offset
                            if (popupCard.barEdge === "bottom")
                                return popupLayer.height - popupCard.offset - popupCard.targetHeight
                            return Frame.popupAlong(shell.popupAnchorY, popupCard.targetHeight, popupCard.hole.top,
                                                    popupLayer.height - popupCard.hole.bottom, popupCard.docked,
                                                    popupCard.margin, bar.layout.radius)
                        }

                        // Glides only between buttons; opening snaps into place.
                        Behavior on x { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on y { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on width { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on height { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on glideAlong { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on sourceX { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on sourceY { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on sourceWidth { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }
                        Behavior on sourceHeight { enabled: !shell.popupOpening; NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutQuint } }

                        HoverHandler {
                            id: cardHover

                            onHoveredChanged: {
                                if (cardHover.hovered) {
                                    popupCard.entered = true
                                    popupLeave.stop()
                                } else if (popupCard.entered && !menuHover.hovered) {
                                    popupLeave.restart()
                                }
                            }
                        }

                        // Switching to another popout restarts the idle timer: the
                        // pointer left the old card, not the new one. The keyboard
                        // follows the card (see takeKeys).
                        Connections {
                            target: shell

                            function onPopupKindChanged() {
                                popupCard.entered = cardHover.hovered
                                popupLeave.stop()
                                popupCard.takeKeys()
                            }

                            function onPopupOpenChanged() {
                                popupCard.takeKeys()
                            }
                        }

                        // The card holds the keyboard while its popup is up, so
                        // Escape and Tab reach it without a click (the layer is
                        // OnDemand: it asks for the keyboard only when something
                        // inside has the focus). Releasing it on close lets the
                        // window underneath take it back.
                        function takeKeys() {
                            if (shell.popupOpen && popupLiquid.open)
                                popupCard.forceActiveFocus()
                            else
                                popupCard.focus = false
                        }

                        // Escape closes the popup; a tray app menu open beside it
                        // closes first and leaves the tray card up.
                        Keys.onEscapePressed: {
                            if (shell.trayMenuItem !== null)
                                shell.trayMenuItem = null
                            else
                                shell.closePopup()
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
                            // Switching: the next popout waits for the previous one
                            // to fade out; opening from closed has nothing to wait for.
                            readonly property int handover: shell.popupOpening ? 0 : VitrailTokens.duration("fast")

                            Popout {
                                name: "launcher"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: launcherComponent
                            }

                            Popout {
                                name: "network"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: networkComponent
                            }

                            Popout {
                                name: "bluetooth"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: bluetoothComponent
                            }

                            Popout {
                                name: "vpn"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: vpnComponent
                            }

                            Popout {
                                name: "media"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: mediaComponent
                            }

                            Popout {
                                name: "dashboard"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: dashboardComponent
                            }

                            Popout {
                                name: "binds"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: bindsComponent
                            }

                            Popout {
                                name: "tray"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: trayComponent
                            }

                            Popout {
                                name: "powerprofile"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: powerProfileComponent
                            }

                            Popout {
                                name: "keyboard"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: keyboardComponent
                            }

                            Popout {
                                name: "power"
                                current: popouts.name
                                handover: popouts.handover
                                sourceComponent: powerComponent
                            }

                            Repeater {
                                model: SystemTray.items

                                delegate: Popout {
                                    id: trayPopout

                                    required property var modelData

                                    name: "tray:" + trayPopout.modelData.id
                                    current: popouts.name
                                    handover: popouts.handover
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
                    }

                    // What the pointer reads over a tray icon: the app's own
                    // words, past the card on the side away from the bar. Not
                    // inside the card, which clips.
                    VitrailTooltip {
                        id: trayTip

                        readonly property var app: popupLayer.trayTip
                        readonly property var corner: popupLayer.trayCell ? popupLayer.trayCell.mapToItem(null, 0, 0) : Qt.point(0, 0)
                        readonly property var at: Frame.tooltipAt(popupCard.barEdge,
                            Qt.rect(trayTip.corner.x, trayTip.corner.y, popupLayer.trayCell ? popupLayer.trayCell.width : 0,
                                    popupLayer.trayCell ? popupLayer.trayCell.height : 0),
                            trayTip.width, trayTip.height,
                            popupCard.barEdge === "left" ? popupCard.x + popupCard.width
                            : popupCard.barEdge === "right" ? popupLayer.width - popupCard.x
                            : popupCard.barEdge === "top" ? popupCard.y + popupCard.height
                            : popupLayer.height - popupCard.y,
                            VitrailTokens.gap("sm"), popupLayer.width, popupLayer.height)

                        x: trayTip.at.x
                        y: trayTip.at.y
                        active: popupLayer.trayCell !== null && shell.popupOpen && shell.popupKind === "tray"
                                && shell.trayMenuItem === null
                        edge: popupCard.barEdge
                        opacityLevel: shell.barOpacity

                        // The text stays while the pill fades out.
                        Binding on text {
                            when: trayTip.app !== null
                            value: trayTip.app ? trayTip.app.tooltipTitle || trayTip.app.title || trayTip.app.id : ""
                            restoreMode: Binding.RestoreNone
                        }
                        Binding on detail {
                            when: trayTip.app !== null
                            value: trayTip.app ? trayTip.app.tooltipDescription : ""
                            restoreMode: Binding.RestoreNone
                        }
                    }

                    // A tray app's menu: a second card past the tray card, away
                    // from the bar, centred on the icon that opened it. It
                    // leaves the tray card open; Escape or picking an entry
                    // closes only the menu.
                    FocusScope {
                        id: menuCard

                        readonly property bool shown: shell.trayMenuItem !== null && shell.popupScreen === monitor.modelData
                        readonly property string name: menuCard.shown ? "tray:" + shell.trayMenuItem.id : ""
                        // The menu being shown, while the previous one fades out.
                        readonly property Item current: {
                            for (var i = 0; i < menus.children.length; i++) {
                                if (menus.children[i].shouldBeActive)
                                    return menus.children[i]
                            }
                            return null
                        }
                        readonly property var corner: popupLayer.menuCell ? popupLayer.menuCell.mapToItem(null, 0, 0) : Qt.point(0, 0)
                        readonly property var at: Frame.besideAt(popupCard.barEdge,
                            Qt.rect(popupCard.targetX, popupCard.targetY, popupCard.targetWidth, popupCard.targetHeight),
                            menuCard.width, menuCard.height,
                            Qt.point(menuCard.corner.x + (popupLayer.menuCell ? popupLayer.menuCell.width : 0) / 2,
                                     menuCard.corner.y + (popupLayer.menuCell ? popupLayer.menuCell.height : 0) / 2),
                            popupCard.hole, popupCard.margin, popupLayer.width, popupLayer.height)

                        visible: menuCard.shown
                        x: menuCard.at.x
                        y: menuCard.at.y
                        width: menuCard.current ? menuCard.current.implicitWidth + 2 * popupCard.margin : 0
                        height: menuCard.current ? menuCard.current.implicitHeight + 2 * popupCard.margin : 0
                        Keys.onEscapePressed: shell.trayMenuItem = null

                        VitrailSurface {
                            anchors.fill: parent
                            opacityLevel: shell.barOpacity
                        }

                        HoverHandler {
                            id: menuHover

                            // The pointer on the menu is still on the popup.
                            onHoveredChanged: {
                                if (menuHover.hovered)
                                    popupLeave.stop()
                                else if (popupCard.entered && !cardHover.hovered)
                                    popupLeave.restart()
                            }
                        }

                        Item {
                            id: menus

                            anchors.fill: parent
                            anchors.margins: popupCard.margin

                            Repeater {
                                model: SystemTray.items

                                delegate: Popout {
                                    id: menuPopout

                                    required property var modelData

                                    name: "tray:" + menuPopout.modelData.id
                                    current: menuCard.name
                                    handover: VitrailTokens.duration("fast")
                                    sourceComponent: Component {
                                        TrayMenu {
                                            handle: menuPopout.modelData.menu
                                            strings: shell.strings
                                            onDone: shell.trayMenuItem = null
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: launcherComponent

                    Launcher {
                        strings: shell.strings
                        prefs: shell.prefs
                        scanned: shell.launcherScanned
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
                        stats: shell.linkStats
                        tab: "internet"
                        bluetooth: shell.bluetoothDevices
                        onRefreshRequested: if (!bluetoothRead.running) bluetoothRead.running = true
                    }
                }

                Component {
                    id: bluetoothComponent

                    NetworkPanel {
                        strings: shell.strings
                        stats: shell.linkStats
                        tab: "bluetooth"
                        bluetooth: shell.bluetoothDevices
                        onRefreshRequested: if (!bluetoothRead.running) bluetoothRead.running = true
                    }
                }

                Component {
                    id: trayComponent

                    TrayPanel {
                        strings: shell.strings
                        onTipHovered: function (item, cell, on) {
                            if (on) {
                                popupLayer.trayTip = item
                                popupLayer.trayCell = cell
                            } else if (popupLayer.trayCell === cell) {
                                popupLayer.trayTip = null
                                popupLayer.trayCell = null
                            }
                        }
                        onActivated: function (item) { item.activate(); shell.closePopup() }
                        // The app's menu opens beside this card; the same icon again closes it.
                        onMenuRequested: function (item, entry) {
                            if (shell.trayMenuItem === item) {
                                shell.trayMenuItem = null
                                return
                            }
                            popupLayer.menuCell = entry
                            shell.trayMenuItem = item
                            popupIdle.restart()
                            menuCard.forceActiveFocus()
                        }
                    }
                }

                Component {
                    id: mediaComponent

                    MediaPanel {
                        player: shell.mprisPlayer
                        style: shell.prefs.mediaStyle || "disc"
                        players: shell.mprisPlayers
                        index: shell.mprisIndex
                        strings: shell.strings
                        onPlayerChosen: function (index) { shell.mprisIndex = index }
                    }
                }

                Component {
                    id: dashboardComponent

                    DashboardPopout {
                        open: shell.popupOpen && shell.popupKind === "dashboard"
                        strings: shell.strings
                        language: shell.prefs.language || "en"
                        mediaPlayer: shell.mprisPlayer
                        mediaPlayers: shell.mprisPlayers
                        mediaIndex: shell.mprisIndex
                        mediaStyle: shell.prefs.mediaStyle || "disc"
                        timerEngine: focusTimers
                        onPlayerChosen: function (index) { shell.mprisIndex = index }
                    }
                }

                Component {
                    id: bindsComponent

                    BindsPopout {
                        strings: shell.strings
                        onDismissed: shell.closePopup()
                    }
                }

                Component {
                    id: vpnComponent

                    VpnPanel {
                        strings: shell.strings
                        configDir: shell.configDir
                        stats: shell.linkStats
                        onProbeRequested: shell.requestVpnProbe()
                    }
                }

                Component {
                    id: powerProfileComponent

                    PowerProfilePanel {
                        strings: shell.strings
                        profile: shell.powerProfile
                        onProfileRequested: function (mode) {
                            shell.powerProfile = mode
                            powerWrite.run(Commands.powerSet(mode), "")
                        }
                    }
                }

                Component {
                    id: keyboardComponent

                    KeyboardPanel {
                        strings: shell.strings
                        keyboards: shell.keyboards
                        onLayoutRequested: function (layout) { shell.applyKeyboardLayout(layout) }
                    }
                }

                // The on-screen keyboard: a floating overlay at the bottom of
                // the focused screen. It is not focusable, so `wtype` types
                // into the application that already has the focus.
                KeyboardWindow {
                    id: keyboardWindow

                    screen: monitor.modelData
                    shown: shell.keyboardOskOpen && shell.keyboardOskScreen === monitor.modelData
                    strings: shell.strings
                    language: Keyboard.language(Keyboard.activeCode(shell.keyboards))
                    onTyped: function (text) { shell.typeText(text) }
                    onKey: function (name) { shell.typeKeyName(name) }
                    onDismissed: shell.closeKeyboardOsk()
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
                    WlrLayershell.keyboardFocus: launcherLayer.visible ? WlrKeyboardFocus.Exclusive
                                                                       : WlrKeyboardFocus.None

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

                    readonly property bool asked: shell.sessionPending !== null
                    readonly property bool shown: (shell.sessionOpen || sessionLayer.asked)
                                                  && shell.sessionScreen === monitor.modelData

                    screen: monitor.modelData
                    // Only while the menu or the question is up; idle, the
                    // window is unmapped so it can never swallow a click.
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
                    WlrLayershell.keyboardFocus: sessionLayer.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                    SessionMenu {
                        id: sessionMenu

                        anchors.fill: parent
                        open: sessionLayer.shown && shell.sessionOpen
                        strings: shell.strings
                        user: Quickshell.env("USER") || ""
                        now: shell.now
                        canHibernate: shell.canHibernate
                        onChosen: function (key) { shell.runSession(key) }
                        onDismissed: shell.sessionOpen = false
                    }

                    // The guard's alert and the countdown, over the menu.
                    SessionConfirm {
                        id: sessionConfirm

                        anchors.fill: parent
                        allowed: sessionLayer.shown
                        strings: shell.strings
                        action: shell.sessionPending ? shell.sessionPending.key : ""
                        phase: shell.sessionPending ? shell.sessionPending.phase : "countdown"
                        jobs: shell.sessionPending && shell.sessionPending.jobs ? shell.sessionPending.jobs : []
                        remaining: shell.sessionPending ? Session.remaining(shell.sessionPending.deadline || 0,
                                                                            shell.sessionNow) : 0
                        total: Session.SECONDS
                        onCancelled: shell.cancelSession()
                        onConfirmed: shell.confirmSession()
                    }
                }

                // Incoming notifications, on the focused monitor (see
                // notificationScreen), wherever the user put them. Only the
                // stack itself takes input.
                PanelWindow {
                    screen: monitor.modelData
                    // Stays up while the stack closes (or the screen changes).
                    visible: monitor.modelData === (shell.toastScreen || shell.notificationScreen) || stackLiquid.shown
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

                        readonly property string position: Notifications.stackPosition(
                            shell.prefs.notificationPosition, shell.prefs.barEdge || "left")
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
                            act: shell.notificationAction
                            snoozeEnabled: shell.snoozeEnabled
                            mutedApps: shell.prefs.notificationMuted || ""
                            atBottom: stackHolder.place.edge === "bottom"
                            onImplicitHeightChanged: if (stack.implicitHeight > 0) stackHolder.keptHeight = stack.implicitHeight
                        }
                    }
                }


                // The clipboard history: a card at the pointer, on the monitor
                // the shortcut was pressed on, with the keyboard while it is up.
                PanelWindow {
                    id: clipboardLayer

                    readonly property bool here: monitor.modelData === shell.clipboardScreen
                    readonly property var place: Clipboard.clamp(
                        shell.clipboardX - monitor.modelData.x, shell.clipboardY - monitor.modelData.y,
                        clipboardCard.implicitWidth, clipboardCard.implicitHeight,
                        monitor.modelData.width, monitor.modelData.height, VitrailTokens.gap("md"))

                    screen: monitor.modelData
                    visible: shell.clipboardOpen && clipboardLayer.here
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "vitrail-clipboard"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: clipboardLayer.visible ? WlrKeyboardFocus.Exclusive
                                                                       : WlrKeyboardFocus.None
                    // The whole screen takes the click that closes it.
                    mask: Region {}

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.clipboardOpen = false
                    }

                    ClipboardPanel {
                        id: clipboardCard

                        x: clipboardLayer.place.x
                        y: clipboardLayer.place.y
                        active: shell.clipboardOpen
                        opacityLevel: shell.barOpacity
                        entries: shell.clipboardEntries
                        thumbs: shell.clipboardThumbs
                        emojis: shell.clipboardEmojis
                        recent: shell.clipboardRecent
                        color: shell.clipboardColor
                        colorFormat: shell.clipboardFormat
                        startMode: shell.clipboardMode
                        strings: shell.strings
                        max: Number(shell.prefs.clipboardMax) || 100
                        onPicked: function (id, mode) { shell.pickClip(id, mode) }
                        onRemoveRequested: function (id) { shell.removeClip(id) }
                        onClearRequested: shell.clearClips()
                        onCloseRequested: shell.clipboardOpen = false
                        onThumbRequested: function (id) { shell.requestThumb(id) }
                        onEmojiPicked: function (emoji) { shell.pickEmoji(emoji) }
                        onColorCopied: function (text) { shell.copyText(text) }
                        onColorPickRequested: shell.pickColor()
                        onColorFormatPicked: function (format) { shell.clipboardFormat = format }
                        onModeSelected: function (mode) {
                            if (mode === "emoji")
                                shell.ensureEmojis()
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
