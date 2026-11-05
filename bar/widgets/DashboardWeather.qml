import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../dashboard/dashboard.js" as Dash

// The dashboard's weather: the place and now, then the next four days. The
// same component draws the desktop weather; `variant: "compact"` keeps only
// the current reading.
Item {
    id: root

    property var weather: ({})
    property var strings: ({})
    property string language: "en"
    property string size: "md"
    property string variant: ""

    readonly property bool hasWeather: !!(root.weather && root.weather.current)
    readonly property bool compact: root.variant === "compact"
    readonly property var forecast: {
        var days = root.hasWeather ? root.weather.daily : null
        if (!days || days.length === undefined)
            return []
        var shown = []
        for (var i = 0; i < Math.min(4, days.length); i++)
            shown.push(days[i])
        return shown
    }
    readonly property var look: ({
        sm: { temperature: "title", condition: "label", detail: "label" },
        md: { temperature: "display", condition: "content", detail: "content" },
        lg: { temperature: "display", condition: "body", detail: "body" }
    })[root.size] || ({ temperature: "display", condition: "content", detail: "content" })

    implicitHeight: root.hasWeather ? weatherColumn.implicitHeight : weatherEmpty.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
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

    ColumnLayout {
        id: weatherEmpty

        anchors.fill: parent
        spacing: VitrailTokens.gap("sm")
        visible: !root.hasWeather

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
            wrapMode: Text.WordWrap
        }
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
                    elide: Text.ElideRight
                    text: root.weather.location ? root.weather.location.name : ""
                }

                RowLayout {
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        objectName: "dashboardWeatherTemperature"
                        variant: root.look.temperature
                        text: Dash.temperature(weatherColumn.current.temperature,
                                               weatherColumn.units.temperature)
                    }

                    VitrailText {
                        objectName: "dashboardWeatherCondition"
                        Layout.alignment: Qt.AlignBottom
                        variant: root.look.condition
                        elide: Text.ElideRight
                        text: root.condition(weatherColumn.current.code,
                                             weatherColumn.current.condition)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("md")
            visible: !root.compact

            VitrailText {
                variant: "label"
                text: root.t("dashboard.humidity")
            }

            VitrailText {
                objectName: "dashboardWeatherHumidity"
                variant: root.look.detail
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
                variant: root.look.detail
                font.features: ({ "tnum": 1 })
                text: weatherColumn.current.wind !== undefined
                      ? weatherColumn.current.wind + " " + (weatherColumn.units.wind || "")
                      : "--"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: !root.compact
            color: VitrailTokens.solid("foreground", 0.12)
        }

        Repeater {
            model: root.compact ? [] : root.forecast

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
                    variant: root.look.detail
                    elide: Text.ElideRight
                    text: root.condition(forecastDay.modelData.code, forecastDay.modelData.condition)
                }

                VitrailText {
                    variant: root.look.detail
                    font.features: ({ "tnum": 1 })
                    text: Dash.degrees(forecastDay.modelData.high) + " / "
                          + Dash.degrees(forecastDay.modelData.low)
                }
            }
        }
    }
}
