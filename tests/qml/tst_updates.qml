import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/updates"
import "../../bar/updates/updates.js" as Updates
import "../../bar/launcher/commands.js" as Commands

// The updates element: the count and tooltip, what "only while active" hides,
// the diff rule behind the "new updates" notification, the popup's blocks and
// the argv its Update button hands to a terminal.
TestCase {
    id: testCase

    name: "Updates"
    when: windowShown
    visible: true
    width: 420
    height: 700

    readonly property var strings: ({
        "bar.widget.updates": "Updates",
        "bar.updates.tooltip.one": "%1 update",
        "bar.updates.tooltip": "%1 updates",
        "bar.updates.none": "No pending updates",
        "bar.updates.checked": "Checked at %1",
        "bar.updates.unavailable": "Update sources unavailable",
        "bar.updates.source.official": "Official repositories",
        "bar.updates.source.aur": "AUR",
        "bar.updates.source.flatpak": "Flatpak",
        "bar.updates.unreadable": "Cannot read the update sources.",
        "bar.updates.more": "and %1 more",
        "bar.updates.update": "Update"
    })

    function row(name, from, to) {
        return { name: name, from: from, to: to }
    }

    function make(official, aur, flatpak, errors) {
        var data = {
            official: official || [],
            aur: aur || [],
            flatpak: flatpak || [],
            errors: errors || {},
            checkedAt: 1763730000000,
            commands: {
                official: ["sudo", "pacman", "-Syu"],
                aur: ["paru", "-Sua"],
                flatpak: ["flatpak", "update", "-y"]
            }
        }
        data.total = data.official.length + data.aur.length + data.flatpak.length
        return data
    }

    Component {
        id: buttonComponent

        UpdatesButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        UpdatesPanel {
            width: 360
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: updates; signalName: "updateRequested" }
    SignalSpy { id: refreshes; signalName: "refreshRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function makeItem(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // Every descendant with that objectName (the one QML's TestCase gives is
    // findChild, not a list).
    function descendants(item, name, found) {
        var out = found || []
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.objectName === name)
                out.push(child)
            descendants(child, name, out)
        }
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_total_comes_from_the_snapshot_and_zero_is_not_ready() {
        compare(Updates.total(make([row("a", "1", "2")])), 1)
        compare(Updates.total(make()), 0)
        compare(Updates.total({ error: "unreadable" }), 0)
        compare(Updates.ready(make()), true)
        compare(Updates.ready({ error: "unreadable" }), false)
        compare(Updates.ready({}), false)
    }

    function test_only_the_sources_the_snapshot_carries_are_listed() {
        compare(Updates.sourcesOf(make([], [], [])), ["official", "aur", "flatpak"])
        compare(Updates.sourcesOf({ official: [], errors: {}, total: 0 }), ["official"])
        compare(Updates.sourcesOf({ error: "unreadable" }), [])
        compare(Updates.entries(make([row("a", "1", "2")]), "official").length, 1)
        compare(Updates.entries({}, "official"), [])
    }

    function test_a_failed_source_keeps_its_error_text() {
        var data = make([row("a", "1", "2")], [], [], { flatpak: "flatpak is not installed" })
        compare(Updates.errorOf(data, "flatpak"), "flatpak is not installed")
        compare(Updates.errorOf(data, "official"), "")
    }

    function test_a_version_row_reads_from_arrow_to_but_keeps_what_it_has() {
        compare(Updates.versions(row("a", "1.0", "1.1")), "1.0 → 1.1")
        compare(Updates.versions(row("a", "", "1.1")), "1.1")
        compare(Updates.versions(row("a", "", "")), "")
        compare(Updates.versions(null), "")
    }

    function test_the_popup_caps_a_source_and_names_the_rest() {
        var rows = []
        for (var i = 0; i < Updates.ROW_LIMIT + 2; i++)
            rows.push(row("p" + i, "1", "2"))
        compare(Updates.shown(rows).length, Updates.ROW_LIMIT)
        compare(Updates.hidden(rows), 2)
        compare(Updates.hidden([row("a", "1", "2")]), 0)
    }

    function test_the_first_snapshot_is_a_silent_baseline() {
        var first = make([row("a", "1", "2"), row("b", "1", "2")])
        compare(Updates.notice(null, first).count, 0)
        compare(Updates.notice({}, first).count, 0)
        compare(Updates.notice(first, { error: "unreadable" }).count, 0)
    }

    function test_a_growing_set_notifies_once_with_the_new_names() {
        var before = make([row("a", "1", "2")])
        var after = make([row("a", "1", "2"), row("b", "1", "2")])
        var found = Updates.notice(before, after)
        compare(found.count, 1)
        compare(found.names, ["b"])
        compare(Updates.notice(before, make([row("a", "1", "2"), row("b", "1", "3"), row("c", "1", "2")])).count, 2)
    }

    function test_the_same_total_never_notifies() {
        var before = make([row("a", "1", "2")])
        compare(Updates.notice(before, make([row("a", "1", "2")])).count, 0)
        // One package replaced by another: the set changed, the total did not.
        compare(Updates.notice(before, make([row("z", "1", "2")])).count, 0)
    }

    function test_a_source_that_starts_answering_counts_as_new() {
        var before = make([row("a", "1", "2")])
        var after = make([row("a", "1", "2"), row("b", "1", "2")])
        compare(Updates.notice(before, after).names, ["b"])
    }

    // --- the settings' plain values -----------------------------------------

    function test_the_check_interval_is_a_whole_number_of_minutes() {
        compare(Updates.intervalMinutes(60), 60)
        compare(Updates.intervalMinutes("30"), 30)
        compare(Updates.intervalMinutes(0), Updates.INTERVAL_MIN)
        compare(Updates.intervalMinutes(9999), Updates.INTERVAL_MAX)
        compare(Updates.intervalMinutes("soon"), Updates.INTERVAL_DEFAULT)
        compare(Updates.intervalMinutes(undefined), Updates.INTERVAL_DEFAULT)
        compare(Updates.intervalMs(60), 3600000)
    }

    function test_the_sources_preference_is_a_comma_list() {
        compare(Updates.enabledSources(undefined), ["official", "aur", "flatpak"])
        compare(Updates.enabledSources("flatpak, official"), ["official", "flatpak"])
        compare(Updates.enabledSources("snap"), [])
        compare(Updates.enabledSources(""), [])
        compare(Updates.withSource("official,aur,flatpak", "aur", false), "official,flatpak")
        compare(Updates.withSource("official", "flatpak", true), "official,flatpak")
        compare(Updates.withSource("official", "official", false), "")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_count_only_when_there_is_one() {
        var item = makeItem(buttonComponent)
        item.snapshot = make([row("a", "1", "2")], [row("b", "1", "2")], [row("c", "", "3")])
        compare(item.text, "3")
        compare(item.icon, "update")
        compare(item.active, true)
        compare(item.tooltip, "3 updates")
        compare(item.tooltipDetail, "Official repositories 1 · AUR 1 · Flatpak 1")

        item.snapshot = make([row("a", "1", "2")])
        compare(item.text, "1")
        compare(item.tooltip, "1 update")

        item.snapshot = make()
        compare(item.text, "")
        compare(item.active, false)
        compare(item.tooltip, "No pending updates")
    }

    function test_only_while_active_hides_it_at_zero() {
        var item = makeItem(buttonComponent)
        item.showMode = "active"
        item.snapshot = make()
        compare(item.shown, false)
        item.snapshot = make([row("a", "1", "2")])
        compare(item.shown, true)
        item.showMode = "always"
        item.snapshot = make()
        compare(item.shown, true)
    }

    function test_the_tooltip_detail_falls_back_to_the_error() {
        var item = makeItem(buttonComponent)
        item.snapshot = make([], [], [], { flatpak: "flatpak is not installed" })
        compare(item.tooltip, "No pending updates")
        compare(item.tooltipDetail, "flatpak is not installed")

        // A source failing beside updates that do exist does not hide them.
        item.snapshot = make([row("a", "1", "2")], [], [], { flatpak: "flatpak is not installed" })
        compare(item.tooltipDetail, "Official repositories 1")

        item.snapshot = { error: "unreadable" }
        compare(item.tooltip, "Updates")
        compare(item.tooltipDetail, "Update sources unavailable")
    }

    function test_a_quiet_snapshot_says_when_it_was_checked() {
        var item = makeItem(buttonComponent)
        item.snapshot = make()
        compare(item.tooltipDetail, "Checked at " + Qt.formatTime(new Date(item.snapshot.checkedAt), "HH:mm"))
    }

    // --- the popup -----------------------------------------------------------

    function test_the_panel_draws_one_block_per_source_and_caps_its_rows() {
        var rows = []
        for (var i = 0; i < Updates.ROW_LIMIT + 2; i++)
            rows.push(row("package-" + i, "1.0", "1.1"))
        var panel = makeItem(panelComponent)
        panel.snapshot = make(rows, [row("aur-pkg", "2", "3")], [])
        compare(descendants(panel, "sourceBlock").length, 3)
        compare(descendants(panel, "updateRow").length, Updates.ROW_LIMIT + 1)
        compare(findChild(panel, "more").visible, true)
        compare(findChild(panel, "more").text, "and 2 more")
    }

    function test_a_failed_source_shows_its_code_as_a_calm_line() {
        var panel = makeItem(panelComponent)
        panel.snapshot = make([row("a", "1", "2")], [], [], { flatpak: "flatpak is not installed" })
        var errors = descendants(panel, "sourceError").filter(function (item) { return item.visible })
        compare(errors.length, 1)
        compare(errors[0].text, "flatpak is not installed")
        // A failed source has no rows, so it offers no Update button there.
        var buttons = descendants(panel, "update").filter(function (item) { return item.visible })
        compare(buttons.length, 1)
    }

    function test_the_update_button_hands_the_snapshots_argv_to_the_shell() {
        var panel = makeItem(panelComponent)
        panel.snapshot = make([row("a", "1", "2")], [row("b", "1", "2")])
        updates.target = panel
        updates.clear()
        var buttons = descendants(panel, "update").filter(function (item) { return item.visible })
        compare(buttons.length, 2)
        buttons[0].clicked()
        compare(updates.count, 1)
        compare(updates.signalArguments[0][0], ["sudo", "pacman", "-Syu"])
    }

    function test_the_refresh_button_asks_for_a_new_snapshot() {
        var panel = makeItem(panelComponent)
        refreshes.target = panel
        refreshes.clear()
        var button = findChild(panel, "refresh")
        verify(button !== null)
        mouseClick(button, button.width / 2, button.height / 2)
        compare(refreshes.count, 1)
    }

    function test_the_panel_gear_asks_for_settings() {
        var panel = makeItem(panelComponent)
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }

    function test_an_unreadable_snapshot_says_so_and_draws_no_block() {
        var panel = makeItem(panelComponent)
        panel.snapshot = { error: "unreadable" }
        compare(findChild(panel, "unavailable").visible, true)
        compare(descendants(panel, "sourceBlock").length, 0)
    }

    function test_the_terminal_line_quotes_an_argv() {
        compare(Commands.runInTerminal("htop").join("|"), "kitty|--hold|sh|-c|htop")
        compare(Commands.runInTerminal(["sudo", "pacman", "-Syu"]).join("|"),
                "kitty|--hold|sh|-c|'sudo' 'pacman' '-Syu'")
    }
}
