import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"
import "../../kit/composed"
import "../../kit/color.js" as Color

// The colour picker: the wheel gives a hue and a saturation, the tone slider the
// lightness, the hex field the code, and each one follows the others.
TestCase {
    id: testCase

    name: "VitrailColorPicker"
    when: windowShown
    visible: true
    width: 500
    height: 600

    VitrailPalette {
        id: palette
    }

    Component {
        id: picker

        VitrailColorPicker {
            width: 300
            size: "md"
        }
    }

    Component {
        id: wheel

        VitrailColorWheel {
            width: 200
            height: 200
        }
    }

    Component {
        id: tone

        VitrailToneSlider {
            width: 200
            height: 30
            hue: 200
            saturation: 0.6
        }
    }

    SignalSpy {
        id: edited

        signalName: "edited"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(props) {
        var item = createTemporaryObject(picker, testCase, props || ({}))
        verify(item !== null)
        return item
    }

    function parts(item) {
        var found = { wheel: null, tone: null, code: null }
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child instanceof VitrailColorWheel)
                found.wheel = child
            else if (child instanceof VitrailToneSlider)
                found.tone = child
            else if (child instanceof VitrailField)
                found.code = child
        }
        return found
    }

    // --- the picker ------------------------------------------------------

    function test_it_opens_on_the_colour_it_is_given() {
        var item = make({ color: "#2196f3" })
        var found = parts(item)
        compare(item.hex, "#2196f3")
        compare(found.code.text, "#2196f3")
        var hsl = Color.hexToHsl("#2196f3")
        fuzzyCompare(found.wheel.hue, hsl.h, 1e-6)
        fuzzyCompare(found.tone.tone, hsl.l, 1e-6)
        verify(item.valid)
    }

    function test_a_new_colour_from_outside_moves_everything() {
        var item = make({ color: "#2196f3" })
        item.color = "#4caf50"
        compare(item.hex, "#4caf50")
        compare(parts(item).code.text, "#4caf50")
    }

    function test_a_click_on_the_wheel_picks_a_hue_and_a_saturation() {
        var item = make({ color: "#808080" })
        var found = parts(item)
        edited.target = item
        edited.clear()
        var centre = found.wheel.mapToItem(testCase, found.wheel.width / 2, found.wheel.height / 2)
        // Half way to the rim, to the right: hue 0, saturation 0.5.
        mouseClick(testCase, centre.x + found.wheel.radius / 2, centre.y)
        compare(edited.count, 1)
        fuzzyCompare(item.hue, 0, 0.5)
        fuzzyCompare(item.saturation, 0.5, 0.02)
        // A grey is not exactly half as light: the wheel leaves the lightness alone.
        fuzzyCompare(item.lightness, 0.5, 0.01)
        compare(item.hex, Color.hslToHex(item.hue, item.saturation, item.lightness))
        compare(found.code.text, item.hex)
    }

    function test_below_the_centre_is_a_hue_of_ninety_degrees() {
        var item = make({ color: "#808080" })
        var found = parts(item)
        var centre = found.wheel.mapToItem(testCase, found.wheel.width / 2, found.wheel.height / 2)
        mouseClick(testCase, centre.x, centre.y + found.wheel.radius)
        fuzzyCompare(item.hue, 90, 0.5)
        fuzzyCompare(item.saturation, 1, 0.01)
    }

    function test_a_drag_beyond_the_rim_stays_on_the_rim() {
        var item = make({ color: "#808080" })
        var found = parts(item)
        var centre = found.wheel.mapToItem(testCase, found.wheel.width / 2, found.wheel.height / 2)
        mousePress(testCase, centre.x, centre.y)
        mouseMove(testCase, centre.x - found.wheel.radius * 3 / 4, centre.y)
        mouseMove(testCase, centre.x - found.wheel.radius * 2, centre.y)
        mouseRelease(testCase, centre.x - found.wheel.radius * 2, centre.y)
        fuzzyCompare(item.hue, 180, 0.5)
        compare(item.saturation, 1)
    }

    function test_the_marker_sits_where_the_colour_is() {
        var found = parts(make({ color: "#ff0000" }))
        // Pure red: the rim, to the right of the centre.
        compare(found.wheel.point.x, found.wheel.radius)
        fuzzyCompare(found.wheel.point.y, 0, 1e-6)
    }

    function test_a_grey_keeps_the_marker_in_the_centre() {
        var found = parts(make({ color: "#808080" }))
        compare(found.wheel.saturation, 0)
        compare(found.wheel.point.x, 0)
    }

    function test_a_typed_code_moves_the_wheel_and_the_slider() {
        var item = make({ color: "#ff0000" })
        var found = parts(item)
        edited.target = item
        edited.clear()
        found.code.text = "00ff00"
        compare(item.hex, "#00ff00")
        compare(found.wheel.hue, 120)
        compare(found.tone.tone, 0.5)
        compare(edited.count, 1)
        compare(edited.signalArguments[0][0], "#00ff00")
        // What was typed stays as it was typed.
        compare(found.code.text, "00ff00")
    }

    function test_a_short_code_is_a_colour() {
        var item = make({ color: "#ff0000" })
        parts(item).code.text = "#0f0"
        compare(item.hex, "#00ff00")
        verify(item.valid)
    }

    function test_a_code_that_is_not_a_colour_is_an_error_and_changes_nothing() {
        var item = make({ color: "#ff0000" })
        var found = parts(item)
        edited.target = item
        edited.clear()
        found.code.text = "#12"
        verify(!item.valid)
        verify(found.code.error)
        compare(item.hex, "#ff0000")
        compare(edited.count, 0)
        found.code.text = "#123456"
        verify(item.valid)
        verify(!found.code.error)
        compare(item.hex, "#123456")
    }

    function test_the_hue_survives_a_black_and_a_white() {
        var item = make({ color: "#2196f3" })
        var found = parts(item)
        var hue = item.hue
        found.tone.forceActiveFocus()
        for (var i = 0; i < 40; i++)
            keyClick(Qt.Key_Left)
        compare(item.hex, "#000000")
        compare(item.hue, hue)
        for (i = 0; i < 80; i++)
            keyClick(Qt.Key_Right)
        compare(item.hex, "#ffffff")
        compare(item.hue, hue)
    }

    // --- the tone slider -------------------------------------------------

    function test_the_arrows_step_the_tone() {
        var item = createTemporaryObject(tone, testCase)
        item.moved.connect(function (value) { item.tone = value })
        item.forceActiveFocus()
        keyClick(Qt.Key_Right)
        fuzzyCompare(item.tone, 0.5 + VitrailTokens.colorPicker.step, 1e-9)
        keyClick(Qt.Key_Left)
        keyClick(Qt.Key_Left)
        fuzzyCompare(item.tone, 0.5 - VitrailTokens.colorPicker.step, 1e-9)
    }

    function test_the_tone_stops_at_the_ends() {
        var item = createTemporaryObject(tone, testCase)
        item.moved.connect(function (value) { item.tone = value })
        item.tone = 1
        item.forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(item.tone, 1)
    }

    function test_a_click_on_the_track_picks_the_tone_under_it() {
        var item = createTemporaryObject(tone, testCase)
        item.moved.connect(function (value) { item.tone = value })
        mouseClick(item, item.markerSize / 2 + item.span * 0.25, item.height / 2)
        fuzzyCompare(item.tone, 0.25, 1e-6)
        mouseClick(item, 0, item.height / 2)
        compare(item.tone, 0)
        mouseClick(item, item.width - 1, item.height / 2)
        compare(item.tone, 1)
    }

    // --- the wheel on its own --------------------------------------------

    function test_the_wheel_reports_what_is_picked_and_the_owner_moves_it() {
        var item = createTemporaryObject(wheel, testCase)
        item.picked.connect(function (hue, saturation) {
            item.hue = hue
            item.saturation = saturation
        })
        var centre = { x: item.width / 2, y: item.height / 2 }
        mouseClick(item, centre.x, centre.y - item.radius / 2)
        fuzzyCompare(item.hue, 270, 0.5)
        fuzzyCompare(item.saturation, 0.5, 0.02)
    }
}
