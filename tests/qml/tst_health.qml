import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/health"
import "../../bar/health/health.js" as Health

// The system health element: the worst severity, the count the button shows,
// when it is active, the severity-to-tone mapping, the bar's own load failures
// joined to the list, the words of a problem and what the popup offers.
TestCase {
    id: testCase

    name: "Health"
    when: windowShown
    visible: true
    width: 420
    height: 700

    readonly property var strings: ({
        "bar.widget.health": "System health",
        "bar.health.fine": "Everything is fine",
        "bar.health.fine.detail": "No problems found",
        "bar.health.unreadable": "Cannot read the health checks.",
        "bar.health.more": "and %1 more",
        "bar.health.fix": "Fix",
        "bar.health.logs": "Logs",
        "bar.health.disk.detail": "%1% free (%2 of %3)",
        "bar.health.title.service-user": "Service %1 failed",
        "bar.health.title.service-system": "System service %1 failed",
        "bar.health.title.disk": "Low disk space on %1",
        "bar.health.title.hyprland": "Hyprland config errors",
        "bar.health.title.doctor": "vitrail doctor found problems",
        "bar.health.title.bar": "A bar element failed to load",
        "bar.health.title.unknown": "Something is wrong"
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    function problem(id, severity, detail, fix, logs) {
        return { id: id, severity: severity, title: id, detail: detail || "", fix: fix || null, logs: logs || null }
    }

    function make(list) {
        return { problems: list, count: list.length, checkedAt: "2026-11-22T10:00:00Z", error: null }
    }

    readonly property var unit: problem("service-user:a.service", "warning", "user service failed: Alpha",
                                        ["systemctl", "--user", "restart", "a.service"],
                                        ["journalctl", "--user", "-u", "a.service"])
    readonly property var disk: problem("disk:/", "warning", "3.1% free (12.0 GB of 400.0 GB)")
    readonly property var system: problem("service-system:b.service", "error", "system service failed")

    Component {
        id: buttonComponent

        HealthButton {
            width: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        HealthPanel {
            width: 380
            strings: testCase.strings
        }
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

    function test_the_worst_severity_is_the_error_when_there_is_one() {
        compare(Health.worst([]), "")
        compare(Health.worst([unit, disk]), "warning")
        compare(Health.worst([unit, system, disk]), "error")
    }

    function test_the_tone_follows_the_severity() {
        compare(Health.tone("error"), "error")
        compare(Health.tone("warning"), "info")
        compare(Health.tone(""), "secondary")
    }

    function test_the_count_text_is_empty_for_one_problem() {
        compare(Health.countText(0), "")
        compare(Health.countText(1), "")
        compare(Health.countText(2), "2")
        compare(Health.countText(12), "12")
    }

    function test_active_means_something_is_wrong() {
        verify(!Health.active(0))
        verify(Health.active(1))
    }

    function test_the_bar_failures_join_the_list_as_an_error() {
        var list = Health.problems(make([disk]), ["volume", "updates"])
        compare(list.length, 2)
        compare(list[1].id, Health.BAR_ID)
        compare(list[1].severity, "error")
        compare(list[1].detail, "volume, updates")
        compare(Health.problems(make([disk]), []).length, 1)
        compare(Health.problems({ error: "unreadable" }, ["volume"]).length, 1)
        compare(Health.problems({ error: "unreadable" }, []).length, 0)
    }

    function test_a_problems_words_are_translated_from_its_id() {
        compare(Health.title(unit, t), "Service a.service failed")
        compare(Health.title(disk, t), "Low disk space on /")
        compare(Health.title(problem("hyprland:config", "warning"), t), "Hyprland config errors")
        compare(Health.title(problem("zzz:new", "warning"), t), "Something is wrong")
        compare(Health.detail(unit, t), "Alpha")
        compare(Health.detail(system, t), "")
    }

    function test_the_disk_detail_keeps_its_numbers() {
        var local = function (key) { return key === "bar.health.disk.detail" ? "%1% libre (%2 de %3)" : key }
        compare(Health.detail(disk, local), "3.1% libre (12.0 GB de 400.0 GB)")
    }

    function test_the_button_is_idle_on_a_clean_machine() {
        var button = build(buttonComponent, { snapshot: make([]), showMode: "active" })
        verify(!button.active)
        verify(!button.shown)
        compare(button.text, "")
        compare(button.tooltip, "Everything is fine")
    }

    function test_the_button_names_the_first_problem_and_counts_the_rest() {
        var button = build(buttonComponent, { snapshot: make([unit, disk, system]) })
        verify(button.active)
        compare(button.count, 3)
        compare(button.text, "3")
        compare(button.severity, "error")
        compare(button.tone, "error")
        compare(button.tooltip, "Service a.service failed")
        compare(button.tooltipDetail, "and 2 more")
    }

    function test_a_single_problem_shows_its_detail_and_no_number() {
        var button = build(buttonComponent, { snapshot: make([unit]) })
        compare(button.text, "")
        compare(button.tone, "info")
        compare(button.tooltipDetail, "Alpha")
    }

    function test_the_bar_failure_alone_makes_the_button_active() {
        var button = build(buttonComponent, { snapshot: { error: "unreadable" }, failed: ["volume"] })
        verify(button.active)
        compare(button.tone, "error")
        compare(button.tooltip, "A bar element failed to load")
    }

    function test_the_panel_has_a_row_per_problem_and_only_the_buttons_it_allows() {
        var panel = build(panelComponent, { snapshot: make([unit, disk]) })
        var rows = find(panel, "problemRow")
        compare(rows.length, 2)
        compare(find(rows[0], "fix").length, 1)
        verify(find(rows[0], "fix")[0].visible)
        verify(find(rows[0], "logs")[0].visible)
        verify(!find(rows[1], "fix")[0].visible)
        verify(!find(rows[1], "logs")[0].visible)
        verify(!find(panel, "fine")[0].visible)
    }

    function test_fix_and_logs_hand_their_argv_to_the_shell_and_run_nothing() {
        var panel = build(panelComponent, { snapshot: make([unit]) })
        var fixed = []
        var shown = []
        var real = false
        panel.fixRequested.connect(function (argv) { real = Array.isArray(argv); fixed.push(argv.join(" ")) })
        panel.logsRequested.connect(function (argv) { shown.push(argv.join(" ")) })
        var row = find(panel, "problemRow")[0]
        find(row, "fix")[0].clicked()
        find(row, "logs")[0].clicked()
        compare(fixed, ["systemctl --user restart a.service"])
        verify(real)
        compare(shown, ["journalctl --user -u a.service"])
    }

    function test_a_clean_machine_gets_a_calm_line_not_an_empty_card() {
        var panel = build(panelComponent, { snapshot: make([]) })
        compare(find(panel, "problemRow").length, 0)
        verify(find(panel, "fine")[0].visible)
        verify(!find(panel, "unavailable")[0].visible)
    }

    function test_an_unreadable_snapshot_says_so() {
        var panel = build(panelComponent, { snapshot: { error: "unreadable" } })
        verify(find(panel, "unavailable")[0].visible)
        verify(!find(panel, "fine")[0].visible)
    }

    function test_the_gear_asks_for_settings() {
        var panel = build(panelComponent, { snapshot: make([]) })
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }

    function test_an_argv_is_a_real_array_even_when_it_comes_from_a_model() {
        compare(Health.argv(["a", "b"]), ["a", "b"])
        compare(Health.argv(null), [])
        compare(Health.argv([]), [])
        compare(Health.argv("systemctl"), [])
        verify(Array.isArray(Health.argv(unit.fix)))
        verify(Health.hasArgv(unit.fix))
        verify(!Health.hasArgv(null))
    }

    function test_the_checks_preference_round_trips() {
        compare(Health.enabledChecks(undefined), ["services", "disk", "hyprland", "doctor"])
        compare(Health.enabledChecks("[]"), [])
        compare(Health.withCheck(undefined, "disk", false), '["services","hyprland","doctor"]')
        compare(Health.withCheck("[]", "doctor", true), '["doctor"]')
        compare(Health.enabledChecks("{broken"), ["services", "disk", "hyprland", "doctor"])
    }

    function test_the_threshold_is_clamped() {
        compare(Health.threshold(undefined), 5)
        compare(Health.threshold(""), 5)
        compare(Health.threshold(0), 1)
        compare(Health.threshold(99), 50)
        compare(Health.threshold(12), 12)
    }
}
