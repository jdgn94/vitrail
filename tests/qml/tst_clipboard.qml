import QtQuick
import QtTest
import "../../bar/clipboard/clipboard.js" as Clipboard
import "../../bar/clipboard/rich.js" as Rich

// The clipboard panel's rules: what a preview is, what the search keeps and
// where the card sits next to the pointer.
TestCase {
    name: "Clipboard"

    function test_an_image_preview_names_its_size() {
        var image = Clipboard.imageOf("[[ binary data 120 KiB png 686x486 ]]")
        compare(image.format, "png")
        compare(image.width, 686)
        compare(image.height, 486)
        compare(Clipboard.imageOf("plain text"), null)
        compare(Clipboard.imageOf(""), null)
    }

    function test_every_entry_has_a_kind() {
        compare(Clipboard.kind({ preview: "[[ binary data 12 KiB png 80x60 ]]" }), "image")
        compare(Clipboard.kind({ preview: "https://example.com/x" }), "link")
        compare(Clipboard.kind({ preview: "http://example.com" }), "link")
        compare(Clipboard.kind({ preview: "comprar café" }), "text")
        compare(Clipboard.kind({ preview: "" }), "text")
    }

    function test_the_kind_filter_keeps_one_kind() {
        var entries = [
            { id: "1", preview: "hola" },
            { id: "2", preview: "https://example.com" },
            { id: "3", preview: "[[ binary data 12 KiB png 80x60 ]]" }
        ]
        compare(Clipboard.filter(entries, "", "link").length, 1)
        compare(Clipboard.filter(entries, "", "image")[0].id, "3")
        compare(Clipboard.filter(entries, "", "all").length, 3)
        compare(Clipboard.filter(entries, "example", "link").length, 1)
        compare(Clipboard.filter(entries, "example", "image").length, 0)
    }

    function test_repeated_copies_are_listed_once() {
        var entries = [
            { id: "3", preview: "hola" },
            { id: "2", preview: "adios" },
            { id: "1", preview: "hola" }
        ]
        var unique = Clipboard.unique(entries)
        compare(unique.length, 2)
        compare(unique[0].id, "3")
        compare(unique[1].id, "2")
    }

    function test_the_counts_feed_the_filters() {
        var counts = Clipboard.counts([
            { preview: "hola" },
            { preview: "https://example.com" },
            { preview: "[[ binary data 12 KiB png 80x60 ]]" }
        ])
        compare(counts.all, 3)
        compare(counts.text, 1)
        compare(counts.link, 1)
        compare(counts.image, 1)
    }

    function test_the_search_keeps_matching_entries() {
        var entries = [{ id: "1", preview: "Comprar café" }, { id: "2", preview: "https://example.com" }]
        compare(Clipboard.filter(entries, "CAFÉ").length, 1)
        compare(Clipboard.filter(entries, "  ").length, 2)
        compare(Clipboard.filter(entries, "nada").length, 0)
    }

    function test_a_label_is_one_line() {
        compare(Clipboard.label({ preview: "uno\ndos   tres" }), "uno dos tres")
        compare(Clipboard.label({ preview: "[[ binary data 12 KiB jpeg 800x600 ]]" }), "JPEG · 800×600")
    }

    function test_the_card_sits_at_the_pointer() {
        var place = Clipboard.clamp(100, 200, 380, 300, 2560, 1440, 12)
        compare(place.x, 100)
        compare(place.y, 200)
    }

    function test_the_card_never_leaves_the_screen() {
        var place = Clipboard.clamp(2500, 1400, 380, 300, 2560, 1440, 12)
        compare(place.x, 2560 - 380 - 12)
        compare(place.y, 1440 - 300 - 12)
    }

    function test_a_card_larger_than_the_screen_starts_at_the_margin() {
        var place = Clipboard.clamp(10, 10, 3000, 2000, 2560, 1440, 12)
        compare(place.x, 12)
        compare(place.y, 12)
    }

    function test_colours_become_hex_and_transparent_ones_disappear() {
        compare(Rich.color("rgb(255, 0, 128)"), "#ff0080")
        compare(Rich.color("rgba(0, 0, 255, 0.5)"), "#0000ff")
        compare(Rich.color("rgba(0, 0, 255, 0)"), "")
        compare(Rich.color("#abc"), "#aabbcc")
        compare(Rich.color("transparent"), "")
        compare(Rich.color("red"), "#ff0000")
    }

    function test_lengths_become_px() {
        compare(Rich.px("12pt", 16), 16)
        compare(Rich.px("2em", 16), 32)
        compare(Rich.px("150%", 20), 30)
        compare(Rich.px("large", 16), 18)
        compare(Rich.px("14px", 16), 14)
        compare(Rich.px("nonsense", 16), -1)
    }

    function test_a_style_keeps_only_what_text_can_draw() {
        var out = Rich.reduceStyle("color: rgb(255, 0, 0); font-family: Georgia, serif; font-size: 12pt; "
            + "font-weight: 700; font-style: oblique; letter-spacing: 0.1em; text-decoration: underline; "
            + "position: fixed; line-height: 1.5", 1, 40)
        compare(out, "color: #ff0000; font-family: Georgia, serif; font-size: 16px; font-weight: 700; "
            + "font-style: italic; letter-spacing: 1.6px; text-decoration: underline; line-height: 150%")
    }

    function test_sizes_are_capped_and_scaled() {
        compare(Rich.reduceStyle("font-size: 200px", 1, 40), "font-size: 40px")
        compare(Rich.reduceStyle("font-size: 40px", 0.5, 40), "font-size: 20px")
        compare(Rich.reduceStyle("font-size: 2px", 1, 40), "font-size: 6px")
    }

    function test_a_big_copy_is_scaled_to_fit_the_card() {
        var html = '<span style="font-size: 96px">Big</span> <span style="font-size: 48px">half</span>'
        compare(Rich.largest(html), 96)
        var out = Rich.fit(html, 32)
        verify(out.indexOf("font-size: 32px") >= 0)
        verify(out.indexOf("font-size: 16px") >= 0)
        compare(Rich.fit('<b style="font-size: 12px">x</b>', 32), '<b style="font-size: 12px">x</b>')
    }

    function test_quotes_escaped_by_the_sanitizer_are_read_back() {
        compare(Rich.map('<p style="font-family: &#x27;DejaVu Sans Mono&#x27;,monospace">t</p>', 1, 40),
                "<p style=\"font-family: 'DejaVu Sans Mono',monospace\">t</p>")
    }

    function test_a_style_with_nothing_drawable_is_removed() {
        compare(Rich.map('<p style="position: fixed">t</p>', 1, 40), "<p>t</p>")
    }

    function test_text_colours_pick_the_page_they_were_written_for() {
        compare(Rich.backdrop('<span style="color: rgb(0, 0, 0)">a</span>'), "light")
        compare(Rich.backdrop('<span style="color: #ffffff">a</span>'), "dark")
        compare(Rich.backdrop('<span style="color: #808080">a</span>'), "")
        compare(Rich.backdrop("<b>none</b>"), "")
        compare(Rich.backdrop('<span style="background-color: #000000">a</span>'), "")
    }
}
