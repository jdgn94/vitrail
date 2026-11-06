import QtQuick
import QtTest
import "../../bar/launcher/state.js" as State

// The launcher's clean start: every opening begins empty and on the default
// tab, whatever the previous one left behind.
TestCase {
    name: "LauncherState"

    function test_reopening_is_empty_and_on_the_default_tab() {
        var first = State.start("")
        first.text = "firefox"
        first.current = 4
        first.tab = "files"
        first.expanded = true
        first.menu = { item: {} }
        first.menuCurrent = 2
        first.fileQuery = "notes"
        first.fileItems = ["a"]
        first.wallpaperLoaded = true
        first.wallpaperFiles = ["b"]
        first.clips = ["c"]
        first.modeBefore = "files"
        first.selected = {}

        var again = State.start("")
        compare(again.text, "")
        compare(again.current, 0)
        compare(again.tab, "all")
        compare(again.expanded, false)
        compare(again.menu, null)
        compare(again.menuCurrent, 0)
        compare(again.fileQuery, "")
        compare(again.fileItems.length, 0)
        compare(again.wallpaperLoaded, false)
        compare(again.wallpaperFiles.length, 0)
        compare(again.clips.length, 0)
        compare(again.modeBefore, "")
        compare(again.selected, null)
    }

    function test_a_requested_mode_starts_with_its_prefix() {
        compare(State.start("files").text, "/")
        compare(State.start("calc").text, "=")
        compare(State.start("wallpaper").text, "wallpaper:")
    }

    function test_an_unknown_or_missing_mode_starts_empty() {
        compare(State.start("").text, "")
        compare(State.start("nonsense").text, "")
    }
}
