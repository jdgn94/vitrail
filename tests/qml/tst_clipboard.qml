import QtQuick
import QtTest
import "../../bar/clipboard/clipboard.js" as Clipboard

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
}
