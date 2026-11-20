import QtQuick
import QtTest
import "../../bar/clipboard"

// The hover card: what it shows for plain text, styled text and an image.
TestCase {
    name: "ClipboardPreview"

    Component {
        id: card

        ClipboardPreview {
            shown: true
        }
    }

    function test_nothing_to_show_is_hidden() {
        var item = createTemporaryObject(card, this, { preview: null })
        verify(item)
        compare(item.opacity, 0)
    }

    function test_plain_text_is_drawn_as_it_is() {
        var item = createTemporaryObject(card, this, { preview: { kind: "text", text: "a <b> c", html: "" } })
        compare(item.rich, false)
        compare(item.markup, "")
        verify(item.implicitHeight > 0)
    }

    function test_styled_text_is_reduced_for_qt_and_keeps_its_colour() {
        var html = '<span style="color: rgb(200, 0, 0); font-size: 90px; position: fixed">Hi</span>'
        var item = createTemporaryObject(card, this, { preview: { kind: "text", text: "Hi", html: html } })
        compare(item.rich, true)
        verify(item.markup.indexOf("color: #c80000") >= 0)
        verify(item.markup.indexOf("position") < 0)
        verify(item.markup.indexOf("font-size: 28px") >= 0)
        compare(item.paper, "light")
    }

    function test_text_without_a_colour_is_inked_against_its_page() {
        var html = '<p style="color: #101010">a</p><p>no colour</p>'
        var item = createTemporaryObject(card, this, { preview: { kind: "text", text: "a", html: html } })
        compare(item.paper, "light")
        verify(item.ink.hslLightness < item.lightPaper.hslLightness)
        compare(item.ink, item.darkPaper)
    }

    function test_an_image_entry_shows_its_file() {
        var item = createTemporaryObject(card, this, { preview: { kind: "image" }, image: "file:///tmp/x.png" })
        compare(item.isImage, true)
    }

    function test_the_card_never_grows_past_its_bound() {
        var long = new Array(400).join("line of text ")
        var item = createTemporaryObject(card, this, { preview: { kind: "text", text: long, html: "" } })
        verify(item.height <= item.look.height)
    }
}
