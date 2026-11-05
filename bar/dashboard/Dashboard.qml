import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../widgets"

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
    readonly property bool hasMedia: (root.mediaPlayer !== null && root.mediaPlayer !== undefined)
                                     || root.mediaPlayers.length > 0

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

    function page(step) {
        root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + step, 1)
    }

    // Whether the calendar is already on the month of today.
    function showingThisMonth() {
        return root.shown.getMonth() === root.now.getMonth()
               && root.shown.getFullYear() === root.now.getFullYear()
    }

    // The weather page computes the same forecast it draws (kept here because
    // the dashboard's tests and callers read it).
    readonly property var forecast: weatherWidget ? weatherWidget.forecast : []

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

            DashboardClock {
                Layout.fillWidth: true
                now: root.now
                language: root.language
                size: "md"
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

            objectName: "dashboardPages"
            Layout.fillWidth: true
            currentIndex: root.tabs.findIndex(function (tab) { return tab.key === root.currentTab })
            // Only the tab on screen sizes the card. The layout's default is
            // the tallest child, which padded the shorter tabs (the calendar,
            // a media tab with nothing playing) with empty space.
            readonly property var pageFor: [calendarPage, weatherPage, performancePage, focusPage, mediaPage]
            readonly property var currentPage: pageFor[currentIndex] || null
            Layout.preferredHeight: currentPage ? currentPage.implicitHeight : 0

            // --- calendar: the month, with today in the accent circle
            Item {
                id: calendarPage
                objectName: "dashboardCalendar"

                implicitHeight: calendarWidget.implicitHeight

                DashboardCalendar {
                    id: calendarWidget

                    anchors.fill: parent
                    now: root.now
                    shown: root.shown
                    language: root.language
                    size: "md"
                    todayText: root.t("clock.today")
                    onPageRequested: function (step) { root.page(step) }
                    onTodayRequested: root.shown = new Date()
                }
            }

            // --- weather: the place, now, then the next four days
            Item {
                id: weatherPage
                objectName: "dashboardWeather"

                implicitHeight: weatherWidget.implicitHeight

                DashboardWeather {
                    id: weatherWidget

                    anchors.fill: parent
                    weather: root.weather
                    strings: root.strings
                    language: root.language
                    size: "md"
                }
            }

            // --- performance: CPU, memory, temperature, disk and network
            Item {
                id: performancePage
                objectName: "dashboardPerformance"

                implicitHeight: resourcesWidget.implicitHeight

                DashboardResources {
                    id: resourcesWidget

                    anchors.fill: parent
                    readings: root.resources
                    strings: root.strings
                    size: "md"
                }
            }

            // --- focus: the pomodoro and the free timer
            Item {
                id: focusPage
                objectName: "dashboardFocus"

                implicitHeight: focusColumn.implicitHeight

                ColumnLayout {
                    id: focusColumn

                    anchors.fill: parent
                    spacing: VitrailTokens.gap("md")

                    DashboardFocus {
                        objectName: "focusPomodoro"
                        Layout.fillWidth: true
                        engine: root.timerEngine
                        kind: "pomodoro"
                        strings: root.strings
                        now: root.now.getTime()
                        size: "md"
                    }

                    DashboardFocus {
                        objectName: "focusTimer"
                        Layout.fillWidth: true
                        engine: root.timerEngine
                        kind: "timer"
                        strings: root.strings
                        now: root.now.getTime()
                        size: "md"
                    }
                }
            }

            // --- media: the panel the caller supplies, or nothing playing
            Item {
                id: mediaPage
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
