import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../widgets"
import "dashboard.js" as Dash

// The dashboard popup: the clock and date, then the month with today marked,
// the weather, the machine's performance, the focus widgets and now playing,
// as tabs. `dashboardWidgets` chooses which ones it shows and their order.
// Only the content lives here: the caller owns the data (see DashboardPopout,
// which runs the services while the popup is open), so the panel renders, and
// is tested, without a process.
Item {
    id: root

    property var strings: ({})
    property string language: "en"
    // The state of vitrail/weather.py and vitrail/resources.py; {} is empty.
    property var weather: ({})
    property var resources: ({})
    // The widget keys the popup shows, in order (DashboardPopout forwards
    // `dashboardWidgets`; empty shows all five in the built-in order).
    property string dashboardWidgets: ""
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
    signal settingsRequested()

    readonly property var widgetKeys: Dash.shownWidgets(root.dashboardWidgets)
    readonly property var tabs: root.widgetKeys.map(function (key) {
        return { key: key, label: root.t("dashboard.tab." + key), icon: Dash.widgetIcon(key) }
    })
    readonly property bool hasMedia: (root.mediaPlayer !== null && root.mediaPlayer !== undefined)
                                     || root.mediaPlayers.length > 0

    // One card size for every tab: the popup's implicit size is this card's,
    // so it must never follow the tab on screen. A taller tab scrolls inside.
    implicitWidth: VitrailTokens.dashboard.width
    implicitHeight: VitrailTokens.dashboard.height

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function showTab(key) {
        if (root.tabs.some(function (tab) { return tab.key === key }))
            root.currentTab = key
    }

    // The tab on screen disappeared with its widget: land on the first one.
    function ensureCurrentTab() {
        var tabs = root.tabs || []
        if (tabs.length === 0)
            return
        if (!tabs.some(function (tab) { return tab.key === root.currentTab }))
            root.currentTab = tabs[0].key
    }

    onTabsChanged: root.ensureCurrentTab()
    Component.onCompleted: root.ensureCurrentTab()

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

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailTabs {
            id: tabBar

            Layout.fillWidth: true
            tabs: root.tabs
            current: root.currentTab
            onSelected: function (key) { root.showTab(key) }
        }

        Flickable {
            id: scroller

            objectName: "dashboardScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: pages.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            StackLayout {
                id: pages

                objectName: "dashboardPages"
                width: scroller.width
                // The pages keep their built-in order as children; the tab
                // decides which one the stack shows (and its scroll height).
                currentIndex: pageOrder.indexOf(pageOf[root.currentTab] || null)
                // Only the tab on screen sets the scrollable height. The card
                // keeps its fixed size, so a taller page scrolls rather than
                // growing the popup; a shorter one leaves the rest empty
                // instead of padding it to the tallest sibling.
                readonly property var pageOf: ({
                    calendar: calendarPage,
                    weather: weatherPage,
                    performance: performancePage,
                    focus: focusPage,
                    media: mediaPage
                })
                readonly property var pageOrder: [calendarPage, weatherPage, performancePage,
                                                  focusPage, mediaPage]
                readonly property var pageFor: root.widgetKeys.map(function (key) { return pageOf[key] || null })
                readonly property var currentPage: pageFor[Math.max(0, root.widgetKeys.indexOf(root.currentTab))] || null
                height: currentPage ? currentPage.implicitHeight : 0

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
}
