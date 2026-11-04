import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "dashboard.js" as Dash

// The dashboard popup: the month with today marked, the weather, the machine's
// performance and now playing, in four tabs. Only the content lives here: the
// caller owns the data (see DashboardPopout, which runs the services while the
// popup is open), so the panel renders, and is tested, without a process.
Item {
    id: root

    property var strings: ({})
    property string language: "en"
    // The state of vitrail/weather.py and vitrail/resources.py; {} is empty.
    property var weather: ({})
    property var resources: ({})
    property string currentTab: "calendar"
    property date now: new Date()
    // Now playing, and the panel that draws it (the caller supplies it, so
    // this file needs no MPRIS import).
    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0
    property string mediaStyle: "disc"
    property Component mediaPanel: null

    signal playerChosen(int index)

    readonly property var tabs: [
        { key: "calendar", label: root.t("dashboard.tab.calendar"), icon: "calendar_month" },
        { key: "weather", label: root.t("dashboard.tab.weather"), icon: "partly_cloudy_day" },
        { key: "performance", label: root.t("dashboard.tab.performance"), icon: "monitoring" },
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
        var text = root.now.toLocaleDateString(Qt.locale(root.language), "MMMM yyyy")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function weekday(iso) {
        var date = new Date(String(iso || "") + "T12:00:00")
        if (isNaN(date.getTime()))
            return String(iso || "")
        return date.toLocaleDateString(Qt.locale(root.language), "ddd")
    }

    // The date changes under the panel; the calendar follows it while shown.
    Timer {
        interval: 60000
        repeat: true
        running: root.currentTab === "calendar"
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "space_dashboard"
                size: "md"
                tone: "primary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.t("dashboard.title")
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

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "body"
                        font.weight: Font.DemiBold
                        text: root.monthTitle()
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
                        month: root.now.getMonth()
                        year: root.now.getFullYear()

                        delegate: Item {
                            id: day

                            required property var model

                            readonly property bool today: day.model.today
                            readonly property bool inMonth: day.model.month === root.now.getMonth()

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
                                    text: weatherColumn.current.condition || ""
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
                                Layout.fillWidth: true
                                variant: "content"
                                text: forecastDay.modelData.condition || ""
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
