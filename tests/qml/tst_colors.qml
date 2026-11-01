import QtQuick
import QtTest
import "../../bar/clipboard/colors.js" as Colors

// The colour tab's rules: reading a hex, writing every format, and the last
// ten colours.
TestCase {
    name: "Colors"

    function test_a_hex_is_read_with_or_without_alpha() {
        var red = Colors.parse("#ff0000")
        compare(red.r, 255)
        compare(red.g, 0)
        compare(red.b, 0)
        compare(red.a, 255)
        compare(Colors.parse("#00ff0080").a, 128)
        compare(Colors.parse("#fff").r, 255)
        compare(Colors.parse("not a colour"), null)
        compare(Colors.parse(""), null)
    }

    function test_every_format_is_written() {
        var red = Colors.parse("#ff0000")
        compare(Colors.format(red, "hex"), "#FF0000")
        compare(Colors.format(red, "hex8"), "#FF0000FF")
        compare(Colors.format(red, "rgb"), "rgb(255, 0, 0)")
        compare(Colors.format(red, "rgba"), "rgba(255, 0, 0, 1)")
        compare(Colors.format(red, "hsl"), "hsl(0, 100%, 50%)")
        compare(Colors.format(red, "hsla"), "hsla(0, 100%, 50%, 1)")
    }

    function test_half_transparent_colours_keep_their_alpha() {
        var half = Colors.parse("#33669980")
        compare(Colors.format(half, "hex8"), "#33669980")
        compare(Colors.format(half, "rgba"), "rgba(51, 102, 153, 0.5)")
    }

    function test_any_hex_is_a_colour() {
        verify(Colors.isColor(" #FF0000 "))
        verify(Colors.isColor("#12345678"))
        verify(!Colors.isColor("hola"))
        verify(!Colors.isColor("#12345"))
    }

    function test_the_preference_is_read_as_a_clean_list() {
        compare(Colors.recentFrom('["#FF0000","nope","#00FF00"]'), ["#FF0000", "#00FF00"])
        compare(Colors.recentFrom(""), [])
        compare(Colors.recentFrom("garbage"), [])
        compare(Colors.recentFrom('{"a":1}'), [])
    }

    function test_the_last_colours_keep_ten_and_move_to_the_top() {
        var list = []
        for (var i = 0; i < 12; i++)
            list = Colors.addRecent(list, "#0000" + (10 + i))
        compare(list.length, 10)
        compare(list[0], "#000021")
        list = Colors.addRecent(list, "#000015")
        compare(list[0], "#000015")
        compare(list.length, 10)
    }
}
