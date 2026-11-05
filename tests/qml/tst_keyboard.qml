import QtQuick
import QtTest
import "../../bar/keyboard/keyboard.js" as Keyboard

// The keyboard chip, its switcher and the on-screen keyboard: the pure pieces
// that turn `hyprctl devices -j` and a key press into text and an argv.
TestCase {
    name: "Keyboard"

    readonly property string sample: '{"keyboards":['
        + '{"name":"usb-keyboard","layout":"latam,us","variant":",",'
        + '"options":"grp:alt_shift_toggle","active_layout_index":0,'
        + '"active_keymap":"Spanish (Latin American)","main":true},'
        + '{"name":"power-button","layout":"latam,us","variant":",",'
        + '"options":"grp:alt_shift_toggle","active_layout_index":0,'
        + '"active_keymap":"Spanish (Latin American)","main":false}]}'

    function test_the_switch_combination_is_humanised() {
        compare(Keyboard.humaniseSwitch("grp:alt_shift_toggle"), "Alt+Shift")
        compare(Keyboard.humaniseSwitch("grp:ctrl_shift_toggle"), "Ctrl+Shift")
        compare(Keyboard.humaniseSwitch("grp:super_space_toggle"), "Super+Space")
        compare(Keyboard.humaniseSwitch("grp:caps_toggle"), "Caps Lock")
        compare(Keyboard.humaniseSwitch(""), "")
    }

    function test_a_layout_has_a_readable_label_and_a_short_code() {
        compare(Keyboard.label("es"), "Español")
        compare(Keyboard.label("en"), "EN")
        compare(Keyboard.label("us"), "English (US)")
        compare(Keyboard.code("latam"), "LATAM")
        compare(Keyboard.code("us"), "US")
        compare(Keyboard.language("latam"), "es")
        compare(Keyboard.language("gb"), "en")
        compare(Keyboard.language("xx"), "en")
    }

    function test_the_devices_text_is_parsed_with_the_main_keyboard_first() {
        var devices = Keyboard.parse(sample)
        compare(devices.length, 2)
        compare(devices[0].name, "usb-keyboard")
        compare(devices[0].main, true)
        compare(Keyboard.parse("not json").length, 0)
    }

    function test_the_chip_shows_only_the_active_layout_abbreviation() {
        var devices = Keyboard.parse(sample)
        compare(Keyboard.chipText(devices), "LATAM")
        var switched = Keyboard.parse(sample.replace('"active_layout_index":0', '"active_layout_index":1'))
        compare(Keyboard.chipText(switched), "US")
        compare(Keyboard.activeCode(devices), "latam")
        verify(Keyboard.tooltip(devices).indexOf("LATAM US") >= 0)
    }

    function test_the_rows_list_each_layout_with_its_devices_and_switch() {
        var rows = Keyboard.layoutRows(Keyboard.parse(sample))
        compare(rows.length, 2)
        compare(rows[0].key, "latam")
        compare(rows[0].title, "Latinoamérica")
        compare(rows[0].active, true)
        verify(rows[0].subtitle.indexOf("usb-keyboard") >= 0)
        verify(rows[0].subtitle.indexOf("Alt+Shift") >= 0)
        verify(rows[1].subtitle.indexOf("Alt+Shift") >= 0)
    }

    function test_choosing_a_layout_keeps_every_layout_and_makes_it_first() {
        var order = Keyboard.orderFor(Keyboard.parse(sample), "us")
        compare(order.layout, "us,latam")
        compare(order.variant, ",")
        var argv = Keyboard.switchCommand(order.layout, order.variant)
        compare(argv[0], "hyprctl")
        verify(argv[2].indexOf('kb_layout="us,latam"') >= 0)
    }

    function test_the_on_screen_keyboard_has_rows_for_each_language() {
        var spanish = Keyboard.rows("es")
        compare(spanish.length, 3)
        verify(spanish[1].indexOf("ñ") >= 0)
        var english = Keyboard.rows("en")
        compare(english.length, 3)
        verify(english[1].indexOf("ñ") < 0)
        compare(Keyboard.rows("xx").join("|"), english.join("|"))
        verify(Keyboard.rows("de")[2].indexOf("y") >= 0)
        compare(Keyboard.digits().length, 10)
    }

    function test_a_key_press_becomes_the_right_wtype_argv() {
        compare(Keyboard.argv("a", false).join(" "), "wtype a")
        compare(Keyboard.argv("a", true).join(" "), "wtype A")
        compare(Keyboard.argv("backspace", false).join(" "), "wtype -k BackSpace")
        compare(Keyboard.argv("enter", false).join(" "), "wtype -k Return")
        compare(Keyboard.argv("tab", false).join(" "), "wtype -k Tab")
        compare(Keyboard.argv("shift", false), null)
        compare(Keyboard.argv(" ", false)[0], "wtype")
        compare(Keyboard.argv(" ", false)[1], " ")
    }
}
