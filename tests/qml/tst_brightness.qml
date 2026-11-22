import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/brightness"
import "../../bar/brightness/brightness.js" as Brightness

// The brightness element: the wheel arithmetic (reusing the OSD's), the
// percentage and icon of the button, the popup's row per monitor (including
// the disabled one), the night light switch, its schedule and the next change
// text the module computed.
TestCase {
    id: testCase

    name: "Brightness"
    when: windowShown
    visible: true
    width: 420
    height: 900

    readonly property var strings: ({
        "bar.widget.brightness": "Brightness",
        "bar.brightness.unreadable": "Cannot read the displays.",
        "bar.brightness.reason.ddc": "This display does not answer over DDC/CI.",
        "bar.brightness.reason.backlight": "This display has no backlight Vitrail can dim.",
        "bar.brightness.monitors": "Displays",
        "bar.brightness.nightLight": "Night light",
        "bar.brightness.nightLight.help": "Warm the screen's colour.",
        "bar.brightness.temperature": "Colour temperature",
        "bar.brightness.temperature.help": "Lower is warmer.",
        "bar.brightness.schedule": "Schedule",
        "bar.brightness.schedule.off": "Off",
        "bar.brightness.schedule.fixed": "Fixed hours",
        "bar.brightness.schedule.sun": "Sunset to sunrise",
        "bar.brightness.start": "On at",
        "bar.brightness.end": "Off at",
        "bar.brightness.sunTimes": "Sunset %1 · sunrise %2",
        "bar.brightness.sunUnavailable": "The weather has no sun times; the fixed hours are used.",
        "bar.brightness.next.on": "On at %1",
        "bar.brightness.next.off": "Off at %1",
        "osd.brightnessAccess": "Brightness needs i2c access.",
        "osd.brightnessMissing": "Install ddcutil.",
        "osd.brightnessNone": "No adjustable display found.",
        "osd.brightnessLoading": "Looking for displays…"
    })

    function snapshot() {
        return {
            status: "ok",
            devices: [
                { name: "eDP-1", kind: "backlight", device: "intel_backlight", percent: 60, max: 10000 },
                { name: "DP-1", kind: "ddc", bus: 6, percent: 40, max: 100 }
            ]
        }
    }

    function nightlight(next) {
        return {
            enabled: true,
            temperature: 4000,
            schedule: { mode: "fixed", start: "20:00", end: "07:00", sunrise: null, sunset: null },
            effective: { temperature: 4000, active: true },
            next: next,
            error: null
        }
    }

    Component {
        id: buttonComponent

        BrightnessButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        BrightnessPanel {
            width: 380
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: brightnesses; signalName: "brightnessRequested" }
    SignalSpy { id: schedules; signalName: "scheduleRequested" }
    SignalSpy { id: temperatures; signalName: "temperatureRequested" }
    SignalSpy { id: nightLights; signalName: "nightLightToggled" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_step_is_a_whole_percent_from_one_to_twenty() {
        compare(Brightness.step(5), 5)
        compare(Brightness.step(0), 1)
        compare(Brightness.step(99), 20)
        compare(Brightness.step("7"), 7)
        compare(Brightness.step(2.6), 3)
        compare(Brightness.step("loud"), 5)
        compare(Brightness.step(undefined), 5)
    }

    function test_a_notch_moves_the_primary_monitor_by_one_step() {
        var data = snapshot()
        var up = Brightness.wheelTarget(data, "DP-1", 120, 5)
        compare(up.name, "DP-1")
        compare(up.percent, 45)
        var down = Brightness.wheelTarget(data, "DP-1", -120, 5)
        compare(down.name, "DP-1")
        compare(down.percent, 35)
        compare(Brightness.wheelTarget(data, "DP-1", 240, 5).percent, 50)
        compare(Brightness.wheelTarget(data, "DP-1", 0, 5), null)
        compare(Brightness.wheelTarget(data, "DP-1", NaN, 5), null)
    }

    function test_the_primary_falls_back_to_the_first_readable_monitor() {
        var data = snapshot()
        compare(Brightness.primary(data, "eDP-1").name, "eDP-1")
        compare(Brightness.primary(data, "HDMI-A-1").name, "eDP-1")
        compare(Brightness.primary({ status: "none", devices: [] }, "DP-1"), null)
    }

    function test_a_notch_clamps_at_the_ends() {
        var data = { status: "ok", devices: [{ name: "DP-1", kind: "ddc", bus: 6, percent: 98, max: 100 }] }
        compare(Brightness.wheelTarget(data, "DP-1", 120, 5).percent, 100)
        data.devices[0].percent = 2
        compare(Brightness.wheelTarget(data, "DP-1", -120, 5).percent, 0)
    }

    function test_the_glyph_follows_the_level() {
        compare(Brightness.icon({ percent: 10 }), "brightness_low")
        compare(Brightness.icon({ percent: 50 }), "brightness_medium")
        compare(Brightness.icon({ percent: 90 }), "brightness_high")
        compare(Brightness.icon(null), "brightness_low")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_names_the_primary_monitor_and_its_level() {
        var item = make(buttonComponent)
        item.snapshot = snapshot()
        item.primary = "DP-1"
        compare(item.text, "")
        compare(item.icon, "brightness_medium")
        compare(item.tooltip, "DP-1")
        compare(item.tooltipDetail, "40%")
        compare(item.active, true)
    }

    function test_without_a_readable_monitor_the_button_says_why() {
        var item = make(buttonComponent)
        item.snapshot = { status: "access", devices: [] }
        compare(item.tooltip, "Brightness")
        compare(item.tooltipDetail, "Brightness needs i2c access.")
        compare(item.icon, "brightness_low")
    }

    function test_one_notch_is_one_brightness_request() {
        var item = make(buttonComponent)
        item.snapshot = snapshot()
        item.primary = "DP-1"
        item.step = 7
        brightnesses.target = item
        brightnesses.clear()
        mouseWheel(item, 20, 20, 0, 120)
        compare(brightnesses.count, 1)
        compare(brightnesses.signalArguments[0][0], "DP-1")
        compare(brightnesses.signalArguments[0][1], 47)
        mouseWheel(item, 20, 20, 0, -120)
        compare(brightnesses.count, 2)
        compare(brightnesses.signalArguments[1][1], 33)
    }

    function test_a_left_click_opens_the_popup_not_a_change() {
        var item = make(buttonComponent)
        item.snapshot = snapshot()
        brightnesses.target = item
        brightnesses.clear()
        var clicks = 0
        item.clicked.connect(function () { clicks++ })
        mouseClick(item, 20, 20, Qt.LeftButton)
        compare(clicks, 1)
        compare(brightnesses.count, 0)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_draws_one_row_per_monitor_and_disables_the_unreadable_one() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot()
        panel.screens = ["eDP-1", "DP-1", "HDMI-A-1"]
        compare(panel.rows.length, 3)
        compare(panel.rows[0].readable, true)
        compare(panel.rows[0].percent, 60)
        compare(panel.rows[1].percent, 40)
        compare(panel.rows[2].readable, false)
        compare(panel.rows[2].reason, "bar.brightness.reason.ddc")
    }

    function test_an_internal_monitor_without_a_backlight_says_so() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot()
        panel.screens = ["eDP-2"]
        compare(panel.rows[0].readable, false)
        compare(panel.rows[0].reason, "bar.brightness.reason.backlight")
    }

    function test_a_drag_asks_for_that_monitors_level() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot()
        panel.screens = ["DP-1"]
        brightnesses.target = panel
        brightnesses.clear()
        panel.brightnessRequested("DP-1", 33)
        compare(brightnesses.signalArguments[0][0], "DP-1")
        compare(brightnesses.signalArguments[0][1], 33)
    }

    function test_the_next_change_is_the_modules_text() {
        var panel = make(panelComponent)
        panel.nightlight = nightlight({ at: "19:42", temperature: 4000, active: true })
        compare(panel.nextText, "On at 19:42")
        panel.nightlight = nightlight({ at: "07:00", temperature: 6500, active: false })
        compare(panel.nextText, "Off at 07:00")
        panel.nightlight = nightlight(null)
        compare(panel.nextText, "")
    }

    function test_the_night_light_switch_and_temperature_ask_the_shell() {
        var panel = make(panelComponent)
        panel.temperature = 4000
        temperatures.target = panel
        nightLights.target = panel
        temperatures.clear()
        nightLights.clear()
        var toggle = findChild(panel, "nightLightSwitch")
        verify(toggle !== null)
        toggle.toggled(true)
        compare(nightLights.count, 1)
        compare(nightLights.signalArguments[0][0], true)
        panel.temperatureRequested(3500)
        compare(temperatures.signalArguments[0][0], 3500)
    }

    function test_the_schedule_mode_and_hours_leave_as_one_document() {
        var panel = make(panelComponent)
        panel.schedule = Brightness.scheduleOf('{"mode":"off","start":"20:00","end":"07:00"}')
        schedules.target = panel
        schedules.clear()
        panel.chooseMode("fixed")
        compare(JSON.parse(schedules.signalArguments[0][0]).mode, "fixed")
        panel.changeTime("start", "21:30")
        compare(JSON.parse(schedules.signalArguments[1][0]).start, "21:30")
        panel.changeTime("start", "nope")
        compare(schedules.count, 2)
    }

    function test_the_schedule_round_trips_through_the_preference() {
        compare(Brightness.scheduleOf("").mode, "off")
        compare(Brightness.scheduleOf("not json").mode, "off")
        compare(Brightness.scheduleOf('{"mode":"sun"}').start, "20:00")
        compare(Brightness.withMode(Brightness.scheduleOf(""), "sun"), '{"mode":"sun","start":"20:00","end":"07:00"}')
        compare(Brightness.withTime(Brightness.scheduleOf(""), "end", "06:15"), '{"mode":"off","start":"20:00","end":"06:15"}')
    }

    function test_the_sun_times_are_read_from_the_snapshot() {
        var panel = make(panelComponent)
        panel.nightlight = {
            schedule: { mode: "sun", start: "20:00", end: "07:00", sunrise: "06:30", sunset: "19:45" },
            next: { at: "19:45", temperature: 3500, active: true }
        }
        compare(panel.sunText, "Sunset 19:45 · sunrise 06:30")
    }

    function test_the_panel_gear_asks_for_settings() {
        var panel = make(panelComponent)
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }
}
