import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/netusage"
import "../../bar/resources/resources.js" as Resources
import "../../bar/netusage/netusage.js" as Net

// The network usage element: the rate and total formatting, the up/down
// choice, today's totals across a day change, the button's states and the
// popup's graph and calm line. The readings come from the resources sampler,
// so every snapshot here is a plain object.
TestCase {
    id: testCase

    name: "NetUsage"
    when: windowShown
    visible: true
    width: 520
    height: 700

    readonly property var strings: ({
        "bar.widget.netusage": "Network usage",
        "bar.netusage.tooltip": "↓ %1  ↑ %2",
        "bar.netusage.today": "Today: %1 received · %2 sent",
        "bar.netusage.unreadable": "Cannot read the network's counters.",
        "bar.netusage.none": "No network interface is reporting traffic.",
        "bar.netusage.now": "Now",
        "bar.netusage.today.rx": "Received today",
        "bar.netusage.today.tx": "Sent today"
    })

    function snap(rx, tx, todayRx, todayTx, date) {
        return {
            cpu: 12, memory: { used: 1, total: 2, percent: 50 },
            temperature: 45, disk: { used: 1, total: 2, free: 1, percent: 50 },
            network: { rx: 1, tx: 1 },
            rate: rx === null ? null : { rx: rx, tx: tx },
            today: {
                date: date === undefined ? Net.dayKey() : date,
                rx: todayRx === undefined ? 0 : todayRx,
                tx: todayTx === undefined ? 0 : todayTx
            }
        }
    }

    function find(item, name) {
        if (item.objectName === name)
            return item
        for (var i = 0; i < item.children.length; i++) {
            var found = find(item.children[i], name)
            if (found)
                return found
        }
        return null
    }

    Component {
        id: buttonComponent

        NetUsageButton {
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        NetUsagePanel {
            width: 380
            strings: testCase.strings
        }
    }

    // ---- the formatting ----

    function test_rates_read_in_the_chosen_units() {
        compare(Net.speed(1500000, "decimal", "down"), "↓ 1.5 MB/s")
        compare(Net.speed(500000, "decimal", "up"), "↑ 500 kB/s")
        compare(Net.speed(1048576, "binary", "down"), "↓ 1.0 MiB/s")
        compare(Net.speed(0, "auto", "down"), "↓ 0 B/s")
        compare(Net.speed(null, "auto", "down"), "↓ --")
        compare(Net.rate(2000000, "decimal"), "2.0 MB/s")
        compare(Net.rate(null, "decimal"), "--")
    }

    function test_the_face_follows_the_bar_option() {
        compare(Net.face("both"), { down: true, up: true })
        compare(Net.face("down"), { down: true, up: false })
        compare(Net.face("up"), { down: false, up: true })
        compare(Net.face("nonsense"), Net.face("both"))
        compare(Net.face(undefined), Net.face("both"))
    }

    // ---- today ----

    function test_the_day_key_is_the_python_one() {
        compare(Net.dayKey(new Date(2026, 10, 22)), "2026-11-22")
        compare(Net.dayKey(new Date(2026, 0, 5)), "2026-01-05")
    }

    function test_today_counts_the_days_total() {
        compare(Net.today(snap(1, 1, 4700000000, 620000000, "2026-11-22"), "2026-11-22"),
                { rx: 4700000000, tx: 620000000 })
        compare(Net.todayText(snap(1, 1, 4700000000, 620000000, "2026-11-22"), "2026-11-22", "decimal"),
                { rx: "4.7 GB", tx: "620 MB" })
    }

    function test_today_starts_over_when_the_day_changes() {
        var yesterday = snap(1, 1, 4700000000, 620000000, "2026-11-22")
        compare(Net.today(yesterday, "2026-11-23"), { rx: 0, tx: 0 })
        compare(Net.todayText(yesterday, "2026-11-23", "decimal"), { rx: "0 B", tx: "0 B" })
        // The same snapshot before the change still reads its own day.
        compare(Net.today(yesterday, "2026-11-22").rx, 4700000000)
    }

    function test_today_never_reads_negative() {
        var broken = snap(1, 1, -4700000000, -5, "2026-11-22")
        compare(Net.today(broken, "2026-11-22"), { rx: 0, tx: 0 })
    }

    function test_today_line_names_both_totals() {
        var data = snap(1, 1, 4700000000, 620000000)
        compare(Net.todayLine(data, Net.dayKey(), "decimal", function (key) {
            return testCase.strings[key] === undefined ? key : testCase.strings[key]
        }), "Today: 4.7 GB received · 620 MB sent")
    }

    // ---- the button ----

    function test_the_button_shows_both_directions() {
        var button = createTemporaryObject(buttonComponent, testCase,
                                           { snapshot: snap(1500000, 500000, 4700000000, 620000000), units: "decimal" })
        verify(button.active)
        tryVerify(function () { return find(button, "downText") !== null })
        verify(find(button, "downText").visible)
        verify(find(button, "upText").visible)
        compare(find(button, "downText").text, "↓ 1.5 MB/s")
        compare(find(button, "upText").text, "↑ 500 kB/s")
        compare(button.tooltip, "↓ 1.5 MB/s  ↑ 500 kB/s")
        compare(button.tooltipDetail, "Today: 4.7 GB received · 620 MB sent")
    }

    function test_down_only_hides_the_up_line() {
        var button = createTemporaryObject(buttonComponent, testCase,
                                           { snapshot: snap(1500000, 500000), barMode: "down" })
        tryVerify(function () { return find(button, "downText") !== null })
        verify(find(button, "downText").visible)
        verify(!find(button, "upText").visible)
    }

    function test_up_only_hides_the_down_line() {
        var button = createTemporaryObject(buttonComponent, testCase,
                                           { snapshot: snap(1500000, 500000), barMode: "up" })
        tryVerify(function () { return find(button, "upText") !== null })
        verify(!find(button, "downText").visible)
        verify(find(button, "upText").visible)
    }

    function test_follows_the_units_option() {
        var button = createTemporaryObject(buttonComponent, testCase,
                                           { snapshot: snap(1048576, 0), units: "binary" })
        tryVerify(function () { return find(button, "downText") !== null })
        compare(find(button, "downText").text, "↓ 1.0 MiB/s")
        button.units = "decimal"
        compare(find(button, "downText").text, "↓ 1.0 MB/s")
    }

    function test_the_first_tick_reads_dashes_not_zero() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(null, null) })
        tryVerify(function () { return find(button, "downText") !== null })
        compare(find(button, "downText").text, "↓ --")
        compare(find(button, "upText").text, "↑ --")
        verify(button.active)
    }

    function test_an_unreadable_snapshot_is_one_calm_line_and_stays_in_the_bar() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: { error: "unreadable" } })
        verify(button.active)
        compare(button.tooltip, "Network usage")
        compare(button.tooltipDetail, "Cannot read the network's counters.")
    }

    // ---- the popup ----

    function test_the_popup_draws_the_sampler_history_and_todays_totals() {
        var data = snap(1500000, 500000, 4700000000, 620000000, "2026-11-22")
        var history = { rx: [1000, 1500000], tx: [200, 500000] }
        var panel = createTemporaryObject(panelComponent, testCase,
                                          { snapshot: data, history: history, units: "decimal" })
        compare(find(panel, "downGraph").values, [1000, 1500000])
        compare(find(panel, "upGraph").values, [200, 500000])
        compare(find(panel, "downGraph").maximum, 2000000)
        compare(find(panel, "downRate").text, "↓ 1.5 MB/s")
        compare(find(panel, "upRate").text, "↑ 500 kB/s")
        compare(find(panel, "todayRx").text, "4.7 GB")
        compare(find(panel, "todayTx").text, "620 MB")
        verify(!find(panel, "unavailable").visible)
    }

    function test_the_graph_axis_comes_from_both_directions() {
        var history = { rx: [1000], tx: [5000000] }
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: snap(1, 1), history: history })
        compare(Resources.networkCeiling(history), 5000000)
        compare(find(panel, "downGraph").maximum, 5000000)
    }

    function test_a_snapshot_without_counters_is_one_calm_line() {
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: { error: "unreadable" } })
        verify(find(panel, "unavailable").visible)
        compare(find(panel, "unavailable").text, "No network interface is reporting traffic.")
    }
}
