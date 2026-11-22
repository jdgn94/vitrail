import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/battery"
import "../../bar/battery/battery.js" as Battery

// The peripherals battery element: the lowest watched device, the kinds the
// user hides, the warning tone, the button's face and the popup's rows.
TestCase {
    id: testCase

    name: "PeripheralsBattery"
    when: windowShown
    visible: true
    width: 420
    height: 760

    readonly property var strings: ({
        "bar.widget.peripherals": "Peripherals battery",
        "bar.peripherals.unavailable": "Peripheral batteries unavailable",
        "bar.peripherals.unreadable": "Cannot read the peripheral batteries.",
        "bar.peripherals.empty": "No peripheral reports a battery.",
        "bar.peripherals.level": "%1 · %2%",
        "bar.peripherals.state.charging": "Charging",
        "bar.peripherals.state.discharging": "Discharging",
        "bar.peripherals.state.full": "Full",
        "bar.peripherals.state.unknown": "Unknown state",
        "bar.peripherals.timeLeft": "%1 left",
        "battery.hours": "%1 h",
        "battery.minutes": "%1 min"
    })

    function device(overrides) {
        var base = {
            path: "/org/freedesktop/UPower/devices/mouse_0",
            name: "Logitech G305",
            kind: "mouse",
            percentage: 55,
            state: "discharging",
            timeToEmpty: 270,
            model: "Logitech G305",
            serial: "46-f4-18-ad"
        }
        for (var key in overrides)
            base[key] = overrides[key]
        return base
    }

    function snapshot(devices) {
        return { devices: devices, lowest: null, error: null }
    }

    readonly property var mouse: device({})
    readonly property var headset: device({
        path: "/org/freedesktop/UPower/devices/headset_1",
        name: "WH-1000XM4",
        kind: "headphones",
        percentage: 30,
        state: "charging",
        timeToEmpty: null
    })
    readonly property var gamepad: device({
        path: "/org/freedesktop/UPower/devices/gamepad_2",
        name: "Xbox Wireless Controller",
        kind: "gamepad",
        percentage: 80,
        state: "discharging",
        timeToEmpty: 720
    })

    Component {
        id: buttonComponent

        BatteryPeripheralsButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        PeripheralsPanel {
            width: 400
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // Every descendant with that objectName.
    function descendants(item, name, found) {
        var out = found || []
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.objectName === name)
                out.push(child)
            descendants(child, name, out)
        }
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_a_snapshot_is_ready_when_it_carries_a_device_list() {
        compare(Battery.ready(snapshot([])), true)
        compare(Battery.ready({}), false)
        compare(Battery.ready({ error: "unreadable" }), false)
        compare(Battery.ready(null), false)
        compare(Battery.watchedDevices({ error: "unreadable" }, ""), [])
    }

    function test_the_lowest_discharging_device_wins_over_a_charging_one() {
        var found = Battery.lowest([headset, mouse, gamepad])
        compare(found.name, "Logitech G305")
        compare(found.percentage, 55)

        // The charging headset is lower, but it is filling: it only competes
        // when nothing discharges.
        compare(Battery.lowest([headset, gamepad]).name, "Xbox Wireless Controller")
        compare(Battery.lowest([headset, device({ name: "Mouse", state: "full", percentage: 100 })]).name,
                "WH-1000XM4")
    }

    function test_a_device_without_a_percentage_never_competes() {
        compare(Battery.lowest([]), null)
        compare(Battery.lowest([device({ percentage: null })]), null)
        compare(Battery.lowest([device({ percentage: null }), mouse]).name, "Logitech G305")
    }

    function test_hidden_kinds_are_left_out_of_the_watch_list() {
        var all = snapshot([mouse, headset, gamepad])
        compare(Battery.watchedDevices(all, "").length, 3)
        compare(Battery.watchedDevices(all, '["mouse"]').length, 2)
        compare(Battery.watchedDevices(all, '["mouse"]')[0].name, "WH-1000XM4")
        // The preference says "headset", the snapshot says "headphones".
        compare(Battery.watchedDevices(all, '["headset"]').length, 2)
        compare(Battery.watchedDevices(all, '["headset"]')[1].name, "Xbox Wireless Controller")
        compare(Battery.watchedDevices(all, "not json").length, 3)
        compare(Battery.watchedDevices(all, '["MOUSE","mouse",""]').length, 2)
    }

    function test_the_hide_preference_round_trips() {
        compare(Battery.parseHide(""), [])
        compare(Battery.parseHide('{"mouse":true}'), [])
        compare(Battery.parseHide('["MOUSE","headset","",3]'), ["mouse", "headphones"])
        compare(Battery.withKind("", "mouse", true), '["mouse"]')
        compare(Battery.withKind('["mouse"]', "mouse", false), "[]")
        compare(Battery.withKind('["mouse"]', "headset", true), '["mouse","headphones"]')
        compare(Battery.withKind('["mouse"]', "mouse", true), '["mouse"]')
    }

    function test_the_glyph_follows_the_level_and_the_warning_the_threshold() {
        compare(Battery.glyph(mouse), "battery_3_bar")
        compare(Battery.glyph(gamepad), "battery_5_bar")
        compare(Battery.glyph(device({ percentage: 100, state: "full" })), "battery_full")
        compare(Battery.glyph(headset), "battery_charging_full")
        compare(Battery.glyph(null), "battery_0_bar")
        compare(Battery.tone(device({ percentage: 19 }), 20), "error")
        compare(Battery.tone(device({ percentage: 20 }), 20), "secondary")
        compare(Battery.tone(device({ percentage: 10, state: "charging" }), 20), "primary")
        compare(Battery.tone(null, 20), "secondary")
    }

    function test_kinds_have_their_own_glyphs() {
        compare(Battery.kindGlyph("mouse"), "mouse")
        compare(Battery.kindGlyph("keyboard"), "keyboard")
        compare(Battery.kindGlyph("headphones"), "headphones")
        compare(Battery.kindGlyph("gamepad"), "sports_esports")
        compare(Battery.kindGlyph("other"), "devices")
    }

    function test_the_detail_names_the_other_devices_or_the_state() {
        compare(Battery.others([headset, mouse, gamepad], mouse),
                "WH-1000XM4 30% · Xbox Wireless Controller 80%")
        compare(Battery.detailText(headset, testCase.strings), "Charging")
        compare(Battery.detailText(mouse, testCase.strings), "Discharging · 4 h 30 min left")
        compare(Battery.detailText(device({ state: "full", timeToEmpty: null }), testCase.strings), "Full")
        compare(Battery.detailText(device({ state: "unknown", timeToEmpty: null }), testCase.strings),
                "Unknown state")
    }

    // --- the button ----------------------------------------------------------

    function test_the_bar_shows_the_lowest_watched_percentage() {
        var item = make(buttonComponent)
        compare(item.showMode, "active")
        compare(item.active, false)
        compare(item.shown, false)
        item.snapshot = snapshot([mouse, headset, gamepad])
        compare(item.active, true)
        compare(item.shown, true)
        compare(item.text, "55%")
        compare(item.icon, "battery_3_bar")
        compare(item.tooltip, "Logitech G305 · 55%")
        compare(item.tooltipDetail, "WH-1000XM4 30% · Xbox Wireless Controller 80%")
    }

    function test_a_hidden_kind_changes_the_lowest_and_can_empty_the_bar() {
        var item = make(buttonComponent)
        item.snapshot = snapshot([mouse, headset, gamepad])
        item.hide = '["mouse"]'
        compare(item.text, "80%")
        compare(item.tooltip, "Xbox Wireless Controller · 80%")
        item.hide = '["mouse","headset","gamepad"]'
        compare(item.active, false)
        compare(item.shown, false)
        item.hide = ""
        compare(item.active, true)
    }

    function test_the_tone_warns_below_the_threshold() {
        var item = make(buttonComponent)
        item.low = 20
        item.snapshot = snapshot([mouse])
        compare(item.tone, "secondary")
        item.snapshot = snapshot([device({ percentage: 12 })])
        compare(item.tone, "error")
        item.snapshot = snapshot([headset])
        compare(item.tone, "primary")
        item.low = 10
        item.snapshot = snapshot([device({ percentage: 12 })])
        compare(item.tone, "secondary")
    }

    function test_a_single_device_details_its_state() {
        var item = make(buttonComponent)
        item.snapshot = snapshot([mouse])
        compare(item.tooltipDetail, "Discharging")
    }

    function test_without_a_usable_snapshot_the_button_says_unavailable() {
        var item = make(buttonComponent)
        item.snapshot = { error: "unreadable" }
        compare(item.active, false)
        compare(item.tooltip, "Peripherals battery")
        compare(item.tooltipDetail, "Cannot read the peripheral batteries.")
        item.snapshot = snapshot([])
        compare(item.tooltip, "No peripheral reports a battery.")
        compare(item.tooltipDetail, "No peripheral reports a battery.")
    }

    function test_a_left_click_opens_the_popup() {
        var item = make(buttonComponent)
        var clicks = 0
        item.clicked.connect(function () { clicks++ })
        mouseClick(item, 20, 20, Qt.LeftButton)
        compare(clicks, 1)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_draws_one_row_per_watched_device() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([mouse, headset, gamepad])
        compare(descendants(panel, "peripheral").length, 3)
        compare(descendants(panel, "peripheralBar").length, 3)
        compare(descendants(panel, "peripheralState")[1].text, "Charging")
        compare(descendants(panel, "peripheralState")[0].text, "Discharging · 4 h 30 min left")
        panel.hide = '["mouse"]'
        compare(descendants(panel, "peripheral").length, 2)
    }

    function test_no_device_is_a_calm_line_not_an_empty_card() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([])
        compare(findChild(panel, "empty").visible, true)
        compare(descendants(panel, "peripheral").length, 0)
    }

    function test_an_unreadable_snapshot_says_so_instead_of_drawing_rows() {
        var panel = make(panelComponent)
        panel.snapshot = { error: "unreadable" }
        compare(findChild(panel, "unavailable").visible, true)
        compare(descendants(panel, "peripheral").length, 0)
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
