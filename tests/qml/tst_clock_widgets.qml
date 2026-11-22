import QtQuick
import QtTest
import "../../kit"
import "../../shell/pages"
import "../../bar/dashboard/dashboard.js" as Dash

// The clock popup's widgets: the preference's keys (in order, unknown and
// repeated dropped, empty meaning all five) and the settings section that
// writes it back.
TestCase {
    id: testCase

    name: "ClockWidgets"
    when: windowShown
    visible: true
    width: 900
    height: 700

    VitrailPalette {
        id: theme
    }

    QtObject {
        id: mockPrefs

        property string dashboardWidgets: ""
        property string barActiveOnly: ""
        property int brightnessStep: 5
        property int caffeineMinutes: 30
        property int clipboardbarRecent: 10
        property int colorpickerRecent: 12
        property string colorpickerColors: ""
        property string containersEngine: "auto"
        property string containersPinned: "[]"
        property bool disksAutomount: false
        property string disksIgnore: ""
        property int dndDefaultMinutes: 60
        property int downloadsRecent: 5
        property string healthChecks: '["services","disk","hyprland","doctor"]'
        property int healthDiskThreshold: 10
        property string marketCurrency: "eur"
        property int marketInterval: 15
        property string marketSymbols: '["bitcoin"]'
        property string netusageBar: "both"
        property string netusageUnits: "auto"
        property bool nightLightEnabled: false
        property string nightLightSchedule: '{"mode":"off","start":"20:00","end":"07:00"}'
        property int nightLightTemperature: 4000
        property int notesPopupMax: 5
        property string peripheralsHide: ""
        property int peripheralsLow: 15
        property string privacyDotColor: "error"
        property string privacyWatch: '["microphone","camera","screen"]'
        property string resourcesBar: "both"
        property int resourcesInterval: 2
        property string resourcesUnits: "auto"
        property int pomodoroCycles: 4
        property int pomodoroRest: 5
        property int pomodoroWork: 25
        property int timerMinutes: 10
        property string updatesAurHelper: "auto"
        property int updatesInterval: 60
        property string updatesSources: "official,aur,flatpak"
        property bool volumeHideSilent: false
        property bool volumePercent: false
        property int volumeStep: 5
        property string weatherCities: "[]"
        property int weatherInterval: 15
        property string weatherUnits: "metric"
    }

    Component {
        id: pageComponent

        BarElementsPage {
            palette: theme
            prefs: mockPrefs
            strings: ({})
        }
    }

    function initTestCase() {
        VitrailTokens.configure(theme, true, "glass", ({}))
    }

    function init() {
        mockPrefs.dashboardWidgets = ""
    }

    function make() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 860, height: 640 })
        verify(page, "the bar elements page loads")
        return page
    }

    function rows(text) {
        return Dash.widgetRows(text).map(function (row) { return row.key })
    }

    function test_the_shown_keys_keep_their_order_and_drop_the_rest() {
        compare(Dash.shownWidgets('["weather","media","calendar"]'), ["weather", "media", "calendar"])
        compare(Dash.shownWidgets('["media","nonsense","media","focus"]'), ["media", "focus"])
        compare(Dash.shownWidgets('["weather","nonsense"]'), ["weather"])
    }

    function test_an_empty_or_broken_preference_shows_all_five() {
        var all = ["calendar", "weather", "performance", "focus", "media"]
        compare(Dash.shownWidgets(""), all)
        compare(Dash.shownWidgets("[]"), all)
        compare(Dash.shownWidgets("not json"), all)
        compare(Dash.shownWidgets('["nonsense"]'), all)
        compare(Dash.shownWidgets(undefined), all)
    }

    function test_the_rows_list_the_shown_widgets_then_the_hidden_ones() {
        compare(rows(""), ["calendar", "weather", "performance", "focus", "media"])
        compare(rows('["media","calendar"]'),
                ["media", "calendar", "weather", "performance", "focus"])
    }

    function test_showing_and_hiding_round_trips_through_the_preference() {
        compare(Dash.withWidget("", "weather", false),
                '["calendar","performance","focus","media"]')
        compare(Dash.withWidget('["calendar","performance","focus","media"]', "weather", true),
                '["calendar","performance","focus","media","weather"]')
        compare(Dash.withWidget('["media"]', "weather", false), '["media"]')
        compare(Dash.shownCount('["media"]'), 1)
        compare(Dash.shownCount(""), 5)
    }

    function test_moving_swaps_with_the_neighbour_and_stops_at_the_edges() {
        compare(Dash.moveWidget('["calendar","weather","media"]', "media", -1),
                '["calendar","media","weather"]')
        compare(Dash.moveWidget('["calendar","media","weather"]', "calendar", 1),
                '["media","calendar","weather"]')
        compare(Dash.moveWidget('["calendar","weather"]', "calendar", -1),
                '["calendar","weather"]')
        compare(Dash.moveWidget('["calendar","weather"]', "weather", 1),
                '["calendar","weather"]')
    }

    function test_the_section_hides_a_widget() {
        var page = make()
        var toggle = findChild(page, "dashboardWidgetToggle-weather")
        verify(toggle !== null)
        compare(toggle.checked, true)
        toggle.toggled(false)
        compare(Dash.shownWidgets(mockPrefs.dashboardWidgets),
                ["calendar", "performance", "focus", "media"])
        // The hidden widget moves to the end of the section's rows.
        compare(rows(mockPrefs.dashboardWidgets),
                ["calendar", "performance", "focus", "media", "weather"])
    }

    function test_the_section_shows_a_hidden_widget_again() {
        var page = make()
        mockPrefs.dashboardWidgets = '["calendar","media"]'
        var toggle = findChild(page, "dashboardWidgetToggle-weather")
        verify(toggle !== null)
        compare(toggle.checked, false)
        toggle.toggled(true)
        compare(Dash.shownWidgets(mockPrefs.dashboardWidgets), ["calendar", "media", "weather"])
    }

    function test_the_section_moves_a_widget() {
        var page = make()
        var up = findChild(page, "dashboardWidgetMoveUp-media")
        verify(up !== null)
        up.clicked()
        compare(Dash.shownWidgets(mockPrefs.dashboardWidgets),
                ["calendar", "weather", "performance", "media", "focus"])
        var down = findChild(page, "dashboardWidgetMoveDown-media")
        down.clicked()
        compare(Dash.shownWidgets(mockPrefs.dashboardWidgets),
                ["calendar", "weather", "performance", "focus", "media"])
    }

    function test_the_last_shown_widget_cannot_be_hidden() {
        var page = make()
        mockPrefs.dashboardWidgets = '["media"]'
        var toggle = findChild(page, "dashboardWidgetToggle-media")
        verify(toggle !== null)
        compare(toggle.enabled, false)
        var hidden = findChild(page, "dashboardWidgetToggle-calendar")
        compare(hidden.enabled, true)
    }
}
