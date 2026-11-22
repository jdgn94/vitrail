import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/weather"
import "../../bar/weather/weather.js" as Weather

// The weather element: the temperature and unit the button shows, the WMO code
// to condition glyph mapping, the city switcher and the quiet error state. The
// snapshot is `vitrail/weather.py`'s flat shape.
TestCase {
    id: testCase

    name: "Weather"
    when: windowShown
    visible: true
    width: 460
    height: 760

    readonly property var strings: ({
        "bar.widget.weather": "Weather",
        "bar.weather.tooltip": "%1 · %2",
        "bar.weather.highLow": "H %1 · L %2",
        "bar.weather.unavailable": "Weather unavailable",
        "bar.weather.hourly": "Next hours",
        "bar.weather.daily": "Next days",
        "bar.weather.city": "City",
        "bar.weather.wind": "Wind",
        "bar.weather.error": "The last forecast could not be refreshed: %1",
        "weather.code.0": "Clear sky",
        "weather.code.2": "Partly cloudy",
        "weather.code.61": "Light rain"
    })

    function day(date, high, low, code) {
        return { date: date, high: high, low: low, code: code, condition: "Partly cloudy" }
    }

    function hour(time, temperature, code) {
        return { time: time, temperature: temperature, code: code }
    }

    readonly property var snapshot: ({
        location: { name: "Madrid", country: "Spain", latitude: 40.4, longitude: -3.7 },
        units: { temperature: "°C", humidity: "%", wind: "km/h" },
        current: { temperature: 18.4, humidity: 62, wind: 11.2, code: 2, condition: "Partly cloudy" },
        hourly: [
            hour("2026-11-04T15:00", 18.4, 2),
            hour("2026-11-04T16:00", 18.9, 3),
            hour("2026-11-04T17:00", 17.2, 61)
        ],
        daily: [
            day("2026-11-04", 21.0, 10.0, 2),
            day("2026-11-05", 20.5, 9.5, 3),
            day("2026-11-06", 19.0, 9.0, 61),
            day("2026-11-07", 18.0, 8.0, 61),
            day("2026-11-08", 17.5, 7.5, 2),
            day("2026-11-09", 16.0, 6.0, 0)
        ],
        updated: 1763730000,
        cached: false
    })

    Component {
        id: buttonComponent

        WeatherButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        WeatherPanel {
            width: 400
            strings: testCase.strings
            language: "en"
            cities: '["Madrid","Valencia"]'
            currentCity: "Madrid"
        }
    }

    SignalSpy { id: cityChosen; signalName: "citySelected" }
    SignalSpy { id: settingsAsked; signalName: "settingsRequested" }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function build(component, props) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        for (var key in props)
            item[key] = props[key]
        return item
    }

    function find(item, name) {
        var out = []
        function walk(node) {
            if (node.objectName === name)
                out.push(node)
            var kids = node.children || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i])
        }
        walk(item)
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_condition_icon_covers_every_group_of_wmo_codes() {
        compare(Weather.iconOf(0), "sunny")
        compare(Weather.iconOf(1), "partly_cloudy_day")
        compare(Weather.iconOf(2), "partly_cloudy_day")
        compare(Weather.iconOf(3), "cloud")
        compare(Weather.iconOf(45), "foggy")
        compare(Weather.iconOf(61), "rainy")
        compare(Weather.iconOf(71), "weather_snowy")
        compare(Weather.iconOf(95), "thunderstorm")
        compare(Weather.iconOf(1234), Weather.DEFAULT_ICON)
        compare(Weather.DEFAULT_ICON, "partly_cloudy_day")
    }

    function test_readiness_is_a_number_temperature() {
        compare(Weather.ready(snapshot), true)
        compare(Weather.current(snapshot).temperature, 18.4)
        compare(Weather.ready({ current: { temperature: "18" } }), false)
        compare(Weather.ready({ error: "offline" }), false)
        compare(Weather.ready({}), false)
        compare(Weather.ready(null), false)
    }

    function test_the_unit_comes_from_the_snapshot() {
        compare(Weather.units(snapshot).temperature, "°C")
        compare(Weather.units({}).temperature, "°")
        compare(Weather.units({ units: { temperature: "°F" } }).temperature, "°F")
    }

    function test_the_city_preference_is_a_json_array_of_names() {
        compare(Weather.cities('["Madrid","Valencia"]', "Madrid"), ["Madrid", "Valencia"])
        compare(Weather.cities("", "Madrid"), ["Madrid"])
        compare(Weather.cities("{broken", "Madrid"), ["Madrid"])
        compare(Weather.cities("[]", "Madrid"), ["Madrid"])
        compare(Weather.cities('[" Madrid ", "", "Valencia", "Madrid"]', "Madrid"), ["Madrid", "Valencia"])
        compare(Weather.cities("", ""), [])
        compare(Weather.withCities([" Madrid ", "", "Valencia", "Madrid"]), '["Madrid","Valencia"]')
    }

    function test_the_city_switcher_offers_the_configured_cities_once() {
        var options = Weather.cityOptions('["Valencia","Madrid"]', "Bilbao")
        compare(options.length, 3)
        compare(options[0].key, "Bilbao")
        compare(options[1].label, "Valencia")
        compare(options[2].label, "Madrid")
        compare(Weather.cityOptions('["Madrid"]', "Madrid").length, 1)
    }

    function test_the_interval_is_whole_minutes_within_the_module_window() {
        compare(Weather.intervalMinutes(15), 15)
        compare(Weather.intervalMinutes("30"), 30)
        compare(Weather.intervalMinutes(0), Weather.INTERVAL_MIN)
        compare(Weather.intervalMinutes(9999), Weather.INTERVAL_MAX)
        compare(Weather.intervalMinutes("soon"), Weather.INTERVAL_DEFAULT)
        compare(Weather.intervalMs(15), 900000)
    }

    function test_the_hourly_and_daily_lists_are_defensive() {
        compare(Weather.hours(snapshot).length, 3)
        compare(Weather.hours({}).length, 0)
        compare(Weather.hours({ hourly: "nope" }).length, 0)
        compare(Weather.days(snapshot, 5).length, 5)
        compare(Weather.days(snapshot).length, 5)
        compare(Weather.days({}).length, 0)
        compare(Weather.hourLabel("2026-11-04T15:00"), "15:00")
        compare(Weather.hourLabel("15:00"), "")
        compare(Weather.hourLabel(""), "")
    }

    function test_the_day_condition_falls_back_to_the_service_words() {
        compare(Weather.condition(testCase.strings, 2, "Partly cloudy"), "Partly cloudy")
        compare(Weather.condition(testCase.strings, 61, "Light rain"), "Light rain")
        compare(Weather.condition(testCase.strings, 1234, "Unknown"), "Unknown")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_rounded_temperature_and_its_unit() {
        var button = build(buttonComponent, { snapshot: snapshot })
        compare(button.text, "18 °C")
        compare(button.icon, "partly_cloudy_day")
        compare(button.active, true)
        compare(button.tooltip, "Madrid · Partly cloudy")
        compare(button.tooltipDetail, "H 21° · L 10°")
    }

    function test_the_unit_switch_changes_the_same_text() {
        var imperial = JSON.parse(JSON.stringify(snapshot))
        imperial.units.temperature = "°F"
        imperial.current.temperature = 65.1
        var button = build(buttonComponent, { snapshot: imperial })
        compare(button.text, "65 °F")
    }

    function test_without_a_temperature_the_button_is_inactive_and_says_so() {
        var button = build(buttonComponent, { snapshot: { error: "offline" } })
        compare(button.text, "")
        compare(button.active, false)
        compare(button.icon, Weather.DEFAULT_ICON)
        compare(button.tooltip, "Weather")
        compare(button.tooltipDetail, "Weather unavailable")
    }

    function test_only_while_active_hides_it_with_no_temperature() {
        var button = build(buttonComponent, { snapshot: { error: "offline" }, showMode: "active" })
        compare(button.shown, false)
        button.snapshot = snapshot
        compare(button.shown, true)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_panel_draws_the_current_reading_hours_and_five_days() {
        var panel = build(panelComponent, { snapshot: snapshot })
        compare(find(panel, "currentTemperature")[0].text, "18 °C")
        compare(find(panel, "currentCondition")[0].text, "Partly cloudy")
        compare(find(panel, "currentHighLow")[0].text, "H 21° · L 10°")
        compare(find(panel, "currentWind")[0].text, "11 km/h")
        compare(find(panel, "hour").length, 3)
        compare(find(panel, "day").length, 5)
        verify(!find(panel, "error")[0].visible)
    }

    function test_the_hour_strip_names_the_hour_and_its_temperature() {
        var panel = build(panelComponent, { snapshot: snapshot })
        var rows = find(panel, "hour")
        compare(find(rows[0], "hourTime")[0].text, "15:00")
        compare(find(rows[0], "hourTemperature")[0].text, "18 °C")
        compare(find(rows[0], "hourIcon")[0].icon, "partly_cloudy_day")
    }

    function test_the_city_switcher_updates_the_preference_the_module_reads() {
        var panel = build(panelComponent, { snapshot: snapshot })
        var city = find(panel, "city")[0]
        compare(city.current, "Madrid")
        compare(city.options.length, 2)
        cityChosen.target = panel
        cityChosen.clear()
        city.pick(1)
        compare(cityChosen.count, 1)
        compare(cityChosen.signalArguments[0][0], "Valencia")
    }

    function test_an_error_is_a_calm_line_and_the_warm_reading_stays() {
        var warm = JSON.parse(JSON.stringify(snapshot))
        warm.error = "offline"
        var panel = build(panelComponent, { snapshot: warm })
        compare(find(panel, "error")[0].visible, true)
        compare(find(panel, "error")[0].text, "The last forecast could not be refreshed: offline")
        compare(find(panel, "currentTemperature")[0].text, "18 °C")

        panel.snapshot = { error: "offline" }
        compare(find(panel, "error")[0].visible, true)
        compare(find(panel, "currentTemperature")[0].visible, false)
        compare(find(panel, "currentTemperature")[0].text, "--")
        compare(find(panel, "hour").length, 0)
        compare(find(panel, "day").length, 0)
    }

    function test_the_gear_is_the_last_item_of_the_first_row() {
        var panel = build(panelComponent, { snapshot: snapshot })
        var gears = find(panel, "popupSettings")
        compare(gears.length, 1)
        settingsAsked.target = panel
        settingsAsked.clear()
        gears[0].clicked()
        compare(settingsAsked.count, 1)
    }
}
