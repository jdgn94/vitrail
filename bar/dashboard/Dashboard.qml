import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "dashboard.js" as Dash
import "timers.js" as Timers

// The dashboard popup: the clock and date, then the month with today marked,
// the weather, the machine's performance, the focus widgets and now playing,
// in five tabs. Only
// the content lives here: the caller owns the data (see DashboardPopout, which
// runs the services while the popup is open), so the panel renders, and is
// tested, without a process.
Item {
    id: root

    property var strings: ({})
    property string language: "en"
    // The state of vitrail/weather.py and vitrail/resources.py; {} is empty.
    property var weather: ({})
    property var resources: ({})
    property string currentTab: "calendar"
    // The header's time, and the month the calendar shows (its paging).
    property date now: new Date()
    property date shown: new Date()
    // Now playing, and the panel that draws it (the caller supplies it, so
    // this file needs no MPRIS import).
    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0
    property string mediaStyle: "disc"
    property Component mediaPanel: null
    // The clock widgets' engine, kept by the shell so a running session lives
    // on when the popup closes (TimerEngine.qml).
    property var timerEngine: null

    signal playerChosen(int index)

    readonly property var tabs: [
        { key: "calendar", label: root.t("dashboard.tab.calendar"), icon: "calendar_month" },
        { key: "weather", label: root.t("dashboard.tab.weather"), icon: "partly_cloudy_day" },
        { key: "performance", label: root.t("dashboard.tab.performance"), icon: "monitoring" },
        { key: "focus", label: root.t("dashboard.tab.focus"), icon: "timer" },
        { key: "media", label: root.t("dashboard.tab.media"), icon: "music_note" }
    ]
    readonly property bool hasWeather: !!(root.weather && root.weather.current)
    readonly property bool hasResources: !!(root.resources && root.resources.memory)
    readonly property bool hasMedia: (root.mediaPlayer !== null && root.mediaPlayer !== undefined)
                                     || root.mediaPlayers.length > 0
    readonly property var forecast: {
        var days = root.hasWeather ? root.weather.daily : null
        if (!days || days.length === undefined)
            return []
        var shown = []
        for (var i = 0; i < Math.min(4, days.length); i++)
            shown.push(days[i])
        return shown
    }
    // One row per reading; a missing value reads as absent, never as zero.
    readonly property var metrics: {
        var data = root.resources || ({})
        return [
            { key: "cpu", icon: "speed", label: root.t("dashboard.cpu"), value: Dash.percent(data.cpu) },
            { key: "memory", icon: "memory", label: root.t("dashboard.memory"), value: Dash.usage(data.memory) },
            { key: "temperature", icon: "thermostat", label: root.t("dashboard.temperature"),
              value: Dash.temperature(data.temperature, "°C") },
            { key: "disk", icon: "storage", label: root.t("dashboard.disk"), value: Dash.usage(data.disk) },
            { key: "network", icon: "swap_vert", label: root.t("dashboard.network"), value: Dash.network(data.network) }
        ]
    }

    implicitWidth: 440
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function showTab(key) {
        if (root.tabs.some(function (tab) { return tab.key === key }))
            root.currentTab = key
    }

    function monthTitle() {
        var text = root.shown.toLocaleDateString(Qt.locale(root.language), "MMMM yyyy")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function page(step) {
        root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + step, 1)
    }

    // Whether the calendar is already on the month of today.
    function showingThisMonth() {
        return root.shown.getMonth() === root.now.getMonth()
               && root.shown.getFullYear() === root.now.getFullYear()
    }

    function weekday(iso) {
        var date = new Date(String(iso || "") + "T12:00:00")
        if (isNaN(date.getTime()))
            return String(iso || "")
        return date.toLocaleDateString(Qt.locale(root.language), "ddd")
    }

    // The words for a WMO code in the user's language (weather.code.<n>); the
    // service's English falls back for a code the table does not name.
    function condition(code, fallback) {
        var text = root.strings["weather.code." + Number(code)]
        return text === undefined || text === "" ? (fallback || "") : text
    }

    // --- the clock widgets: the pomodoro and the free timer -------------------
    readonly property var pomodoro: root.timerEngine ? root.timerEngine.pomodoro : null
    readonly property var freeTimer: root.timerEngine ? root.timerEngine.timer : null

    function clockLeft(state) {
        if (!state)
            return 0
        return state.running ? Timers.remaining(state.end, root.now.getTime()) : state.left
    }

    function clockProgress(state) {
        return Timers.progress(state, root.now.getTime())
    }

    function pomodoroPhase(state) {
        if (!state)
            return ""
        if (state.done)
            return root.t("dashboard.focus.done")
        var phase = state.phase === "work" ? root.t("dashboard.focus.work")
                                           : root.t("dashboard.focus.rest")
        return phase + " · " + root.t("dashboard.focus.round") + " "
               + Timers.round(state) + "/" + state.cycles
    }

    function timerPhase(state) {
        if (!state)
            return ""
        if (state.done)
            return root.t("dashboard.focus.done")
        if (state.running)
            return root.t("dashboard.focus.timer")
        if (state.left > 0 && state.left < state.duration)
            return root.t("dashboard.focus.paused")
        return root.t("dashboard.focus.ready")
    }

    // The header time ticks every second; the calendar follows the day.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    objectName: "dashboardClock"
                    variant: "display"
                    font.features: ({ "tnum": 1 })
                    text: root.now.toLocaleTimeString(Qt.locale(root.language), "HH:mm")
                }

                VitrailText {
                    objectName: "dashboardClockDate"
                    Layout.fillWidth: true
                    variant: "content"
                    text: {
                        var day = root.now.toLocaleDateString(Qt.locale(root.language), "dddd d MMMM yyyy")
                        return day.charAt(0).toUpperCase() + day.slice(1)
                    }
                }
            }

            VitrailIcon {
                icon: "space_dashboard"
                size: "md"
                tone: "primary"
            }
        }

        VitrailTabs {
            id: tabBar

            Layout.fillWidth: true
            tabs: root.tabs
            current: root.currentTab
            onSelected: function (key) { root.showTab(key) }
        }

        StackLayout {
            id: pages

            Layout.fillWidth: true
            currentIndex: root.tabs.findIndex(function (tab) { return tab.key === root.currentTab })

            // --- calendar: the month, with today in the accent circle
            Item {
                objectName: "dashboardCalendar"

                implicitHeight: calendar.implicitHeight

                ColumnLayout {
                    id: calendar

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("md")

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "body"
                            font.weight: Font.DemiBold
                            text: root.monthTitle()
                        }

                        VitrailButton {
                            visible: !root.showingThisMonth()
                            variant: "text"
                            size: "sm"
                            text: root.t("clock.today")
                            onClicked: root.shown = new Date()
                        }

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            icon: "chevron_left"
                            onClicked: root.page(-1)
                        }

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            icon: "chevron_right"
                            onClicked: root.page(1)
                        }
                    }

                    DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: Qt.locale(root.language)

                        delegate: VitrailText {
                            required property string shortName

                            horizontalAlignment: Text.AlignHCenter
                            variant: "label"
                            text: shortName.charAt(0).toUpperCase() + shortName.slice(1, 2)
                        }
                    }

                    MonthGrid {
                        Layout.fillWidth: true
                        locale: Qt.locale(root.language)
                        month: root.shown.getMonth()
                        year: root.shown.getFullYear()

                        delegate: Item {
                            id: day

                            required property var model

                            readonly property bool today: day.model.today
                            readonly property bool inMonth: day.model.month === root.shown.getMonth()

                            implicitWidth: VitrailTokens.size("display") + VitrailTokens.gap("xs")
                            implicitHeight: implicitWidth

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height)
                                height: width
                                radius: width / 2
                                visible: day.today
                                color: VitrailTokens.color("primary")
                            }

                            VitrailText {
                                anchors.centerIn: parent
                                variant: "content"
                                font.features: ({ "tnum": 1 })
                                font.weight: day.today ? Font.DemiBold : Font.Normal
                                opacity: day.inMonth ? 1 : 0.35
                                color: day.today ? VitrailTokens.color("accentForeground")
                                                 : VitrailTokens.color("foreground")
                                text: day.model.day
                            }
                        }
                    }
                }
            }

            // --- weather: the place, now, then the next four days
            Item {
                objectName: "dashboardWeather"

                implicitHeight: root.hasWeather ? weatherColumn.implicitHeight : weatherEmpty.implicitHeight

                ColumnLayout {
                    id: weatherEmpty

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("sm")
                    visible: !root.hasWeather

                    Item { Layout.fillHeight: true }

                    VitrailIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "partly_cloudy_day"
                        size: "xl"
                        tone: "muted"
                    }

                    VitrailText {
                        objectName: "dashboardWeatherEmpty"
                        Layout.alignment: Qt.AlignHCenter
                        variant: "content"
                        text: root.t("dashboard.weather.empty")
                    }

                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    id: weatherColumn

                    objectName: "dashboardWeatherData"
                    anchors.fill: parent
                    spacing: VitrailTokens.gap("md")
                    visible: root.hasWeather

                    readonly property var current: root.hasWeather ? root.weather.current : ({})
                    readonly property var units: root.weather && root.weather.units ? root.weather.units : ({})

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            VitrailText {
                                objectName: "dashboardWeatherLocation"
                                Layout.fillWidth: true
                                variant: "label"
                                text: root.weather.location ? root.weather.location.name : ""
                            }

                            RowLayout {
                                spacing: VitrailTokens.gap("sm")

                                VitrailText {
                                    objectName: "dashboardWeatherTemperature"
                                    variant: "display"
                                    text: Dash.temperature(weatherColumn.current.temperature,
                                                           weatherColumn.units.temperature)
                                }

                                VitrailText {
                                    objectName: "dashboardWeatherCondition"
                                    Layout.alignment: Qt.AlignBottom
                                    variant: "content"
                                    text: root.condition(weatherColumn.current.code,
                                                         weatherColumn.current.condition)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("md")

                        VitrailText {
                            variant: "label"
                            text: root.t("dashboard.humidity")
                        }

                        VitrailText {
                            objectName: "dashboardWeatherHumidity"
                            variant: "body"
                            font.features: ({ "tnum": 1 })
                            text: weatherColumn.current.humidity !== undefined
                                  ? weatherColumn.current.humidity + " " + (weatherColumn.units.humidity || "")
                                  : "--"
                        }

                        Item { Layout.fillWidth: true }

                        VitrailText {
                            variant: "label"
                            text: root.t("dashboard.wind")
                        }

                        VitrailText {
                            objectName: "dashboardWeatherWind"
                            variant: "body"
                            font.features: ({ "tnum": 1 })
                            text: weatherColumn.current.wind !== undefined
                                  ? weatherColumn.current.wind + " " + (weatherColumn.units.wind || "")
                                  : "--"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: VitrailTokens.solid("foreground", 0.12)
                    }

                    Repeater {
                        model: root.forecast

                        delegate: RowLayout {
                            id: forecastDay

                            required property var modelData
                            required property int index

                            objectName: "dashboardWeatherDay" + forecastDay.index
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                variant: "label"
                                text: root.weekday(forecastDay.modelData.date)
                            }

                            VitrailText {
                                objectName: "dashboardWeatherDayCondition" + forecastDay.index
                                Layout.fillWidth: true
                                variant: "content"
                                text: root.condition(forecastDay.modelData.code, forecastDay.modelData.condition)
                            }

                            VitrailText {
                                variant: "body"
                                font.features: ({ "tnum": 1 })
                                text: Dash.degrees(forecastDay.modelData.high) + " / "
                                      + Dash.degrees(forecastDay.modelData.low)
                            }
                        }
                    }
                }
            }

            // --- performance: CPU, memory, temperature, disk and network
            Item {
                objectName: "dashboardPerformance"

                implicitHeight: root.hasResources ? performanceColumn.implicitHeight
                                                  : performanceEmpty.implicitHeight

                ColumnLayout {
                    id: performanceEmpty

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("sm")
                    visible: !root.hasResources

                    Item { Layout.fillHeight: true }

                    VitrailIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "monitoring"
                        size: "xl"
                        tone: "muted"
                    }

                    VitrailText {
                        objectName: "dashboardPerformanceEmpty"
                        Layout.alignment: Qt.AlignHCenter
                        variant: "content"
                        text: root.t("dashboard.performance.empty")
                    }

                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    id: performanceColumn

                    objectName: "dashboardPerformanceData"
                    anchors.fill: parent
                    spacing: VitrailTokens.gap("sm")
                    visible: root.hasResources

                    Repeater {
                        model: root.metrics

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: modelData.icon
                                size: "sm"
                                tone: "secondary"
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "label"
                                text: modelData.label
                            }

                            VitrailText {
                                objectName: "dashboardValue_" + modelData.key
                                variant: "body"
                                font.features: ({ "tnum": 1 })
                                text: modelData.value
                            }
                        }
                    }
                }
            }

            // --- focus: the pomodoro and the free timer
            Item {
                objectName: "dashboardFocus"

                implicitHeight: focusColumn.implicitHeight

                ColumnLayout {
                    id: focusColumn

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("md")
                    visible: root.timerEngine !== null

                    FocusWidget {
                        objectName: "focusPomodoro"
                        Layout.fillWidth: true
                        name: "pomodoro"
                        title: root.t("dashboard.focus.pomodoro")
                        phase: root.pomodoroPhase(root.pomodoro)
                        remaining: Timers.format(root.clockLeft(root.pomodoro))
                        progress: root.clockProgress(root.pomodoro)
                        running: root.pomodoro ? root.pomodoro.running : false
                        done: root.pomodoro ? root.pomodoro.done : false
                        startText: root.t("dashboard.focus.start")
                        pauseText: root.t("dashboard.focus.pause")
                        resetText: root.t("dashboard.focus.reset")
                        onStartRequested: root.timerEngine.togglePomodoro()
                        onPauseRequested: root.timerEngine.pausePomodoro()
                        onResetRequested: root.timerEngine.resetPomodoro()
                    }

                    FocusWidget {
                        objectName: "focusTimer"
                        Layout.fillWidth: true
                        name: "timer"
                        title: root.t("dashboard.focus.timer")
                        phase: root.timerPhase(root.freeTimer)
                        remaining: Timers.format(root.clockLeft(root.freeTimer))
                        progress: root.clockProgress(root.freeTimer)
                        running: root.freeTimer ? root.freeTimer.running : false
                        done: root.freeTimer ? root.freeTimer.done : false
                        startText: root.t("dashboard.focus.start")
                        pauseText: root.t("dashboard.focus.pause")
                        resetText: root.t("dashboard.focus.reset")
                        editableMinutes: true
                        minutes: root.freeTimer ? root.freeTimer.minutes : 10
                        minutesLabel: root.t("dashboard.focus.minutes")
                        onStartRequested: root.timerEngine.toggleTimer(root.freeTimer.minutes)
                        onPauseRequested: root.timerEngine.pauseTimer()
                        onResetRequested: root.timerEngine.resetTimer()
                        onMinutesEdited: function (value) { root.timerEngine.setTimerMinutes(value) }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.timerEngine === null
                }
            }

            // --- media: the panel the caller supplies, or nothing playing
            Item {
                objectName: "dashboardMedia"

                implicitHeight: root.hasMedia ? mediaLoader.implicitHeight : mediaEmpty.implicitHeight

                ColumnLayout {
                    id: mediaEmpty

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("sm")
                    visible: !root.hasMedia

                    Item { Layout.fillHeight: true }

                    VitrailIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "music_note"
                        size: "xl"
                        tone: "muted"
                    }

                    VitrailText {
                        objectName: "dashboardMediaEmpty"
                        Layout.alignment: Qt.AlignHCenter
                        variant: "content"
                        text: root.t("dashboard.media.empty")
                    }

                    Item { Layout.fillHeight: true }
                }

                Loader {
                    id: mediaLoader

                    width: parent.width
                    active: root.currentTab === "media" && root.hasMedia && root.mediaPanel !== null
                    visible: root.hasMedia
                    sourceComponent: root.mediaPanel
                }
            }
        }
    }
}
