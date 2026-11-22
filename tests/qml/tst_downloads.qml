import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/downloads"
import "../../bar/downloads/downloads.js" as Downloads

// The downloads element: the weighted aggregate percentage (only when every
// total is known), the indeterminate face for two unknown totals, the active
// rule, the preference's recent cap, the popup's running and recent rows and
// the clicks it hands to the shell.
TestCase {
    id: testCase

    name: "Downloads"
    when: windowShown
    visible: true
    width: 460
    height: 760

    readonly property var strings: ({
        "bar.widget.downloads": "Downloads",
        "bar.downloads.none": "No downloads",
        "bar.downloads.unavailable": "Cannot read the downloads folder.",
        "bar.downloads.unreadable": "Cannot read the downloads folder.",
        "bar.downloads.tooltip.one": "1 download · %1/s",
        "bar.downloads.tooltip": "%1 downloads · %2/s",
        "bar.downloads.starting": "1 download",
        "bar.downloads.startingMany": "%1 downloads",
        "bar.downloads.measuring": "measuring",
        "bar.downloads.active": "Downloading",
        "bar.downloads.recent": "Recent",
        "bar.downloads.empty": "Nothing is downloading.",
        "bar.downloads.cancelling": "Cancelling…",
        "bar.downloads.recentOption": "Recent downloads kept",
        "downloads.body.of": "%1 of %2",
        "downloads.speed": "%1/s",
        "downloads.action.folder": "Open folder",
        "downloads.action.file": "Open file",
        "downloads.action.cancel": "Cancel"
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    function item(name, size, total, percent, speed, elapsed) {
        return {
            id: name,
            name: name,
            path: "/home/u/Downloads/" + name + ".part",
            final: "/home/u/Downloads/" + name,
            folder: "/home/u/Downloads",
            size: size,
            total: total === undefined ? null : total,
            percent: percent === undefined ? null : percent,
            speed: speed || 0,
            elapsed: elapsed || 0,
            app: "Firefox",
            state: "live",
            finalExists: false
        }
    }

    function recentItem(name, size) {
        return {
            id: name,
            name: name,
            path: "/home/u/Downloads/" + name,
            folder: "/home/u/Downloads",
            size: size,
            app: "Firefox",
            finishedAt: 1763730000,
            state: "done"
        }
    }

    function make(active, recent) {
        return { active: active || [], recent: recent || [], updated: 1763730000 }
    }

    Component {
        id: buttonComponent

        DownloadsButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        DownloadsPanel {
            width: 400
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    // createTemporaryObject's property map round-trips through QVariant, which
    // turns a short array into something Array.isArray rejects; the shell
    // assigns plain JS values by binding, so the tests assign them too.
    function build(component, props) {
        var item = createTemporaryObject(component, testCase)
        for (var key in props)
            item[key] = props[key]
        return item
    }

    function find(item, name) {
        var out = []
        function walk(node) {
            if (node.objectName === name)
                out.push(node)
            var kids = node.children || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i])
        }
        walk(item)
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_aggregate_is_weighted_and_needs_every_total() {
        compare(Downloads.aggregate(make([])), -1)
        compare(Downloads.aggregate(make([item("a", 25, 100, 25)])), 25)
        compare(Downloads.aggregate(make([item("a", 25, 100, 25),
                                          item("b", 300, 600, 50)])), 46)
        compare(Downloads.aggregate(make([item("a", 25, 100, 25),
                                          item("b", 300, null, null)])), -1)
        compare(Downloads.aggregate({ error: "unreadable" }), -1)
    }

    function test_an_unknown_or_impossible_percentage_is_not_ready() {
        compare(Downloads.ready(make([])), true)
        compare(Downloads.ready({ error: "unreadable" }), false)
        compare(Downloads.ready({ active: [] }), false)
        compare(Downloads.percentOf(item("a", 1, null, null)), -1)
        compare(Downloads.percentOf(item("a", 150, 100, 150)), 100)
        compare(Downloads.percentOf(item("a", 0, 100, 0)), 0)
        compare(Downloads.percentOf(null), -1)
    }

    function test_sizes_and_times_read_like_the_module() {
        compare(Downloads.humanSize(0), "0 B")
        compare(Downloads.humanSize(999), "999 B")
        compare(Downloads.humanSize(1500), "1.5 KB")
        compare(Downloads.humanSize(12400000), "12.4 MB")
        compare(Downloads.humanTime(0), "0:00")
        compare(Downloads.humanTime(7), "0:07")
        compare(Downloads.humanTime(83), "1:23")
        compare(Downloads.humanTime(3723), "1:02:03")
    }

    function test_recent_is_capped_by_the_preference() {
        var list = []
        for (var i = 0; i < 7; i++)
            list.push(recentItem("f" + i + ".iso", 1000))
        var snapshot = make([], list)
        compare(Downloads.recent(snapshot, 5).length, 5)
        compare(Downloads.recent(snapshot, 2).length, 2)
        compare(Downloads.recent(snapshot, 0).length, 0)
        compare(Downloads.recent(snapshot, 99).length, 7)
        compare(Downloads.cap(undefined), 5)
        compare(Downloads.cap(""), 5)
        compare(Downloads.cap("2"), 2)
        compare(Downloads.cap(-3), 0)
        compare(Downloads.cap(99), 20)
        compare(Downloads.cap("x"), 5)
    }

    function test_the_tooltip_names_the_count_and_the_speed() {
        compare(Downloads.title(make([]), t), "No downloads")
        compare(Downloads.title({ error: "unreadable" }, t), "Cannot read the downloads folder.")
        compare(Downloads.title(make([item("a", 1, null, null, 0)]), t), "1 download")
        compare(Downloads.title(make([item("a", 1, null, null, 1500)]), t), "1 download · 1.5 KB/s")
        compare(Downloads.title(make([item("a", 1, null, null, 1000),
                                      item("b", 1, null, null, 500)]), t), "2 downloads · 1.5 KB/s")
        compare(Downloads.detail(make([item("a", 1, null, null)])), "a")
        compare(Downloads.detail(make([])), "")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_aggregate_percentage_and_the_ring() {
        var button = build(buttonComponent, { snapshot: make([item("a", 40, 100, 40)]) })
        verify(button.active)
        verify(button.shown)
        compare(button.text, "40%")
        compare(button.percent, 40)
        compare(button.tooltip, "1 download")
        compare(button.tooltipDetail, "a")

        var track = find(button, "track")[0]
        var fill = find(button, "fill")[0]
        compare(Math.round(fill.width), Math.round(track.width * 0.4))
    }

    function test_two_downloads_of_unknown_total_show_no_percentage() {
        var button = build(buttonComponent, { snapshot: make([item("a", 900000, null, null, 220000),
                                                              item("b", 12000000, null, null, 480000)]) })
        verify(button.active)
        verify(button.indeterminate)
        compare(button.percent, -1)
        compare(button.text, "")
        compare(button.tooltip, "2 downloads · 700.0 KB/s")
        compare(button.tooltipDetail, "a")

        var track = find(button, "track")[0]
        var fill = find(button, "fill")[0]
        compare(Math.round(fill.width), Math.round(track.width * 0.25))
    }

    function test_idle_hides_the_element_in_active_mode() {
        var button = build(buttonComponent, { snapshot: make([]), showMode: "active" })
        verify(!button.active)
        verify(!button.shown)
        compare(button.text, "")
        compare(button.tooltip, "No downloads")
        compare(button.tooltipDetail, "")

        var always = build(buttonComponent, { snapshot: make([]), showMode: "always" })
        verify(always.shown)
        compare(find(always, "fill")[0].visible, false)
    }

    function test_an_unreadable_snapshot_is_inactive_but_says_why() {
        var button = build(buttonComponent, { snapshot: { error: "unreadable" } })
        verify(!button.active)
        verify(!button.ready)
        compare(button.tooltip, "Cannot read the downloads folder.")
    }

    // --- the panel -----------------------------------------------------------

    function test_the_panel_draws_a_row_per_running_and_recent_download() {
        var panel = build(panelComponent, {
            snapshot: make([item("big.iso", 4000000, 10000000, 40, 1250000, 6),
                            item("photo.jpg", 900000, null, null, 220000, 12)],
                           [recentItem("notes.pdf", 145000), recentItem("wallpaper.png", 6800000)])
        })
        var active = find(panel, "downloadRow")
        var recent = find(panel, "recentRow")
        compare(active.length, 2)
        compare(recent.length, 2)
        compare(find(panel, "percent")[0].text, "40%")
        verify(find(panel, "measuring")[1].visible)
        compare(find(panel, "recentSize")[0].text, "145.0 KB")
        verify(!find(active[0], "openFile")[0].enabled)
        verify(find(recent[0], "openFile")[0].enabled)
        verify(!find(panel, "empty")[0].visible)
    }

    function test_the_panel_keeps_only_the_recent_cap() {
        var list = []
        for (var i = 0; i < 7; i++)
            list.push(recentItem("f" + i + ".iso", 1000))
        var panel = build(panelComponent, { snapshot: make([], list), recentLimit: 2 })
        compare(find(panel, "recentRow").length, 2)
    }

    function test_open_folder_open_file_and_cancel_are_signals() {
        var panel = build(panelComponent, { snapshot: make([item("big.iso", 1, 2, 50)], []) })
        var folders = []
        var files = []
        var cancels = []
        panel.openFolderRequested.connect(function (path) { folders.push(path) })
        panel.openFileRequested.connect(function (path) { files.push(path) })
        panel.cancelRequested.connect(function (path) { cancels.push(path) })
        var row = find(panel, "downloadRow")[0]
        find(row, "openFolder")[0].clicked()
        find(row, "cancel")[0].clicked()
        compare(folders, ["/home/u/Downloads"])
        compare(cancels, ["/home/u/Downloads/big.iso.part"])
        compare(files, [])
    }

    function test_a_finished_row_opens_the_file_it_names() {
        var panel = build(panelComponent, { snapshot: make([], [recentItem("notes.pdf", 145000)]) })
        var files = []
        panel.openFileRequested.connect(function (path) { files.push(path) })
        find(panel, "recentRow")[0]
        find(panel, "openFile")[0].clicked()
        compare(files, ["/home/u/Downloads/notes.pdf"])
    }

    function test_nothing_gets_a_calm_line_not_an_empty_card() {
        var panel = build(panelComponent, { snapshot: make([]) })
        compare(find(panel, "downloadRow").length, 0)
        compare(find(panel, "recentRow").length, 0)
        verify(find(panel, "empty")[0].visible)
        verify(!find(panel, "unavailable")[0].visible)
    }

    function test_an_unreadable_snapshot_says_so() {
        var panel = build(panelComponent, { snapshot: { error: "unreadable" } })
        verify(find(panel, "unavailable")[0].visible)
        verify(!find(panel, "empty")[0].visible)
    }

    function test_the_gear_asks_for_settings() {
        var panel = build(panelComponent, { snapshot: make([]) })
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }
}
