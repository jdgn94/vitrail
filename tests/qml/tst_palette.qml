import QtQuick
import QtTest
import "../../shell/palette.js" as Palette

// The settings window watches the generated palette file. A reload only
// repaints when the document really changed, so a repeated poll costs nothing
// and a half-written file never blanks the window.
TestCase {
    name: "PaletteWatch"

    function test_a_document_is_read_as_an_object() {
        compare(Palette.read('{"dark":{"primary":"#ff0000"}}'), { dark: { primary: "#ff0000" } })
    }

    function test_garbage_and_non_objects_are_ignored() {
        compare(Palette.read("not json"), null)
        compare(Palette.read(""), null)
        compare(Palette.read("[]"), null)
        compare(Palette.read("null"), null)
    }

    function test_same_ignores_key_order() {
        verify(Palette.same({ dark: { a: 1, b: 2 } }, { dark: { b: 2, a: 1 } }))
        verify(!Palette.same({ dark: { a: 1 } }, { dark: { a: 2 } }))
    }

    function test_only_a_real_change_asks_for_a_repaint() {
        var current = { dark: { primary: "#ff0000" } }
        verify(!Palette.changed(current, '{"dark":{"primary":"#ff0000"}}'))
        verify(Palette.changed(current, '{"dark":{"primary":"#00ff00"}}'))
        verify(!Palette.changed(current, "{"))
        verify(!Palette.changed(current, ""))
    }
}
