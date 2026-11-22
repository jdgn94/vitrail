import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../dashboard/dashboard.js" as Dash
import "weather.js" as Weather

// The weather element's popup: now (condition, temperature, high/low and wind
// when the answer has it), the hourly strip the module returns, the next five
// days, and a city switcher over `weatherCities` that writes the preference
// the module reads (`weatherLocation`). With a warm cache an offline answer
// keeps the reading and adds a calm error line; with no cache it is only that
// line. The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The configured city list (one JSON array); empty follows the snapshot.
    property var cities: ""
    property string currentCity: ""
    property string language: "en"

    signal settingsRequested()
    // The city the user picked from the switcher; the shell writes it to the
    // preference the module reads and asks for a fresh snapshot.
    signal citySelected(string city)

    readonly property bool ready: Weather.ready(root.snapshot)
    readonly property var current: Weather.current(root.snapshot)
    readonly property var unit: Weather.units(root.snapshot)
    readonly property var highLow: Weather.highLow(root.snapshot)
    readonly property var hours: Weather.hours(root.snapshot)
    readonly property var days: Weather.days(root.snapshot, 5)
    readonly property string error: root.snapshot && root.snapshot.error !== undefined
                                    ? String(root.snapshot.error) : ""
    readonly property string wind: Weather.wind(root.snapshot)
    readonly property string city: root.snapshot && root.snapshot.location
                                    && root.snapshot.location.name !== undefined
                                    ? String(root.snapshot.location.name) : root.currentCity
    readonly property var cityOptions: Weather.cityOptions(root.cities, root.city)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function conditionOf(code, fallback) {
        return Weather.condition(root.strings, code, fallback)
    }

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.weather")
            }

            VitrailSelect {
                objectName: "city"

                Layout.preferredWidth: VitrailTokens.size("display") * 5
                label: root.t("bar.weather.city")
                options: root.cityOptions
                current: root.city
                onSelected: function (key) { root.citySelected(key) }
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "error"

            Layout.fillWidth: true
            visible: root.error !== ""
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.t("bar.weather.error").replace("%1", root.error)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.ready
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                Layout.alignment: Qt.AlignTop
                icon: Weather.iconOf(root.current.code)
                size: "lg"
                tone: "secondary"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailText {
                    objectName: "currentTemperature"

                    variant: "title"
                    text: Dash.temperature(root.current.temperature, root.unit.temperature)
                }

                VitrailText {
                    objectName: "currentCondition"

                    Layout.fillWidth: true
                    variant: "body"
                    elide: Text.ElideRight
                    text: root.conditionOf(root.current.code, root.current.condition)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.ready
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                objectName: "currentHighLow"

                variant: "label"
                text: root.t("bar.weather.highLow")
                          .replace("%1", Dash.degrees(root.highLow.high))
                          .replace("%2", Dash.degrees(root.highLow.low))
            }

            Item { Layout.fillWidth: true }

            VitrailText {
                visible: root.wind !== ""
                variant: "label"
                text: root.t("bar.weather.wind")
            }

            VitrailText {
                objectName: "currentWind"

                visible: root.wind !== ""
                variant: "body"
                text: root.wind
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.hours.length > 0
            variant: "label"
            text: root.t("bar.weather.hourly")
        }

        Flickable {
            id: hourStrip

            Layout.fillWidth: true
            Layout.preferredHeight: hourRow.implicitHeight
            visible: root.hours.length > 0
            contentWidth: hourRow.implicitWidth
            contentHeight: hourRow.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            RowLayout {
                id: hourRow

                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.hours

                    delegate: ColumnLayout {
                        required property var modelData

                        objectName: "hour"
                        spacing: VitrailTokens.gap("xs")

                        VitrailText {
                            objectName: "hourTime"

                            Layout.alignment: Qt.AlignHCenter
                            variant: "label"
                            text: Weather.hourLabel(modelData.time)
                        }

                        VitrailIcon {
                            objectName: "hourIcon"

                            Layout.alignment: Qt.AlignHCenter
                            icon: Weather.iconOf(modelData.code)
                            size: "sm"
                            tone: "secondary"
                        }

                        VitrailText {
                            objectName: "hourTemperature"

                            Layout.alignment: Qt.AlignHCenter
                            variant: "label"
                            text: Dash.temperature(modelData.temperature, root.unit.temperature)
                        }
                    }
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.days.length > 0
            variant: "label"
            text: root.t("bar.weather.daily")
        }

        Repeater {
            model: root.days

            delegate: RowLayout {
                id: forecastDay

                required property var modelData

                objectName: "day"
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    variant: "label"
                    text: Weather.weekday(forecastDay.modelData.date, root.language)
                }

                VitrailIcon {
                    icon: Weather.iconOf(forecastDay.modelData.code)
                    size: "sm"
                    tone: "secondary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    elide: Text.ElideRight
                    text: root.conditionOf(forecastDay.modelData.code, forecastDay.modelData.condition)
                }

                VitrailText {
                    variant: "body"
                    text: Dash.degrees(forecastDay.modelData.high) + " / "
                          + Dash.degrees(forecastDay.modelData.low)
                }
            }
        }
    }
}
