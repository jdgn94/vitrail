import QtQuick
import Qt.labs.settings 1.1
import "../kit"

// The settings window's preferences: one Settings per file, each file named
// after the area of the window that owns its keys. vitrail/prefs.map is the
// source of truth; tests/test_prefs_map.py keeps this file in line with it.
// Every property is aliased onto this object, so a page reads and writes
// `prefs.radius` without knowing which file stores it.
QtObject {
    id: root

    // The folder that holds the files (~/.config/vitrail).
    property string directory: "."

    property alias appearance: appearanceFile.appearance
    property alias surfaceStyle: appearanceFile.surfaceStyle
    property alias surfaceOpacity: appearanceFile.surfaceOpacity
    property alias radius: appearanceFile.radius
    property alias blurStrength: appearanceFile.blurStrength
    property alias spacing: appearanceFile.spacing
    property alias fontBase: appearanceFile.fontBase
    property alias barEdge: barFile.barEdge
    property alias barScreens: barFile.barScreens
    property alias barStyle: barFile.barStyle
    property alias barSize: barFile.barSize
    property alias barOpacity: barFile.barOpacity
    property alias barOpacityFollow: barFile.barOpacityFollow
    property alias frameStyle: barFile.frameStyle
    property alias frameSize: barFile.frameSize
    property alias panelSize: barFile.panelSize
    property alias panelPush: barFile.panelPush
    property alias notificationPosition: barFile.notificationPosition
    property alias notificationMax: barFile.notificationMax
    property alias notificationDnd: barFile.notificationDnd
    property alias notificationMuteUntil: barFile.notificationMuteUntil
    property alias notificationSnooze: barFile.notificationSnooze
    property alias notificationMuted: barFile.notificationMuted
    property alias notificationUrgentApps: barFile.notificationUrgentApps
    property alias notificationUrgentBypass: barFile.notificationUrgentBypass
    property alias notificationSnoozes: barFile.notificationSnoozes
    property alias clipboardMax: barFile.clipboardMax
    property alias clipboardPaste: barFile.clipboardPaste
    property alias mediaStyle: barFile.mediaStyle
    property alias trayStyle: barFile.trayStyle
    property alias osdKeys: barFile.osdKeys
    property alias osdKeyTime: barFile.osdKeyTime
    property alias osdHotZone: barFile.osdHotZone
    property alias osdSize: barFile.osdSize
    property alias osdStep: barFile.osdStep
    property alias osdBrightnessStep: barFile.osdBrightnessStep
    property alias soundOutputApps: soundFile.soundOutputApps
    property alias soundInputApps: soundFile.soundInputApps
    property alias soundFocusApps: soundFile.soundFocusApps
    property alias soundStep: soundFile.soundStep
    property alias fontSystem: fontsFile.fontSystem
    property alias fontConsole: fontsFile.fontConsole
    property alias uiIcons: fontsFile.uiIcons
    property alias iconTheme: fontsFile.iconTheme
    property alias cursorTheme: fontsFile.cursorTheme
    property alias cursorSize: fontsFile.cursorSize
    property alias wallpaper: wallpaperFile.wallpaper
    property alias wallpaperMode: wallpaperFile.wallpaperMode
    property alias wallpaperDir: wallpaperFile.wallpaperDir
    property alias wallpaperType: wallpaperFile.wallpaperType
    property alias wallpaperSelection: wallpaperFile.wallpaperSelection
    property alias wallpaperInterval: wallpaperFile.wallpaperInterval
    property alias wallpaperOrder: wallpaperFile.wallpaperOrder
    property alias wallpaperImport: wallpaperFile.wallpaperImport
    property alias wallpaperRemove: wallpaperFile.wallpaperRemove
    property alias systemColor: wallpaperFile.systemColor
    property alias windowLayout: windowsFile.windowLayout
    property alias visibleColumns: windowsFile.visibleColumns
    property alias followFocus: windowsFile.followFocus
    property alias wrapFocus: windowsFile.wrapFocus
    property alias borderWidth: windowsFile.borderWidth
    property alias opacityFocused: windowsFile.opacityFocused
    property alias opacityUnfocused: windowsFile.opacityUnfocused
    property alias monitorOverrides: monitorsFile.monitorOverrides
    property alias keyboardLayouts: inputFile.keyboardLayouts
    property alias keyboardSwitch: inputFile.keyboardSwitch
    property alias numlockOnStart: inputFile.numlockOnStart
    property alias focusFollowsMouse: inputFile.focusFollowsMouse
    property alias terminalScheme: terminalFile.terminalScheme
    property alias terminalPadding: terminalFile.terminalPadding
    property alias fontSize: terminalFile.fontSize
    property alias tabStyle: terminalFile.tabStyle
    property alias tabIcons: terminalFile.tabIcons
    property alias tabNumbers: terminalFile.tabNumbers
    property alias launcherEngine: launcherFile.launcherEngine
    property alias launcherBangs: launcherFile.launcherBangs
    property alias launcherModes: launcherFile.launcherModes
    property alias launcherView: launcherFile.launcherView
    property alias launcherClear: launcherFile.launcherClear
    property alias language: languageFile.language
    property alias languageSystem: languageFile.languageSystem
    property alias timezone: datetimeFile.timezone
    property alias ntp: datetimeFile.ntp
    property alias connectionRequest: connectionFile.connectionRequest
    property alias connectionSeq: connectionFile.connectionSeq
    property alias selftest: miscFile.selftest
    property alias quickNotes: miscFile.quickNotes
    property alias clipboardColors: miscFile.clipboardColors

    property Settings appearanceSettings: Settings {
        id: appearanceFile

        fileName: root.directory + "/appearance.ini"
        category: "appearance"

        property string appearance: "auto"
        property string surfaceStyle: "glass"
        property real surfaceOpacity: 0.9
        property real radius: 14
        property int blurStrength: 6
        property int spacing: 12
        property int fontBase: 13
    }

    property Settings barSettings: Settings {
        id: barFile

        fileName: root.directory + "/bar.ini"
        category: "bar"

        property string barEdge: "left"
        property string barScreens: "primary"
        property string barStyle: ""
        property int barSize: VitrailTokens.ranges.bar.value
        property real barOpacity: VitrailTokens.ranges.opacity.value
        property bool barOpacityFollow: true
        property string frameStyle: ""
        property int frameSize: VitrailTokens.ranges.frame.value
        property int panelSize: VitrailTokens.ranges.panel.value
        property bool panelPush: false
        property string notificationPosition: "top-right"
        property int notificationMax: VitrailTokens.ranges.notifications.value
        property bool notificationDnd: false
        // When the bell's one-hour silence ends (ms; "0" when none).
        property string notificationMuteUntil: "0"
        // The cards: snooze them, the apps that are muted, and the apps whose
        // notifications count as urgent (they bypass Do Not Disturb when the
        // bypass is on).
        property bool notificationSnooze: true
        property string notificationMuted: ""
        property string notificationUrgentApps: ""
        property bool notificationUrgentBypass: true
        // What was snoozed and when it comes back, as a JSON array.
        property string notificationSnoozes: ""
        // What the clipboard store keeps, and whether picking an entry also
        // pastes it into the focused window.
        property int clipboardMax: 100
        property bool clipboardPaste: false
        // The player's look: "disc" or "cassette".
        property string mediaStyle: "disc"
        // The tray's look: "inline" folds the icons out, "popup" lists them.
        property string trayStyle: "inline"
        // The OSD: whether keys show it, how long a key's slider stays, how far
        // past the frame the hot zone reaches, its slider size and the steps.
        property bool osdKeys: true
        property int osdKeyTime: VitrailTokens.ranges.osdKey.value
        property int osdHotZone: VitrailTokens.ranges.osdHot.value
        property string osdSize: VitrailTokens.osd.size
        property int osdStep: VitrailTokens.ranges.osdStep.value
        property int osdBrightnessStep: VitrailTokens.ranges.osdBrightnessStep.value
    }

    property Settings wallpaperSettings: Settings {
        id: wallpaperFile

        fileName: root.directory + "/wallpaper.ini"
        category: "wallpaper"

        property string wallpaper: ""
        property string wallpaperMode: ""
        property string wallpaperDir: ""
        // One kind at a time; several of it rotate every wallpaperInterval min.
        property string wallpaperType: ""
        property string wallpaperSelection: ""
        property int wallpaperInterval: 30
        property string wallpaperOrder: "sequential"
        // Requests for `vitrail wallpaper sync`: "<nonce>|path|path…".
        property string wallpaperImport: ""
        property string wallpaperRemove: ""
        // Colour of the whole system ("" = from the wallpaper): palette seed
        // for every kind of wallpaper, and the colour adaptive SVGs take.
        property string systemColor: ""
    }

    property Settings windowsSettings: Settings {
        id: windowsFile

        fileName: root.directory + "/windows.ini"
        category: "windows"

        property string windowLayout: "dwindle"
        property int visibleColumns: 2
        property bool followFocus: true
        property bool wrapFocus: false
        property int borderWidth: 2
        property real opacityFocused: 0.97
        property real opacityUnfocused: 0.88
    }

    property Settings monitorsSettings: Settings {
        id: monitorsFile

        fileName: root.directory + "/monitors.ini"
        category: "monitors"

        // One JSON object keyed by Hyprland output name ("DP-1"); an output
        // without an entry follows the compositor's defaults.
        property string monitorOverrides: "{}"
    }

    property Settings inputSettings: Settings {
        id: inputFile
        fileName: root.directory + "/input.ini"
        category: "input"

        property string keyboardLayouts: "us:"
        property string keyboardSwitch: "grp:alt_shift_toggle"
        property bool numlockOnStart: true
        property bool focusFollowsMouse: true
    }

    property Settings terminalSettings: Settings {
        id: terminalFile

        fileName: root.directory + "/terminal.ini"
        category: "terminal"

        property string terminalScheme: "system"
        property int terminalPadding: 6
        property int fontSize: 13
        property string tabStyle: "capsule"
        property bool tabIcons: true
        property bool tabNumbers: false
    }

    property Settings soundSettings: Settings {
        id: soundFile

        fileName: root.directory + "/sound.ini"
        category: "sound"

        // The apps of the volume and microphone cards.
        property bool soundOutputApps: true
        property bool soundInputApps: true
        property bool soundFocusApps: true
        property int soundStep: VitrailTokens.ranges.soundStep.value
    }

    property Settings fontsSettings: Settings {
        id: fontsFile

        fileName: root.directory + "/fonts.ini"
        category: "fonts"

        // One system font for the whole session, a console font of its own,
        // the shell's icon family, the apps' icon pack and the pointer.
        property string fontSystem: "Roboto"
        property string fontConsole: "JetBrainsMono Nerd Font"
        property string uiIcons: "rounded"
        property string iconTheme: "Adwaita"
        property string cursorTheme: "Adwaita"
        property int cursorSize: VitrailTokens.ranges.cursor.value
    }

    property Settings launcherSettings: Settings {
        id: launcherFile

        fileName: root.directory + "/launcher.ini"
        category: "launcher"

        // The launcher: web engine, user bangs ("key*name*url|…"), enabled
        // modes ("web|calc|…"), the browse view, and a request (a timestamp)
        // for the bar to clear what it remembers.
        property string launcherEngine: "duckduckgo"
        property string launcherBangs: ""
        property string launcherModes: "web|calc|run|files|windows|actions|clipboard"
        property string launcherView: "grid"
        property string launcherClear: ""
    }

    property Settings languageSettings: Settings {
        id: languageFile

        fileName: root.directory + "/language.ini"
        category: "language"

        property string language: "en"
        // Whether the language also becomes the system's (after the next login).
        property bool languageSystem: true
    }

    property Settings datetimeSettings: Settings {
        id: datetimeFile

        fileName: root.directory + "/datetime.ini"
        category: "datetime"

        // "" leaves the system's zone / clock sync as they are.
        property string timezone: ""
        property string ntp: ""
    }

    property Settings connectionSettings: Settings {
        id: connectionFile

        fileName: root.directory + "/connection.ini"
        category: "connection"

        // What the Connection page asks `vitrail.network apply` to do, and a
        // counter that grows with every ask so the same one can be repeated.
        property string connectionRequest: ""
        property int connectionSeq: 0
    }

    property Settings miscSettings: Settings {
        id: miscFile

        fileName: root.directory + "/misc.ini"
        category: "misc"

        // The quick-notes widget: one note per line, newest first.
        property string quickNotes: ""
        // The colour tab's last ten colours, as a JSON array of hex values.
        property string clipboardColors: ""
        // Written by the smoke test, never by the UI.
        property string selftest: ""
    }
}
