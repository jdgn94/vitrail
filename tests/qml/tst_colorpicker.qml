import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/colorpicker"
import "../../bar/colorpicker/colorpicker.js" as ColorPicker

// The colour picker bar element: the bounded recent-colour list, the button's
// live tooltip, the swatch grid (hex and swatch), copying one and opening the
// palette.
TestCase {
    id: testCase

    name: "ColorPicker"
    when: windowShown
    visible: true
    width: 440
    height: 760

    readonly property var strings: ({
        "bar.widget.colorpicker": "Colour picker",
        "bar.colorpicker.none": "No recent colours",
        "bar.colorpicker.tooltip.one": "1 colour · %1",
        "bar.colorpicker.tooltip": "%1 colours · %2",
        "bar.colorpicker.oldest": "Oldest: %1",
        "bar.colorpicker.pickHint": "A click picks a colour from the screen.",
        "bar.colorpicker.empty": "No colours yet.",
        "bar.colorpicker.recent": "Recent colours",
        "bar.colorpicker.open": "Open palette",
        "bar.colorpicker.recentOption": "Colours shown",
        "bar.colorpicker.recentOption.help": "How many the popup lists (4–24)."
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    function colours(count) {
        var list = []
        for (var i = 0; i < count; i++) {
            var value = (0x100000 + i * 0x010101).toString(16).toUpperCase()
            list.push("#" + value)
        }
        return list
    }

    Component {
        id: buttonComponent

        ColorPickerButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        ColorPickerPanel {
            width: 380
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function build(component, props) {
        var item = createTemporaryObject(component, testCase)
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

    // --- the rules -----------------------------------------------------------

    function test_the_preference_is_bounded_to_twelve_by_default() {
        compare(ColorPicker.cap(undefined), 12)
        compare(ColorPicker.cap(""), 12)
        compare(ColorPicker.cap("not a number"), 12)
        compare(ColorPicker.cap(4), 4)
        compare(ColorPicker.cap(24), 24)
        compare(ColorPicker.cap(1), 4)
        compare(ColorPicker.cap(99), 24)
    }

    function test_the_recent_list_is_clean_and_capped() {
        var stored = JSON.stringify(["#FF0000", "nope", "#00FF00", "#0000FF", "#FFFF00"])
        compare(ColorPicker.recent(stored, 4), ["#FF0000", "#00FF00", "#0000FF", "#FFFF00"])
        compare(ColorPicker.recent(stored, 12), ["#FF0000", "#00FF00", "#0000FF", "#FFFF00"])
        compare(ColorPicker.recent(stored, 1), ["#FF0000", "#00FF00", "#0000FF", "#FFFF00"])
        compare(ColorPicker.recent("", 12), [])
        compare(ColorPicker.recent("garbage", 12), [])
    }

    function test_the_store_keeps_twenty_four_and_moves_to_the_top() {
        var list = ColorPicker.stored(JSON.stringify(colours(30)))
        compare(list.length, 24)
        list = ColorPicker.add(list, "#ABCDEF")
        compare(list[0], "#ABCDEF")
        compare(list.length, 24)
        list = ColorPicker.add(list, "#abcdef")
        compare(list[0], "#ABCDEF")
        compare(list.length, 24)
        compare(ColorPicker.add(list, "nope").length, 24)
    }

    function test_a_hex_is_written_in_capitals() {
        compare(ColorPicker.hex("#aabbcc"), "#AABBCC")
        compare(ColorPicker.hex("not a colour"), "")
        compare(ColorPicker.hex("abc"), "#AABBCC")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_is_an_eyedropper_with_the_recent_colours() {
        var button = build(buttonComponent, { colors: ["#FF0000", "#00FF00"] })
        verify(button.active)
        verify(button.shown)
        compare(button.icon, "colorize")
        compare(button.tooltip, "2 colours · #FF0000")
        compare(button.tooltipDetail, "Oldest: #00FF00")
    }

    function test_the_button_says_when_there_is_nothing_yet() {
        var button = build(buttonComponent, { colors: [] })
        verify(button.active)
        compare(button.tooltip, "No recent colours")
        compare(button.tooltipDetail, "A click picks a colour from the screen.")
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_shows_each_swatch_with_its_hex() {
        var panel = build(panelComponent, { colors: colorsFor(), limit: 4 })
        compare(find(panel, "colorSwatch").length, 4)
        compare(find(panel, "colorHex").length, 4)
        compare(find(panel, "colorHex")[0].text, "#FF0000")
        verify(!find(panel, "empty")[0].visible)

        var empty = build(panelComponent, { colors: [], limit: 12 })
        compare(find(empty, "colorSwatch").length, 0)
        verify(find(empty, "empty")[0].visible)
    }

    function test_a_click_copies_the_colour_and_the_button_opens_the_palette() {
        var panel = build(panelComponent, { colors: colorsFor(), limit: 4 })
        waitForRendering(panel)
        var copied = []
        var opened = 0
        panel.copyRequested.connect(function (hex) { copied.push(hex) })
        panel.paletteRequested.connect(function () { opened++ })
        var cells = find(panel, "colorSwatch")
        var target = null
        for (var i = 0; i < cells.length; i++) {
            if (find(cells[i], "colorHex")[0].text === "#00FF00")
                target = cells[i]
        }
        verify(target !== null)
        mouseClick(target, target.width / 2, target.height / 2)
        compare(copied, ["#00FF00"])
        find(panel, "openPalette")[0].clicked()
        compare(opened, 1)
    }

    function test_the_gear_opens_the_element_settings() {
        var panel = build(panelComponent, { colors: [], limit: 12 })
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }

    function colorsFor() {
        return ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF"]
    }
}
