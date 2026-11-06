import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/dashboard"
import "../../bar/dashboard/dashboard.js" as Dash
import "../../bar/dashboard/timers.js" as Timers

// The dashboard: five tabs, the today calendar, the weather, the performance
// readout with its empty states and percentages, and the focus widgets.
TestCase {
    id: testCase

    name: "Dashboard"
    when: windowShown
    visible: true
    width: 520
    height: 760

    VitrailPalette {
        id: palette
    }

    Component {
        id: control

        Dashboard {
            width: 440
            language: "en"
        }
    }

    Component {
        id: engineControl

        TimerEngine {}
    }

    Component {
        id: mediaStub

        Rectangle {
            implicitWidth: 300
            implicitHeight: 240
        }
    }

    Component {
        id: tallMediaStub

        Rectangle {
            implicitWidth: 300
            implicitHeight: 900
        }
    }

    function initTestCase() {
        VitrailTokens.configure({
            surface: palette.surface,
            surfaceHigh: palette.surfaceHigh,
            foreground: palette.foreground,
            muted: palette.muted,
            primary: palette.primary,
            accentForeground: palette.accentForeground,
            info: palette.info,
            infoForeground: palette.infoForeground,
            error: palette.error,
            errorForeground: palette.errorForeground
        }, true, "glass", ({}))
    }

    function make(props) {
        var box = createTemporaryObject(control, testCase, props || {})
        verify(box)
        return box
    }

    function test_there_are_five_tabs_and_the_calendar_is_first() {
        var box = make()
        compare(box.tabs.length, 5)
        compare(box.tabs.map(function (tab) { return tab.key }),
                ["calendar", "weather", "performance", "focus", "media"])
        compare(box.currentTab, "calendar")
        verify(findChild(box, "dashboardCalendar").visible)
    }

    function test_choosing_a_tab_shows_its_page() {
        var box = make()
        box.showTab("weather")
        compare(box.currentTab, "weather")
        verify(findChild(box, "dashboardWeather").visible)
        verify(!findChild(box, "dashboardCalendar").visible)
        box.showTab("performance")
        verify(findChild(box, "dashboardPerformance").visible)
        box.showTab("media")
        verify(findChild(box, "dashboardMedia").visible)
        box.showTab("focus")
        verify(findChild(box, "dashboardFocus").visible)
        box.showTab("calendar")
        verify(findChild(box, "dashboardCalendar").visible)
    }

    function test_the_dashboard_starts_with_the_clock_and_the_date() {
        var when = new Date(2026, 10, 4, 14, 5)
        var box = make({ now: when })
        compare(findChild(box, "dashboardClock").text, "14:05")
        var day = when.toLocaleDateString(Qt.locale("en"), "dddd d MMMM yyyy")
        compare(findChild(box, "dashboardClockDate").text,
                day.charAt(0).toUpperCase() + day.slice(1))
    }

    function test_the_calendar_pages_by_month_and_returns_to_today() {
        var box = make({ now: new Date(2026, 10, 4, 14, 5) })
        box.page(1)
        compare(box.shown.getMonth(), 11)
        verify(!box.showingThisMonth())
        box.shown = new Date(box.now.getFullYear(), box.now.getMonth(), 1)
        verify(box.showingThisMonth())
    }

    function test_an_unknown_tab_is_ignored() {
        var box = make()
        box.showTab("nonsense")
        compare(box.currentTab, "calendar")
    }

    function test_the_weather_and_performance_pages_have_an_empty_state() {
        var box = make({ weather: ({}), resources: ({}) })
        box.showTab("weather")
        verify(findChild(box, "dashboardWeatherEmpty").visible)
        box.showTab("performance")
        verify(findChild(box, "dashboardPerformanceEmpty").visible)
        box.showTab("media")
        verify(findChild(box, "dashboardMediaEmpty").visible)
    }

    function test_the_focus_tab_draws_the_pomodoro_and_the_timer() {
        var engine = createTemporaryObject(engineControl, testCase, {
            workMinutes: 25, restMinutes: 5, cycles: 4, timerMinutes: 10
        })
        var strings = {
            "dashboard.focus.work": "Work",
            "dashboard.focus.rest": "Break",
            "dashboard.focus.round": "Round",
            "dashboard.focus.done": "Done",
            "dashboard.focus.ready": "Ready",
            "dashboard.focus.paused": "Paused",
            "dashboard.focus.timer": "Timer",
            "dashboard.focus.pomodoro": "Pomodoro"
        }
        var box = make({ timerEngine: engine, strings: strings })
        box.showTab("focus")
        verify(findChild(box, "focusPomodoro").visible)
        verify(findChild(box, "focusTimer").visible)
        compare(findChild(box, "focusRemaining_pomodoro").text, "25:00")
        compare(findChild(box, "focusRemaining_timer").text, "10:00")
        compare(findChild(box, "focusPhase_pomodoro").text, "Work · Round 1/4")
        compare(findChild(box, "focusPhase_timer").text, "Ready")
    }

    function test_the_focus_actions_reach_the_engine() {
        var engine = createTemporaryObject(engineControl, testCase, { timerMinutes: 10 })
        var strings = {
            "dashboard.focus.work": "Work",
            "dashboard.focus.rest": "Break",
            "dashboard.focus.round": "Round",
            "dashboard.focus.done": "Done",
            "dashboard.focus.ready": "Ready",
            "dashboard.focus.paused": "Paused",
            "dashboard.focus.timer": "Timer",
            "dashboard.focus.pomodoro": "Pomodoro"
        }
        var box = make({ timerEngine: engine, strings: strings })
        box.showTab("focus")
        findChild(box, "focusToggle_pomodoro").clicked()
        compare(engine.pomodoro.running, true)
        compare(findChild(box, "focusPhase_pomodoro").text, "Work · Round 1/4")
        findChild(box, "focusToggle_pomodoro").clicked()
        compare(engine.pomodoro.running, false)
        compare(findChild(box, "focusPhase_pomodoro").text, "Work · Round 1/4")
        findChild(box, "focusReset_pomodoro").clicked()
        compare(engine.pomodoro.left, 1500)
        compare(findChild(box, "focusRemaining_pomodoro").text, "25:00")

        findChild(box, "focusToggle_timer").clicked()
        compare(engine.timer.running, true)
        findChild(box, "focusToggle_timer").clicked()
        compare(engine.timer.running, false)
        findChild(box, "focusReset_timer").clicked()
        compare(engine.timer.left, 600)
    }

    function test_the_timer_field_sets_the_free_length() {
        var engine = createTemporaryObject(engineControl, testCase, { timerMinutes: 10 })
        var box = make({ timerEngine: engine })
        box.showTab("focus")
        var field = findChild(box, "focusMinutes_timer")
        field.text = "42"
        compare(engine.timerMinutes, 42)
        compare(findChild(box, "focusRemaining_timer").text, "42:00")
    }

    function test_the_weather_shows_the_place_current_conditions_and_four_days() {        var box = make({
            weather: ({
                location: { name: "Madrid" },
                units: { temperature: "°C", humidity: "%", wind: "km/h" },
                current: { temperature: 18.4, humidity: 62, wind: 11.2, condition: "Partly cloudy" },
                daily: [
                    { date: "2026-11-04", high: 21, low: 10, condition: "Partly cloudy" },
                    { date: "2026-11-05", high: 20, low: 9, condition: "Overcast" },
                    { date: "2026-11-06", high: 19, low: 9, condition: "Light rain" },
                    { date: "2026-11-07", high: 18, low: 8, condition: "Light rain" },
                    { date: "2026-11-08", high: 17, low: 7, condition: "Light showers" },
                    { date: "2026-11-09", high: 16, low: 6, condition: "Clear sky" },
                    { date: "2026-11-10", high: 15, low: 5, condition: "Mainly clear" }
                ]
            })
        })
        box.showTab("weather")
        verify(findChild(box, "dashboardWeatherData").visible)
        verify(!findChild(box, "dashboardWeatherEmpty").visible)
        compare(findChild(box, "dashboardWeatherLocation").text, "Madrid")
        compare(findChild(box, "dashboardWeatherTemperature").text, "18 °C")
        compare(findChild(box, "dashboardWeatherCondition").text, "Partly cloudy")
        compare(findChild(box, "dashboardWeatherHumidity").text, "62 %")
        compare(findChild(box, "dashboardWeatherWind").text, "11.2 km/h")
        compare(box.forecast.length, 4)
    }

    function test_the_conditions_follow_the_language() {
        var box = make({
            strings: ({ "weather.code.2": "Parcialmente nublado", "weather.code.3": "Cubierto" }),
            weather: ({
                location: { name: "Madrid" },
                units: { temperature: "°C", humidity: "%", wind: "km/h" },
                current: { temperature: 18.4, humidity: 62, wind: 11.2, code: 2, condition: "Partly cloudy" },
                daily: [
                    { date: "2026-11-04", high: 21, low: 10, code: 3, condition: "Overcast" },
                    { date: "2026-11-05", high: 20, low: 9, code: 2, condition: "Partly cloudy" }
                ]
            })
        })
        box.showTab("weather")
        compare(findChild(box, "dashboardWeatherCondition").text, "Parcialmente nublado")
        compare(findChild(box, "dashboardWeatherDayCondition0").text, "Cubierto")
        compare(findChild(box, "dashboardWeatherDayCondition1").text, "Parcialmente nublado")
    }

    function test_an_unknown_code_keeps_the_service_text() {
        var box = make({
            weather: ({
                location: { name: "Madrid" },
                units: { temperature: "°C", humidity: "%", wind: "km/h" },
                current: { temperature: 18.4, humidity: 62, wind: 11.2, code: 1234, condition: "Unknown" },
                daily: []
            })
        })
        box.showTab("weather")
        compare(findChild(box, "dashboardWeatherCondition").text, "Unknown")
    }

    function test_the_performance_values_are_formatted() {
        var box = make({
            resources: ({
                cpu: 14.8,
                cpuTicks: { total: 10, idle: 9 },
                memory: { used: 2 * 1024 * 1024 * 1024, total: 8 * 1024 * 1024 * 1024, percent: 25 },
                temperature: 52,
                network: { rx: 1024 * 1024, tx: 2 * 1024 * 1024 },
                disk: { used: 50 * 1024 * 1024 * 1024, total: 200 * 1024 * 1024 * 1024, percent: 25 }
            })
        })
        box.showTab("performance")
        verify(findChild(box, "dashboardPerformanceData").visible)
        compare(findChild(box, "dashboardValue_cpu").text, "15%")
        compare(findChild(box, "dashboardValue_memory").text, "2.0 GB / 8.0 GB · 25%")
        compare(findChild(box, "dashboardValue_temperature").text, "52 °C")
        compare(findChild(box, "dashboardValue_disk").text, "50.0 GB / 200.0 GB · 25%")
        compare(findChild(box, "dashboardValue_network").text, "↓ 1.0 MB  ↑ 2.0 MB")
    }

    function test_a_first_reading_without_cpu_is_shown_as_absent() {
        var box = make({
            resources: ({
                cpu: null,
                memory: { used: 0, total: 0, percent: 0 },
                temperature: null,
                network: { rx: 0, tx: 0 },
                disk: { used: 0, total: 0, percent: 0 }
            })
        })
        box.showTab("performance")
        compare(findChild(box, "dashboardValue_cpu").text, "--")
        compare(findChild(box, "dashboardValue_temperature").text, "--")
    }

    function test_the_card_keeps_one_size_across_the_tabs() {
        var box = make()
        var pages = findChild(box, "dashboardPages")
        var scroller = findChild(box, "dashboardScroll")
        verify(scroller !== null)
        var keys = ["calendar", "weather", "performance", "focus", "media"]
        var names = {
            calendar: "dashboardCalendar",
            weather: "dashboardWeather",
            performance: "dashboardPerformance",
            focus: "dashboardFocus",
            media: "dashboardMedia"
        }
        for (var i = 0; i < keys.length; i++) {
            box.showTab(keys[i])
            // The layout recalculates on the next polish pass.
            wait(50)
            var page = findChild(box, names[keys[i]])
            // The page still decides what the scroller shows...
            compare(pages.height, page.implicitHeight)
            compare(scroller.contentHeight, pages.height)
            // ...but the card keeps the one token size on every tab, so the
            // popup (whose implicit size is this card's) never resizes.
            compare(box.implicitWidth, VitrailTokens.dashboard.width)
            compare(box.implicitHeight, VitrailTokens.dashboard.height)
        }
    }

    function test_the_media_tab_follows_what_is_playing() {
        var box = make()
        var pages = findChild(box, "dashboardPages")
        var media = findChild(box, "dashboardMedia")
        box.showTab("media")
        wait(50)
        compare(pages.height, media.implicitHeight)
        var emptyHeight = box.implicitHeight
        box.mediaPlayer = ({})
        box.mediaPanel = mediaStub
        wait(50)
        compare(pages.height, media.implicitHeight)
        compare(media.implicitHeight, 240)
        // The card keeps its fixed size; the taller page scrolls inside it.
        compare(box.implicitHeight, emptyHeight)
        compare(box.implicitHeight, VitrailTokens.dashboard.height)
    }

    function test_a_tall_tab_scrolls_inside_the_fixed_card() {
        var box = make()
        var pages = findChild(box, "dashboardPages")
        var scroller = findChild(box, "dashboardScroll")
        box.mediaPlayer = ({})
        box.mediaPanel = tallMediaStub
        box.showTab("media")
        wait(50)
        compare(pages.height, 900)
        // The card does not grow: the content is what scrolls.
        compare(box.implicitHeight, VitrailTokens.dashboard.height)
        verify(scroller.contentHeight > scroller.height, "the tall page does not scroll")
        scroller.contentY = 120
        compare(scroller.contentY, 120)
    }

    function test_the_percentage_format() {
        compare(Dash.percent(42.6), "43%")
        compare(Dash.percent(0), "0%")
        compare(Dash.percent(100), "100%")
        compare(Dash.percent(150), "100%")
        compare(Dash.percent(-3), "0%")
        compare(Dash.percent(undefined), "--")
        compare(Dash.percent("nope"), "--")
    }

    function test_the_byte_format() {
        compare(Dash.bytes(0), "0 B")
        compare(Dash.bytes(1024), "1.0 KB")
        compare(Dash.bytes(1536), "1.5 KB")
        compare(Dash.bytes(5 * 1024 * 1024 * 1024), "5.0 GB")
        compare(Dash.bytes(-1), "--")
        compare(Dash.bytes(undefined), "--")
    }

    function test_a_broken_state_is_ignored() {
        compare(Dash.parse("not json"), ({}))
        compare(Dash.parse(""), ({}))
        compare(Dash.parse('{"cpu": 1}'), { cpu: 1 })
    }
}
