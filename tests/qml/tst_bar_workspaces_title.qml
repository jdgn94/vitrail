import QtQuick
import QtTest
import "../../bar/workspaces"
import "../../bar/workspaces/workspaces.js" as Workspaces
import "../../bar/window"
import "../../kit"

// The bar's workspace pills and window title: the workspace mapping (existing,
// active, occupied), the app icon by window class, the title's elision and
// hiding, and the tooltip both elements read (bar/workspaces, bar/window).
TestCase {
    id: testCase

    name: "BarWorkspacesTitle"
    when: windowShown
    visible: true
    width: 800
    height: 600

    readonly property var words: ({
        "bar.widget.workspaces.help": "Click a workspace to switch to it",
        "bar.widget.workspaces.tooltip": "Workspace %1",
        "bar.widget.title.help": "The active window",
        "bar.widget.title.tooltip": "Active window"
    })

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure({
            surface: palette.surface,
            surfaceHigh: palette.surfaceHigh,
            foreground: palette.foreground,
            muted: palette.muted,
            primary: palette.primary,
            accentForeground: palette.accentForeground,
            info: palette.info,
            infoForeground: palette.infoForeground,
            error: palette.error,
            errorForeground: palette.errorForeground
        }, true, "glass", ({}))
    }

    function windowAt(address, klass, title) {
        return { address: address, title: title || klass, lastIpcObject: { class: klass } }
    }

    function workspace(id, focused, windows) {
        return { id: id, name: String(id), focused: focused === true, toplevels: windows || [] }
    }

    // --- the workspace mapping ------------------------------------------------

    function test_collect_lists_existing_workspaces_in_number_order() {
        var entries = Workspaces.collect([
            workspace(3, false, []),
            workspace(1, true, []),
            workspace(2, false, [windowAt("abc", "firefox", "Mozilla Firefox")])
        ], "abc")
        compare(entries.length, 3)
        compare(entries.map(function (entry) { return entry.id }), [1, 2, 3])
        compare(entries[0].active, true)
        compare(entries[0].occupied, false)
        compare(entries[1].occupied, true)
    }

    function test_only_the_focused_workspace_is_active() {
        var entries = Workspaces.collect([
            workspace(1, false, []),
            workspace(2, true, [])
        ], "")
        compare(entries[0].active, false)
        compare(entries[1].active, true)
    }

    function test_a_window_makes_a_workspace_occupied_even_without_a_model() {
        var entries = Workspaces.collect([{ id: 4, name: "4", focused: false, windows: 2 }], "")
        compare(entries[0].occupied, true)
        compare(entries[0].klass, "")
    }

    function test_special_workspaces_stay_out_of_the_pills() {
        var entries = Workspaces.collect([
            { id: -99, name: "special:scratch", focused: false, toplevels: [] }
        ], "")
        compare(entries.length, 0)
    }

    function test_the_active_window_names_its_workspace_and_the_last_one_otherwise() {
        var windows = [windowAt("a", "kitty", "Terminal"), windowAt("b", "firefox", "Mozilla Firefox")]
        var active = Workspaces.collect([workspace(5, true, windows)], "a")
        compare(active[0].klass, "kitty")
        compare(active[0].title, "Terminal")
        var resting = Workspaces.collect([workspace(5, false, windows)], "gone")
        compare(resting[0].klass, "firefox")
        compare(resting[0].title, "Mozilla Firefox")
    }

    // --- the app icon by class ------------------------------------------------

    function test_the_app_icon_comes_from_the_desktop_entry() {
        var entries = [
            { id: "firefox.desktop", name: "Firefox", startupClass: "Firefox", icon: "firefox" },
            { id: "kitty.desktop", name: "kitty", startupClass: "kitty", icon: "kitty" },
            { id: "org.example.Editor.desktop", name: "Editor", startupClass: "ExampleEditor", icon: "editor" }
        ]
        compare(Workspaces.iconFor(entries, "firefox"), "firefox")
        compare(Workspaces.iconFor(entries, "Firefox"), "firefox")
        compare(Workspaces.iconFor(entries, "ExampleEditor"), "editor")
        compare(Workspaces.iconFor(entries, "kitty"), "kitty")
    }

    function test_an_unknown_class_falls_back_to_its_own_icon_name() {
        compare(Workspaces.iconFor([], "SomeApp"), "someapp")
        compare(Workspaces.iconFor([], ""), "")
    }

    // --- the tooltips ---------------------------------------------------------

    function test_the_pill_tooltip_names_the_workspace_and_its_app() {
        var entry = { id: 2, label: "2", klass: "firefox", title: "Mozilla Firefox" }
        compare(Workspaces.tooltip(entry, words), "Workspace 2")
        compare(Workspaces.tooltipDetail(entry, words), "firefox · Mozilla Firefox")
        compare(Workspaces.tooltipDetail({ id: 3, label: "3", klass: "" }, words),
                "Click a workspace to switch to it")
    }

    Component {
        id: pillsComponent

        WorkspacePills {
            iconProvider: function (klass) { return "icon:" + klass }
        }
    }

    function test_the_pills_pass_the_workspace_and_app_to_the_pointer() {
        var entries = Workspaces.collect([
            workspace(1, false, [windowAt("a", "firefox", "Mozilla Firefox")]),
            workspace(2, true, [])
        ], "a")
        var pills = createTemporaryObject(pillsComponent, testCase, { workspaces: entries, strings: words })
        verify(pills !== null)
        wait(0)
        var first = findChild(pills, "workspacePill.1")
        var second = findChild(pills, "workspacePill.2")
        verify(first !== null)
        verify(second !== null)
        compare(first.tooltip, "Workspace 1")
        compare(first.tooltipDetail, "firefox · Mozilla Firefox")
        compare(first.occupied, true)
        compare(first.active, false)
        compare(second.active, true)
        compare(second.occupied, false)
        compare(second.tooltip, "Workspace 2")
    }

    // --- the title ------------------------------------------------------------

    Component {
        id: titleComponent

        WindowTitle {}
    }

    function test_the_title_elides_to_its_width_and_reads_in_full() {
        var long = "A window title long enough that the bar cannot show all of it"
        var title = createTemporaryObject(titleComponent, testCase, {
            title: long, appClass: "firefox", maxWidth: 80, strings: words
        })
        verify(title !== null)
        tryCompare(title, "truncated", true)
        verify(title.textWidth <= 80)
        verify(title.naturalWidth > title.textWidth)
        compare(title.tooltip, long)
        compare(title.tooltipDetail, "firefox")
    }

    function test_the_title_turns_to_read_along_a_vertical_bar() {
        var title = createTemporaryObject(titleComponent, testCase, {
            title: "A title long enough to run down the side of the screen", maxWidth: 80,
            vertical: true, strings: words
        })
        verify(title !== null)
        verify(title.implicitWidth < title.implicitHeight)
        verify(title.implicitHeight <= 80)
    }

    function test_the_title_leaves_without_text_fullscreen_or_the_layout() {
        var title = createTemporaryObject(titleComponent, testCase, {
            title: "Vitrail", appClass: "kitty", strings: words
        })
        verify(title !== null)
        verify(title.shown)
        title.title = ""
        verify(!title.shown)
        title.title = "Vitrail"
        title.fullscreen = true
        verify(!title.shown)
        title.fullscreen = false
        title.layoutVisible = false
        verify(!title.shown)
        compare(title.tooltip, "Vitrail")
        compare(title.tooltipDetail, "kitty")
    }
}
