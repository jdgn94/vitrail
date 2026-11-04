import QtQuick
import QtTest
import "../../shell/search.js" as Search

// The settings search index: every category and tab, folded (no accents, no
// case) and capped, so the header field never shows a wall of results.
TestCase {
    name: "Search"

    function test_cursor_goes_to_fonts_cursor() {
        var hits = Search.matches("cursor")
        verify(hits.length > 0)
        compare(hits[0].category, "fonts")
        compare(hits[0].tab, "cursor")
    }

    function test_wallpaper_goes_to_the_wallpaper_category() {
        var hits = Search.matches("wallpaper")
        verify(hits.length > 0)
        compare(hits[0].category, "wallpaper")
        compare(hits[0].tab, "")
    }

    function test_no_result_is_an_empty_list() {
        compare(Search.matches("snapshot"), [])
        compare(Search.matches("zzzz-nothing"), [])
        compare(Search.matches(""), [])
        compare(Search.matches("   "), [])
    }

    function test_case_and_accents_are_ignored() {
        compare(Search.matches("CURSOR"), Search.matches("cursor"))
        compare(Search.matches("Cúrsor"), Search.matches("cursor"))
        verify(Search.matches("cúrsor").length > 0)
    }

    function test_at_most_twelve_results() {
        var hits = Search.matches("a")
        verify(hits.length > 0)
        verify(hits.length <= 12)
    }

    function test_every_category_and_tab_is_indexed() {
        var expected = [
            ["appearance", ""], ["appearance", "theme"], ["appearance", "surface"],
            ["fonts", ""], ["fonts", "text"], ["fonts", "icons"], ["fonts", "cursor"],
            ["wallpaper", ""], ["colors", ""],
            ["design", ""], ["design", "shape"], ["design", "surface"], ["design", "share"],
            ["bar", ""], ["bar", "layout"], ["bar", "frame"], ["bar", "notifications"],
            ["bar", "osd"], ["bar", "capture"],
            ["windows", ""], ["windows", "border"], ["windows", "opacity"], ["windows", "layout"],
            ["monitors", ""],
            ["terminal", ""], ["terminal", "tabs"], ["terminal", "look"],
            ["launcher", ""], ["launcher", "general"], ["launcher", "web"],
            ["input", ""], ["input", "keyboard"], ["input", "mouse"],
            ["sound", ""], ["sound", "output"], ["sound", "input"],
            ["language", ""],
            ["datetime", ""], ["datetime", "zone"], ["datetime", "clock"],
            ["connection", ""], ["connection", "internet"], ["connection", "vpn"],
            ["connection", "bluetooth"],
            ["plugins", ""], ["plugins", "media"], ["plugins", "installed"]
        ]
        for (var i = 0; i < expected.length; i++) {
            var hit = Search.index.find(function (entry) {
                return entry.category === expected[i][0] && entry.tab === expected[i][1]
            })
            verify(hit !== undefined, expected[i][0] + "/" + expected[i][1])
        }
    }
}
