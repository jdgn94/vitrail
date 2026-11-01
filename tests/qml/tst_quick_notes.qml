import QtQuick
import QtTest
import "../../bar/notes/notes.js" as Notes

// How the quick-notes widget keeps its lines. The value is one JSON array on
// a single line, because the bar's preference reader is line based.
TestCase {
    name: "QuickNotes"

    function test_parse_reads_the_json_array() {
        compare(Notes.parse('["uno","dos"]'), ["uno", "dos"])
        compare(Notes.parse(""), [])
        compare(Notes.parse(undefined), [])
    }

    function test_parse_tolerates_a_broken_value() {
        compare(Notes.parse("garbage"), [])
        compare(Notes.parse('["uno", 3]'), ["uno"])
    }

    function test_a_new_note_goes_to_the_top() {
        compare(Notes.add("", "only"), '["only"]')
        compare(Notes.add('["one"]', "two"), '["two","one"]')
    }

    function test_a_note_is_trimmed_and_blank_is_ignored() {
        compare(Notes.add('["one"]', "  two  "), '["two","one"]')
        compare(Notes.add('["one"]', "   "), '["one"]')
    }

    function test_the_same_note_moves_up_instead_of_repeating() {
        compare(Notes.add('["two","one"]', "one"), '["one","two"]')
    }

    function test_the_list_is_capped() {
        var text = ""
        for (var i = 0; i < Notes.LIMIT + 5; i++)
            text = Notes.add(text, "note " + i)
        compare(Notes.parse(text).length, Notes.LIMIT)
        compare(Notes.parse(text)[0], "note " + (Notes.LIMIT + 4))
    }

    function test_remove_drops_one_line() {
        compare(Notes.remove('["one","two","three"]', 1), '["one","three"]')
        compare(Notes.remove('["one"]', 5), '["one"]')
        compare(Notes.remove('["one"]', -1), '["one"]')
    }

    function test_shown_limits_what_the_widget_lists() {
        compare(Notes.shown('["a","b","c","d"]', 2), ["a", "b"])
        compare(Notes.shown("", 3), [])
    }
}
