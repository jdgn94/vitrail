import QtQuick
import QtTest
import "../../shell/reorder.js" as Reorder

TestCase {
    name: "Reorder"

    function test_moving_forward_shifts_the_rest_back() {
        compare(Reorder.move(["a", "b", "c", "d"], 0, 2), ["b", "c", "a", "d"])
    }

    function test_moving_back_shifts_the_rest_forward() {
        compare(Reorder.move(["a", "b", "c", "d"], 3, 1), ["a", "d", "b", "c"])
    }

    function test_the_same_place_changes_nothing() {
        compare(Reorder.move(["a", "b", "c"], 1, 1), ["a", "b", "c"])
    }

    function test_the_input_is_not_changed() {
        var list = ["a", "b", "c"]
        Reorder.move(list, 0, 2)
        compare(list, ["a", "b", "c"])
    }

    function test_places_are_clamped() {
        compare(Reorder.move(["a", "b", "c"], 0, 9), ["b", "c", "a"])
        compare(Reorder.move(["a", "b", "c"], 2, -4), ["c", "a", "b"])
    }

    function test_a_missing_entry_changes_nothing() {
        compare(Reorder.move(["a", "b"], 5, 0), ["a", "b"])
        compare(Reorder.move([], 0, 0), [])
    }
}
