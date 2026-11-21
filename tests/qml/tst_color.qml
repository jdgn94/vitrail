import QtQuick
import QtTest
import "../../kit/color.js" as Color

// The colour picker's maths: hex codes, hue / saturation / lightness and where
// they sit on the wheel. No window: the same functions the picker calls.
TestCase {
    name: "Color"

    function test_hex_colours_are_checked() {
        verify(Color.isHex("#a1B2c3"))
        verify(!Color.isHex("a1b2c3"))
        verify(!Color.isHex("#abc"))
        verify(!Color.isHex(undefined))
    }

    function test_typed_codes_are_normalized() {
        compare(Color.normalizeHex("A1B2C3"), "#a1b2c3")
        compare(Color.normalizeHex(" #A1B2C3 "), "#a1b2c3")
        compare(Color.normalizeHex("#abc"), "#aabbcc")
        compare(Color.normalizeHex("F0a"), "#ff00aa")
        compare(Color.normalizeHex("#ab"), "")
        compare(Color.normalizeHex("#abcd"), "")
        compare(Color.normalizeHex("nope12"), "")
        compare(Color.normalizeHex(""), "")
        compare(Color.normalizeHex(undefined), "")
    }

    function test_hsl_and_hex_convert_both_ways() {
        compare(Color.hslToHex(0, 1, 0.5), "#ff0000")
        compare(Color.hslToHex(120, 1, 0.5), "#00ff00")
        compare(Color.hslToHex(240, 1, 0.5), "#0000ff")
        compare(Color.hslToHex(0, 0, 1), "#ffffff")
        compare(Color.hslToHex(0, 0, 0), "#000000")
        var hsl = Color.hexToHsl("#2196f3")
        compare(Color.hslToHex(hsl.h, hsl.s, hsl.l), "#2196f3")
        compare(Color.hexToHsl("#808080").s, 0)
    }

    function test_every_colour_survives_the_round_trip() {
        for (var red = 0; red < 256; red += 15) {
            for (var green = 0; green < 256; green += 15) {
                for (var blue = 0; blue < 256; blue += 15) {
                    var hex = Color.hexOf(red / 255, green / 255, blue / 255)
                    var hsl = Color.hexToHsl(hex)
                    compare(Color.hslToHex(hsl.h, hsl.s, hsl.l), hex)
                }
            }
        }
    }

    // The wheel: hue is the angle from the right going clockwise on screen.
    function test_a_point_of_the_wheel_is_a_hue_and_a_saturation() {
        var right = Color.wheelAt(50, 0, 100)
        compare(right.h, 0)
        compare(right.s, 0.5)
        var below = Color.wheelAt(0, 100, 100)
        compare(below.h, 90)
        compare(below.s, 1)
        compare(Color.wheelAt(-100, 0, 100).h, 180)
        compare(Color.wheelAt(0, -100, 100).h, 270)
        compare(Color.wheelAt(0, 0, 100).s, 0)
    }

    function test_beyond_the_rim_is_the_rim() {
        compare(Color.wheelAt(300, 0, 100).s, 1)
        compare(Color.wheelAt(0, -250, 100).s, 1)
    }

    function test_a_hue_and_saturation_sit_where_they_are_found() {
        var point = Color.wheelPoint(90, 0.5, 100)
        fuzzyCompare(point.x, 0, 1e-9)
        fuzzyCompare(point.y, 50, 1e-9)
        for (var h = 0; h < 360; h += 30) {
            var at = Color.wheelPoint(h, 0.75, 80)
            var back = Color.wheelAt(at.x, at.y, 80)
            fuzzyCompare(back.h, h, 1e-6)
            fuzzyCompare(back.s, 0.75, 1e-9)
        }
    }

    function test_the_wheel_agrees_with_the_hue_it_paints() {
        // Right of the centre is red, a third of a turn clockwise is green.
        compare(Color.hslToHex(Color.wheelAt(100, 0, 100).h, 1, 0.5), "#ff0000")
        compare(Color.hslToHex(Color.wheelAt(-50, 86.60254, 100).h, 1, 0.5), "#00ff00")
    }
}
