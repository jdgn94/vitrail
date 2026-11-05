import QtQuick
import "../widgets.js" as Registry

// One widget of the desktop, chosen by id from the shared registry
// (bar/widgets.js). The desktop document says where it goes, its size and its
// style (bar/layouts.js); this host resolves those to the same components the
// dashboard and the panel use.
Item {
    id: root

    property string widgetId: ""
    property string size: "md"
    property string style: ""
    property var strings: ({})

    // The clock and the calendar.
    property date now: new Date()
    property date month: new Date()
    property string language: "en"

    // The services.
    property var weather: ({})
    property var readings: ({})

    // The clock widgets' engine.
    property var timerEngine: null

    // The player.
    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0
    property string mediaStyle: "disc"

    // The quick toggles and the notes.
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool airplaneOn: false
    property bool dnd: false
    property string notes: ""

    signal playerChosen(int index)
    signal quickToggled(string key)
    signal noteAdded(string note)
    signal noteRemoved(int index)

    // The desktop document gives a point, a size and a style; the widget's
    // natural height comes from its content and its width from the registry
    // (bar/widgets.js), the same number the editor canvas uses.
    readonly property real preferredWidth: Registry.widthOf(root.widgetId, root.size)

    implicitWidth: Math.max(root.preferredWidth, loader.implicitWidth)
    implicitHeight: loader.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Loader {
        id: loader

        width: root.width
        height: root.height
        sourceComponent: root.widgetId === "clock" ? clockWidget
                       : root.widgetId === "calendar" ? calendarWidget
                       : root.widgetId === "weather" ? weatherWidget
                       : root.widgetId === "resources" ? resourcesWidget
                       : root.widgetId === "pomodoro" ? pomodoroWidget
                       : root.widgetId === "timer" ? timerWidget
                       : root.widgetId === "media" ? mediaWidget
                       : root.widgetId === "toggles" ? togglesWidget
                       : root.widgetId === "notes" ? notesWidget
                       : null
    }

    Component {
        id: clockWidget

        DashboardClock {
            width: loader.width
            height: loader.height
            now: root.now
            language: root.language
            size: root.size
            variant: root.style
        }
    }

    Component {
        id: calendarWidget

        DashboardCalendar {
            width: loader.width
            height: loader.height
            now: root.now
            shown: root.month
            language: root.language
            size: root.size
            variant: root.style
            todayText: root.t("clock.today")
            onPageRequested: function (step) {
                root.month = new Date(root.month.getFullYear(), root.month.getMonth() + step, 1)
            }
            onTodayRequested: root.month = new Date()
        }
    }

    Component {
        id: weatherWidget

        DashboardWeather {
            width: loader.width
            height: loader.height
            weather: root.weather
            strings: root.strings
            language: root.language
            size: root.size
            variant: root.style
        }
    }

    Component {
        id: resourcesWidget

        DashboardResources {
            width: loader.width
            height: loader.height
            readings: root.readings
            strings: root.strings
            size: root.size
            variant: root.style
        }
    }

    Component {
        id: pomodoroWidget

        DashboardFocus {
            width: loader.width
            height: loader.height
            engine: root.timerEngine
            kind: "pomodoro"
            strings: root.strings
            now: root.now.getTime()
            size: root.size
            variant: root.style
        }
    }

    Component {
        id: timerWidget

        DashboardFocus {
            width: loader.width
            height: loader.height
            engine: root.timerEngine
            kind: "timer"
            strings: root.strings
            now: root.now.getTime()
            size: root.size
            variant: root.style
        }
    }

    Component {
        id: mediaWidget

        PanelWidget {
            width: loader.width
            height: loader.height
            widgetId: "media"
            size: root.size
            style: root.style !== "" ? root.style : root.mediaStyle
            strings: root.strings
            mediaPlayer: root.mediaPlayer
            mediaPlayers: root.mediaPlayers
            mediaIndex: root.mediaIndex
            onPlayerChosen: function (index) { root.playerChosen(index) }
        }
    }

    Component {
        id: togglesWidget

        PanelWidget {
            width: loader.width
            height: loader.height
            widgetId: "toggles"
            size: root.size
            strings: root.strings
            wifiOn: root.wifiOn
            bluetoothOn: root.bluetoothOn
            bluetoothPresent: root.bluetoothPresent
            micMuted: root.micMuted
            airplaneOn: root.airplaneOn
            dnd: root.dnd
            onQuickToggled: function (key) { root.quickToggled(key) }
        }
    }

    Component {
        id: notesWidget

        PanelWidget {
            width: loader.width
            height: loader.height
            widgetId: "notes"
            size: root.size
            strings: root.strings
            notes: root.notes
            onNoteAdded: function (note) { root.noteAdded(note) }
            onNoteRemoved: function (index) { root.noteRemoved(index) }
        }
    }
}
