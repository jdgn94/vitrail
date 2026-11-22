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
    property alias uiIconFill: appearanceFile.uiIconFill
    property alias cursorThemeSplit: appearanceFile.cursorThemeSplit
    property alias launchAnimation: appearanceFile.launchAnimation
    property alias barEdge: barFile.barEdge
    property alias barScreens: barFile.barScreens
    property alias barStyle: barFile.barStyle
    property alias barMonitors: barFile.barMonitors
    property alias barLayout: barFile.barLayout
    property alias panelLayout: barFile.panelLayout
    property alias desktopLayout: barFile.desktopLayout
    // Whether every monitor shares one desktop document.
    property alias desktopSync: barFile.desktopSync
    // Whether a right click on the desktop opens its menu.
    property alias desktopMenu: barFile.desktopMenu
    // Whether the bar editor reorders rows by dragging.
    property alias barDragReorder: barFile.barDragReorder
    property alias barSize: barFile.barSize
    property alias barOpacity: barFile.barOpacity
    property alias barOpacityFollow: barFile.barOpacityFollow
    property alias frameStyle: barFile.frameStyle
    property alias frameSize: barFile.frameSize
    property alias panelSize: barFile.panelSize
    property alias notificationPosition: barFile.notificationPosition
    property alias notificationMax: barFile.notificationMax
    property alias notificationDnd: barFile.notificationDnd
    property alias notificationMuteUntil: barFile.notificationMuteUntil
    property alias notificationSnooze: barFile.notificationSnooze
    property alias notificationMuted: barFile.notificationMuted
    property alias notificationUrgentApps: barFile.notificationUrgentApps
    property alias notificationUrgentBypass: barFile.notificationUrgentBypass
    property alias notificationSnoozes: barFile.notificationSnoozes
    property alias dockEnabled: dockFile.dockEnabled
    property alias dockEdge: dockFile.dockEdge
    property alias dockAutohide: dockFile.dockAutohide
    property alias dockAttached: dockFile.dockAttached
    property alias dockMagnify: dockFile.dockMagnify
    property alias dockMagnifyRange: dockFile.dockMagnifyRange
    property alias dockMagnifyScale: dockFile.dockMagnifyScale
    property alias dockPinned: dockFile.dockPinned
    property alias dockWidgets: dockFile.dockWidgets
    property alias clipboardMax: barFile.clipboardMax
    property alias clipboardPaste: barFile.clipboardPaste
    property alias clipboardRich: barFile.clipboardRich
    property alias clipboardPreview: barFile.clipboardPreview
    property alias mediaStyle: barFile.mediaStyle
    property alias trayStyle: barFile.trayStyle
    property alias barBatteryChip: barFile.barBatteryChip
    property alias barBluetoothChip: barFile.barBluetoothChip
    property alias barActiveOnly: barFile.barActiveOnly
    property alias barKeyboard: barFile.barKeyboard
    property alias osdKeys: barFile.osdKeys
    property alias osdKeyTime: barFile.osdKeyTime
    property alias osdHotZone: barFile.osdHotZone
    property alias osdSize: barFile.osdSize
    property alias osdStep: barFile.osdStep
    property alias osdBrightnessStep: barFile.osdBrightnessStep
    property alias volumeStep: barFile.volumeStep
    property alias volumePercent: barFile.volumePercent
    property alias volumeHideSilent: barFile.volumeHideSilent
    property alias updatesInterval: barFile.updatesInterval
    property alias updatesSources: barFile.updatesSources
    property alias updatesAurHelper: barFile.updatesAurHelper
    property alias disksAutomount: barFile.disksAutomount
    property alias disksIgnore: barFile.disksIgnore
    property alias containersEngine: barFile.containersEngine
    property alias containersPinned: barFile.containersPinned
    property alias peripheralsHide: barFile.peripheralsHide
    property alias peripheralsLow: barFile.peripheralsLow
    property alias brightnessStep: barFile.brightnessStep
    property alias resourcesInterval: barFile.resourcesInterval
    property alias resourcesBar: barFile.resourcesBar
    property alias resourcesUnits: barFile.resourcesUnits
    property alias netusageBar: barFile.netusageBar
    property alias netusageUnits: barFile.netusageUnits
    property alias healthDiskThreshold: barFile.healthDiskThreshold
    property alias healthChecks: barFile.healthChecks
    property alias privacyWatch: barFile.privacyWatch
    property alias privacyDotColor: barFile.privacyDotColor
    property alias marketSymbols: barFile.marketSymbols
    property alias marketCurrency: barFile.marketCurrency
    property alias marketInterval: barFile.marketInterval
    property alias downloadsRecent: barFile.downloadsRecent
    property alias dndDefaultMinutes: barFile.dndDefaultMinutes
    property alias caffeineMinutes: barFile.caffeineMinutes
    property alias nightLightEnabled: barFile.nightLightEnabled
    property alias nightLightTemperature: barFile.nightLightTemperature
    property alias nightLightSchedule: barFile.nightLightSchedule
    property alias pomodoroWork: barFile.pomodoroWork
    property alias pomodoroRest: barFile.pomodoroRest
    property alias pomodoroCycles: barFile.pomodoroCycles
    property alias timerMinutes: barFile.timerMinutes
    property alias notesPopupMax: barFile.notesPopupMax
    property alias soundOutputApps: soundFile.soundOutputApps
    property alias soundInputApps: soundFile.soundInputApps
    property alias soundFocusApps: soundFile.soundFocusApps
    property alias soundStep: soundFile.soundStep
    property alias colorScheme: colorsFile.colorScheme
    property alias colorContrast: colorsFile.colorContrast
    property alias fontSystem: fontsFile.fontSystem
    property alias fontConsole: fontsFile.fontConsole
    property alias uiIcons: fontsFile.uiIcons
    property alias iconTheme: fontsFile.iconTheme
    property alias iconAdaptive: fontsFile.iconAdaptive
    property alias iconFill: fontsFile.iconFill
    property alias iconImport: fontsFile.iconImport
    property alias iconRemove: fontsFile.iconRemove
    property alias cursorTheme: fontsFile.cursorTheme
    property alias cursorThemeLight: fontsFile.cursorThemeLight
    property alias cursorThemeDark: fontsFile.cursorThemeDark
    property alias cursorImport: fontsFile.cursorImport
    property alias cursorRemove: fontsFile.cursorRemove
    property alias cursorAdaptive: fontsFile.cursorAdaptive
    property alias cursorMonochrome: fontsFile.cursorMonochrome
    property alias cursorSize: fontsFile.cursorSize
    property alias cursorSpinner: fontsFile.cursorSpinner
    property alias wallpaper: wallpaperFile.wallpaper
    property alias wallpaperMode: wallpaperFile.wallpaperMode
    property alias wallpaperDir: wallpaperFile.wallpaperDir
    property alias wallpaperType: wallpaperFile.wallpaperType
    property alias wallpaperSelection: wallpaperFile.wallpaperSelection
    property alias wallpaperInterval: wallpaperFile.wallpaperInterval
    property alias wallpaperOrder: wallpaperFile.wallpaperOrder
    property alias wallpaperImport: wallpaperFile.wallpaperImport
    property alias wallpaperRemove: wallpaperFile.wallpaperRemove
    property alias wallpaperEffect: wallpaperFile.wallpaperEffect
    property alias wallpaperEffectDetail: wallpaperFile.wallpaperEffectDetail
    property alias wallpaperPauseFullscreen: wallpaperFile.wallpaperPauseFullscreen
    property alias wallpaperTransition: wallpaperFile.wallpaperTransition
    property alias wallpaperTransitionTime: wallpaperFile.wallpaperTransitionTime
    property alias wallpaperMonitors: wallpaperFile.wallpaperMonitors
    property alias systemColor: wallpaperFile.systemColor
    property alias visualiserEnabled: backgroundFile.visualiserEnabled
    property alias visualiserVariant: backgroundFile.visualiserVariant
    property alias visualiserHeight: backgroundFile.visualiserHeight
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
    property alias captureDir: captureFile.captureDir
    property alias captureRecordDir: captureFile.captureRecordDir
    property alias captureRecordAudio: captureFile.captureRecordAudio
    property alias captureRecordRegion: captureFile.captureRecordRegion
    property alias captureAnimation: captureFile.captureAnimation
    property alias editorTool: captureFile.editorTool
    property alias editorRemember: captureFile.editorRemember
    property alias editorOptions: captureFile.editorOptions
    property alias captureAi: captureFile.captureAi
    property alias ocrLanguages: captureFile.ocrLanguages
    property alias captureDetect: captureFile.captureDetect
    property alias capturePaletteSize: captureFile.capturePaletteSize
    property alias translateTarget: captureFile.translateTarget
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
    property alias networkMetrics: connectionFile.networkMetrics
    property alias weatherLocation: weatherFile.weatherLocation
    property alias weatherUnits: weatherFile.weatherUnits
    property alias weatherCities: weatherFile.weatherCities
    property alias weatherInterval: weatherFile.weatherInterval
    property alias selftest: miscFile.selftest
    property alias quickNotes: miscFile.quickNotes
    property alias clipboardColors: miscFile.clipboardColors
    property alias pomodoroState: miscFile.pomodoroState
    property alias timerState: miscFile.timerState

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
        property string uiIconFill: "outlined"
        property bool cursorThemeSplit: false
        // A drop grows from the dock icon / launcher row while an app starts.
        property bool launchAnimation: true
    }

    property Settings barSettings: Settings {
        id: barFile

        fileName: root.directory + "/bar.ini"
        category: "bar"

        property string barEdge: "left"
        property string barScreens: "primary"
        property string barStyle: ""
        // One JSON object keyed by output name ("DP-1"): {"edge","style"}.
        // An output without an entry follows the global edge and style.
        property string barMonitors: "{}"
        // The bar's elements: one JSON document with the order of each group,
        // the hidden elements, the density and whether a fullscreen window
        // hides the bar (bar/layouts.js). Empty is today's bar.
        property string barLayout: "{}"
        // The notification panel's widgets: their order, visibility and the
        // size/style of each one (bar/layouts.js, bar/widgets.js). Empty is
        // today's panel.
        property string panelLayout: "{}"
        // The desktop widgets: per monitor, each one's point (0..1), size and
        // style (bar/layouts.js, bar/widgets.js). Empty is no widgets.
        property string desktopLayout: "{}"
        // Whether every monitor shares the one desktop document (on) or each
        // output keeps its own list (off).
        property bool desktopSync: true
        // The desktop's right-click menu: the way into the in-place editor.
        property bool desktopMenu: true
        // The Bar tab reorders its rows by dragging (the group selectors and
        // arrows stay as the keyboard alternative).
        property bool barDragReorder: true
        property int barSize: VitrailTokens.ranges.bar.value
        property real barOpacity: VitrailTokens.ranges.opacity.value
        property bool barOpacityFollow: true
        property string frameStyle: ""
        property int frameSize: VitrailTokens.ranges.frame.value
        property int panelSize: VitrailTokens.ranges.panel.value
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
        // Copies keep the style of their source (HTML beside the text).
        property bool clipboardRich: true
        // The hover card of the clipboard panel.
        property bool clipboardPreview: true
        // The player's look: "disc" or "cassette".
        property string mediaStyle: "disc"
        // The tray's look: "inline" folds the icons out, "popup" lists them.
        property string trayStyle: "inline"
        // The battery and Bluetooth chips: each still needs its hardware.
        property bool barBatteryChip: true
        property bool barBluetoothChip: true
        // The elements that show only while they have something to say: a JSON
        // array of ids (bar/elements.js). Updates, disks, containers, the
        // peripheral batteries, health and privacy start here; an explicit
        // value (even "[]") wins over the built-in default.
        property string barActiveOnly: "[\"updates\",\"disks\",\"containers\",\"peripherals\",\"health\",\"privacy\",\"market\",\"downloads\",\"pomodoro\"]"
        // The keyboard layout chip, with its switcher and on-screen keyboard.
        property bool barKeyboard: true
        // The OSD: whether keys show it, how long a key's slider stays, how far
        // past the frame the hot zone reaches, its slider size and the steps.
        property bool osdKeys: true
        property int osdKeyTime: VitrailTokens.ranges.osdKey.value
        property int osdHotZone: VitrailTokens.ranges.osdHot.value
        property string osdSize: VitrailTokens.osd.size
        property int osdStep: VitrailTokens.ranges.osdStep.value
        property int osdBrightnessStep: VitrailTokens.ranges.osdBrightnessStep.value
        // The volume bar element: wheel step (%), the level as text, and
        // whether its popup hides paused streams.
        property int volumeStep: VitrailTokens.ranges.volumeStep.value
        property bool volumePercent: false
        property bool volumeHideSilent: false
        // The updates bar element: how often it checks (minutes), the sources
        // it checks ("official,aur,flatpak") and the AUR helper.
        property int updatesInterval: 60
        property string updatesSources: "official,aur,flatpak"
        property string updatesAurHelper: "auto"
        // The disks bar element: whether a newly plugged drive is mounted on
        // its own, and the labels or UUIDs it leaves alone (one JSON array).
        property bool disksAutomount: false
        property string disksIgnore: ""
        // The containers bar element: which engine to use ("auto" follows
        // docker, then podman) and the containers pinned first in its popup
        // (one JSON array of names).
        property string containersEngine: "auto"
        property string containersPinned: "[]"
        // The peripherals battery element: the kinds it leaves out ("mouse",
        // "keyboard", "headphones", "gamepad" as one JSON array) and the
        // percentage below which the icon warns.
        property string peripheralsHide: ""
        property int peripheralsLow: VitrailTokens.ranges.peripheralLow.value
        // The brightness bar element: the wheel step, the night light's switch,
        // its colour temperature (kelvin) and its schedule (mode plus fixed
        // hours, one JSON document).
        property int brightnessStep: VitrailTokens.ranges.brightnessStep.value
        // The resources bar element: seconds between two readings, what the bar
        // shows (both, cpu, ram or numbers) and the units (auto, binary, decimal).
        property int resourcesInterval: VitrailTokens.ranges.resourcesInterval.value
        property string resourcesBar: "both"
        property string resourcesUnits: "auto"
        // The network usage bar element: what the bar shows (both, down, up)
        // and the units of its rates and today's totals (auto, binary, decimal).
        property string netusageBar: "both"
        property string netusageUnits: "auto"
        // The system health bar element: the free space (percent) under which a
        // disk is a problem, and the checks that are on (one JSON array of
        // services, disk, hyprland, doctor).
        property int healthDiskThreshold: VitrailTokens.ranges.healthDisk.value
        property string healthChecks: "[\"services\",\"disk\",\"hyprland\",\"doctor\"]"
        // The privacy bar element: the kinds it watches (one JSON array of
        // microphone, camera, screen) and the dot's palette role.
        property string privacyWatch: "[\"microphone\",\"camera\",\"screen\"]"
        property string privacyDotColor: "error"
        // The market bar element: the CoinGecko ids on the bar and in the
        // popup (one JSON array, in order), the currency they are quoted in and
        // how often the module is polled (minutes, never below its cache).
        property string marketSymbols: "[\"bitcoin\"]"
        property string marketCurrency: "eur"
        property int marketInterval: VitrailTokens.ranges.marketInterval.value
        // The downloads element: how many finished downloads its popup keeps.
        property int downloadsRecent: VitrailTokens.ranges.downloadsRecent.value
        // The Do Not Disturb element: the duration its click starts and its
        // popup marks (30, 60, or 0 for until tomorrow at 08:00).
        property int dndDefaultMinutes: 60
        // The caffeine element: the duration its click starts and its popup
        // marks (minutes; 0 is until turned off).
        property int caffeineMinutes: 30
        property bool nightLightEnabled: false
        property int nightLightTemperature: 4000
        property string nightLightSchedule: '{"mode":"off","start":"20:00","end":"07:00"}'
        // The dashboard's clock widgets: the pomodoro's periods and rounds and
        // the timer's default length, in minutes.
        property int pomodoroWork: VitrailTokens.ranges.pomodoroWork.value
        property int pomodoroRest: VitrailTokens.ranges.pomodoroRest.value
        property int pomodoroCycles: VitrailTokens.ranges.pomodoroCycles.value
        property int timerMinutes: VitrailTokens.ranges.timerMinutes.value
        // The notes bar element: how many notes its popup lists.
        property int notesPopupMax: VitrailTokens.ranges.notesPopupMax.value
    }

    property Settings dockSettings: Settings {
        id: dockFile

        fileName: root.directory + "/dock.ini"
        category: "dock"

        // The dock of every monitor: shown or not, its edge, whether it hides
        // until the pointer reaches the edge, whether it is flush or floating,
        // and how its icons answer the pointer.
        property bool dockEnabled: false
        property string dockEdge: "bottom"
        property bool dockAutohide: false
        property bool dockAttached: true
        // planet (distance falloff), individual (only the hovered icon) or
        // none; `scale`/`lift` from the previous pair read as planet.
        property string dockMagnify: "planet"
        property int dockMagnifyRange: VitrailTokens.ranges.dockMagnifyRange.value
        property real dockMagnifyScale: VitrailTokens.ranges.dockMagnifyScale.value
        // The pinned apps as one JSON array, in their stored order:
        // [{ id, desktop, name, icon }].
        property string dockPinned: "[]"
        // Reserved for the dock's widgets (next phase): one JSON array.
        property string dockWidgets: "[]"
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
        // An effect over the picture ("none" = as it is); the derived file
        // drives both the palette and what the bar draws. Some effects follow
        // the light/dark mode.
        property string wallpaperEffect: "none"
        // How much of the style shows: the dot size and the ascii column count
        // (fine | normal | bold).
        property string wallpaperEffectDetail: "normal"
        // A fullscreen window (a game) stops the background: the video pauses,
        // the rotation waits and the visualiser ends.
        property bool wallpaperPauseFullscreen: true
        // How the picture arrives (none | random | ink | outline | fade) and
        // how long that animation runs, in milliseconds.
        property string wallpaperTransition: "random"
        property int wallpaperTransitionTime: VitrailTokens.ranges.transition.value
        // Per-output pictures: {"DP-1": {"wallpaper": "/path"}}. An empty one
        // follows the global picture; the effect is global and applies to
        // whichever picture the output shows.
        property string wallpaperMonitors: "{}"
        // Colour of the whole system ("" = from the wallpaper): palette seed
        // for every kind of wallpaper.
        property string systemColor: ""
    }

    property Settings backgroundSettings: Settings {
        id: backgroundFile

        fileName: root.directory + "/background.ini"
        category: "background"

        // The audio visualiser over the wallpaper: on/off, its look and height.
        property bool visualiserEnabled: false
        property string visualiserVariant: "bars"
        property int visualiserHeight: VitrailTokens.ranges.visualiserHeight.value
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

    property Settings colorsSettings: Settings {
        id: colorsFile

        fileName: root.directory + "/colors.ini"
        category: "colors"

        property string colorScheme: "tonal"
        property real colorContrast: 0
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
        property bool iconAdaptive: true
        property string iconFill: "solid"
        property string iconImport: ""
        property string iconRemove: ""
        property string cursorTheme: "Adwaita"
        property string cursorThemeLight: ""
        property string cursorThemeDark: ""
        property string cursorImport: ""
        property string cursorRemove: ""
        property bool cursorAdaptive: true
        property bool cursorMonochrome: false
        property int cursorSize: VitrailTokens.ranges.cursor.value
        property bool cursorSpinner: false
    }

    property Settings captureSettings: Settings {
        id: captureFile

        fileName: root.directory + "/capture.ini"
        category: "capture"

        property string captureDir: ""
        property string captureRecordDir: ""
        property bool captureRecordAudio: false
        property bool captureRecordRegion: false
        property bool captureAnimation: true
        // The screenshot editor: the tool it opens on, whether it remembers
        // the options last used, and those options (a JSON document).
        property string editorTool: "pencil"
        property bool editorRemember: true
        property string editorOptions: ""
        // "Ask AI" in the overlay: off, the button and the I key are gone.
        property bool captureAi: true
        // tesseract codes joined with "+"; empty: system language + English.
        property string ocrLanguages: ""
        // Search the selection for text and codes once it rests (local).
        property bool captureDetect: true
        // How many main colours the palette of an area shows.
        property int capturePaletteSize: VitrailTokens.ranges.capturePalette.value
        // Language code Translate writes in; empty: the system language.
        property string translateTarget: ""
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
        property string launcherModes: "web|calc|run|files|windows|actions|clipboard|wallpaper"
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
        // The bar's latency and traffic line: one echo every ten seconds and
        // the interface's counters.
        property bool networkMetrics: true
    }

    property Settings weatherSettings: Settings {
        id: weatherFile

        fileName: root.directory + "/weather.ini"
        category: "weather"

        // The city the weather is asked for; "" follows the IP's guess.
        property string weatherLocation: ""
        // "metric" (°C, km/h) or "imperial" (°F, mph).
        property string weatherUnits: "metric"
        // The cities the popup's switcher offers, one JSON array in order.
        // Empty follows the snapshot's own city (the module's default).
        property string weatherCities: "[]"
        // How often the bar asks for a snapshot, in whole minutes.
        property int weatherInterval: 15
    }

    property Settings miscSettings: Settings {
        id: miscFile

        fileName: root.directory + "/misc.ini"
        category: "misc"

        // The quick-notes widget: one note per line, newest first.
        property string quickNotes: ""
        // The colour tab's last ten colours, as a JSON array of hex values.
        property string clipboardColors: ""
        // The dashboard's sessions, as the JSON timers.js writes: the state
        // and the end time, so a running one continues after a reload.
        property string pomodoroState: ""
        property string timerState: ""
        // Written by the smoke test, never by the UI.
        property string selftest: ""
    }
}
