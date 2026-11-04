import QtQuick
import QtTest
import "../../shell/fontsview.js" as FontsView

// The Fonts page's lists: what is installed, sorted, and the stored value kept
// selectable even when the machine no longer has it.
TestCase {
    name: "FontsView"

    function test_options_become_key_label_rows() {
        compare(FontsView.options(["Roboto", "Inter"], "Roboto"),
                [{ key: "Inter", label: "Inter" }, { key: "Roboto", label: "Roboto" }])
    }

    function test_a_value_that_is_not_installed_is_still_listed_first() {
        compare(FontsView.options(["Inter"], "Roboto"),
                [{ key: "Roboto", label: "Roboto" }, { key: "Inter", label: "Inter" }])
    }

    function test_an_empty_list_keeps_the_current_value_selectable() {
        compare(FontsView.options([], "Roboto"), [{ key: "Roboto", label: "Roboto" }])
        compare(FontsView.options([], ""), [])
    }

    function test_duplicates_and_blanks_are_dropped() {
        compare(FontsView.options(["Inter", "Inter", ""], "Inter"),
                [{ key: "Inter", label: "Inter" }])
    }

    function test_a_family_named_like_an_object_member_is_still_listed() {
        compare(FontsView.options(["constructor"], ""),
                [{ key: "constructor", label: "constructor" }])
    }
}
