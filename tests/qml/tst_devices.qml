import QtQuick
import QtTest
import "../../bar/devices/devices.js" as Devices

// The battery and Bluetooth chips' helpers: visibility follows the hardware,
// the numbers are whole, and a duration reads in the caller's language.
TestCase {
    name: "Devices"

    function test_a_machine_without_a_battery_shows_no_chip() {
        verify(!Devices.batteryShown(null))
        verify(!Devices.batteryShown(undefined))
        verify(!Devices.batteryShown({}))
        verify(!Devices.batteryShown({ isPresent: false, percentage: 80 }))
        verify(!Devices.batteryShown({ isPresent: true }))
        // The synthetic display device of a desktop: no battery, no state.
        verify(!Devices.batteryShown({ isPresent: true, percentage: 0, state: 0 }))
        verify(Devices.batteryShown({ isPresent: true, percentage: 0, state: 3 }))
        verify(Devices.batteryShown({ isPresent: true, percentage: 0, state: 2 }))
        verify(Devices.batteryShown({ isPresent: true, percentage: 80, state: 2 }))
    }

    function test_the_percentage_is_whole_and_clamped() {
        compare(Devices.batteryPercent(84.6), "85%")
        compare(Devices.batteryPercent(0), "0%")
        compare(Devices.batteryPercent(100), "100%")
        compare(Devices.batteryPercent(120), "100%")
        compare(Devices.batteryPercent(-3), "0%")
        compare(Devices.batteryPercent(null), "")
        compare(Devices.batteryPercent(undefined), "")
    }

    function test_the_state_comes_from_upower() {
        compare(Devices.batteryState(0), "unknown")
        compare(Devices.batteryState(1), "charging")
        compare(Devices.batteryState(2), "discharging")
        compare(Devices.batteryState(3), "empty")
        compare(Devices.batteryState(4), "full")
        compare(Devices.batteryState(5), "pending")
        compare(Devices.batteryState(99), "unknown")
    }

    function test_the_glyph_follows_the_charge() {
        compare(Devices.batteryGlyph({ state: 2, percentage: 0 }), "battery_0_bar")
        compare(Devices.batteryGlyph({ state: 2, percentage: 40 }), "battery_2_bar")
        compare(Devices.batteryGlyph({ state: 2, percentage: 96 }), "battery_full")
        compare(Devices.batteryGlyph({ state: 1, percentage: 80 }), "battery_charging_full")
        compare(Devices.batteryGlyph({ state: 5, percentage: 80 }), "battery_charging_full")
    }

    function test_time_parts_are_hours_and_minutes() {
        verify(Devices.timeParts(0) === null)
        verify(Devices.timeParts(-5) === null)
        verify(Devices.timeParts(null) === null)
        verify(Devices.timeParts(20) === null)
        var one = Devices.timeParts(3600)
        compare(one.hours, 1)
        compare(one.minutes, 0)
        var mixed = Devices.timeParts(4500)
        compare(mixed.hours, 1)
        compare(mixed.minutes, 15)
        var short = Devices.timeParts(900)
        compare(short.hours, 0)
        compare(short.minutes, 15)
    }

    function test_a_duration_reads_in_the_language() {
        var strings = { "battery.hours": "%1 h", "battery.minutes": "%1 min" }
        compare(Devices.durationText({ hours: 1, minutes: 15 }, strings), "1 h 15 min")
        compare(Devices.durationText({ hours: 2, minutes: 0 }, strings), "2 h")
        compare(Devices.durationText({ hours: 0, minutes: 20 }, strings), "20 min")
        compare(Devices.durationText(null, strings), "")
    }

    function test_bluetooth_needs_an_adapter() {
        verify(!Devices.bluetoothInfo(null).shown)
        verify(!Devices.bluetoothInfo({}).shown)
        verify(!Devices.bluetoothInfo({ available: false, powered: false }).shown)
        verify(Devices.bluetoothInfo({ available: true, powered: false }).shown)
    }

    function test_only_connected_devices_are_counted() {
        var info = Devices.bluetoothInfo({
            available: true,
            powered: true,
            devices: [
                { name: "Buds", paired: true, connected: true },
                { name: "Mouse", paired: true, connected: false },
                { name: "Phone", paired: true, connected: true }
            ]
        })
        compare(info.connected, 2)
        compare(info.badge, "2")
        compare(info.device.name, "Buds")
        compare(info.paired.length, 3)
    }

    function test_the_badge_never_reads_past_nine() {
        var devices = []
        for (var i = 0; i < 12; i++)
            devices.push({ connected: true })
        compare(Devices.bluetoothInfo({ available: true, powered: true, devices: devices }).badge, "9+")
        compare(Devices.bluetoothInfo({ available: true, powered: true, devices: [] }).badge, "")
    }
}
