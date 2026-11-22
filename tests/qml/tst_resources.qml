import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/resources"
import "../../bar/resources/resources.js" as Resources

// The resources element: the face choice, the history ring, the unit
// formatting, the two-step kill, the button's states and the popup's calm
// lines for a metric that is missing.
TestCase {
    id: testCase

    name: "Resources"
    when: windowShown
    visible: true
    width: 520
    height: 900

    readonly property var strings: ({
        "bar.widget.resources": "Resources",
        "bar.resources.tooltip": "CPU %1 · RAM %2",
        "bar.resources.tooltip.temperature": "CPU %1 · RAM %2 · %3",
        "bar.resources.unreadable": "Cannot read the system's resources.",
        "bar.resources.disk.free": "%1 free of %2",
        "bar.resources.memory.used": "%1 of %2",
        "bar.resources.temperature.missing": "No temperature sensor was found on this machine.",
        "bar.resources.disk.missing": "The disk cannot be read.",
        "bar.resources.kill": "End",
        "bar.resources.kill.force": "Force quit",
        "bar.resources.kill.confirm": "Sure?",
        "bar.resources.kill.error.refused": "That process cannot be ended from here."
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    function snap(cpu, percent, rx, tx, temperature) {
        return {
            cpu: cpu, memory: { used: 4000000000, total: 16000000000, percent: percent },
            temperature: temperature === undefined ? 55 : temperature,
            disk: { used: 300, total: 1000, free: 700, percent: 30 },
            network: { rx: 1, tx: 1 }, rate: rx === null ? null : { rx: rx, tx: tx }, at: 1, top: []
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

    function findAll(item, name, into) {
        if (item.objectName === name)
            into.push(item)
        for (var i = 0; i < item.children.length; i++)
            findAll(item.children[i], name, into)
        return into
    }

    Component {
        id: buttonComponent

        ResourcesButton {
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        ResourcesPanel {
            width: 380
            strings: testCase.strings
        }
    }

    SignalSpy {
        id: killSpy

        signalName: "killRequested"
    }

    // ---- the face ----

    function test_the_face_follows_the_bar_option() {
        compare(Resources.face("both"), { bars: true, cpu: true, ram: true })
        compare(Resources.face("cpu"), { bars: true, cpu: true, ram: false })
        compare(Resources.face("ram"), { bars: true, cpu: false, ram: true })
        compare(Resources.face("numbers"), { bars: false, cpu: true, ram: true })
        compare(Resources.face("nonsense"), Resources.face("both"))
        compare(Resources.face(undefined), Resources.face("both"))
    }

    function test_the_interval_is_clamped_to_one_to_ten_seconds() {
        compare(Resources.interval(2), 2)
        compare(Resources.interval(0), 1)
        compare(Resources.interval(99), 10)
        compare(Resources.interval("abc"), 2)
        compare(Resources.interval(undefined), 2)
        compare(Resources.intervalMs(3), 3000)
    }

    // ---- the ring ----

    function test_the_history_ring_appends_and_stays_bounded() {
        var history = Resources.emptyHistory()
        for (var i = 0; i < 5; i++)
            history = Resources.push(history, snap(i * 10, 40, 100 * i, 10 * i), 3)
        compare(history.cpu, [20, 30, 40])
        compare(history.rx, [200, 300, 400])
        compare(history.tx.length, 3)
        compare(history.memory, [40, 40, 40])
        compare(history.disk[0], 70)
    }

    function test_the_ring_never_changes_the_history_it_was_given() {
        var before = Resources.emptyHistory()
        var after = Resources.push(before, snap(10, 40, 1, 1), 60)
        compare(before.cpu.length, 0)
        compare(after.cpu.length, 1)
    }

    function test_a_missing_reading_is_a_gap_not_a_zero() {
        var history = Resources.push(Resources.emptyHistory(), snap(null, 40, null, null, null), 60)
        compare(history.cpu, [null])
        compare(history.temperature, [null])
        compare(history.rx, [null])
        verify(!Resources.hasData(history, "temperature"))
        verify(Resources.hasData(history, "memory"))
    }

    function test_a_failed_snapshot_adds_nothing() {
        var history = Resources.push(Resources.emptyHistory(), snap(10, 40, 1, 1), 60)
        compare(Resources.push(history, { error: "unreadable" }, 60), history)
        compare(Resources.push(history, {}, 60), history)
    }

    function test_the_graph_axis_grows_in_round_steps() {
        compare(Resources.ceiling([null, 0], 1024), 1024)
        compare(Resources.ceiling([1500, 300], 1024), 2000)
        compare(Resources.ceiling([4200000], 1024), 5000000)
        compare(Resources.ceiling([9000000], 1024), 10000000)
    }

    // ---- the units ----

    function test_auto_counts_memory_in_binary_and_the_rest_in_decimal() {
        compare(Resources.bytes(1536, "auto", "memory"), "1.5 KiB")
        compare(Resources.bytes(1500, "auto", "disk"), "1.5 kB")
        compare(Resources.bytes(1500000, "auto", "network"), "1.5 MB")
    }

    function test_binary_and_decimal_are_forced_everywhere() {
        compare(Resources.bytes(1048576, "binary", "disk"), "1.0 MiB")
        compare(Resources.bytes(1000000, "decimal", "memory"), "1.0 MB")
        compare(Resources.bytes(512, "decimal", "memory"), "512 B")
        compare(Resources.bytes(25000000000, "decimal", "disk"), "25 GB")
    }

    function test_unreadable_numbers_read_as_absent() {
        compare(Resources.bytes(null, "auto", "memory"), "--")
        compare(Resources.bytes(-1, "auto", "memory"), "--")
        compare(Resources.percent(undefined), "--")
        compare(Resources.temperature(null), "--")
        compare(Resources.rate(null, "auto"), "--")
        compare(Resources.percent(42.6), "43%")
        compare(Resources.percent(140), "100%")
        compare(Resources.temperature(54.6), "55 °C")
        compare(Resources.rate(2000000, "decimal"), "2.0 MB/s")
    }

    function test_the_lines_use_the_translated_frames() {
        compare(Resources.diskFree({ total: 1000000000, free: 250000000 }, "decimal", t), "250 MB free of 1.0 GB")
        compare(Resources.diskFree({ total: 0, free: 0 }, "auto", t), "--")
        compare(Resources.memoryUsed({ used: 1048576, total: 2097152 }, "binary", t), "1.0 MiB of 2.0 MiB")
        compare(Resources.networkLine({ rate: { rx: 1500, tx: 500 } }, "decimal"), "↓ 1.5 kB/s  ↑ 500 B/s")
        compare(Resources.networkLine({ rate: null }, "decimal"), "--")
    }

    // ---- the kill steps ----

    function test_terminate_on_the_first_click_and_kill_only_after_a_confirmation() {
        var step = Resources.click("")
        compare(step, { stage: "sent", send: "term" })
        step = Resources.click(step.stage)
        compare(step, { stage: "confirm", send: "" })
        step = Resources.click(step.stage)
        compare(step, { stage: "done", send: "kill" })
        compare(Resources.click("done"), { stage: "done", send: "" })
    }

    function test_cancelling_the_confirmation_goes_back_without_a_signal() {
        compare(Resources.cancel("confirm"), "sent")
        compare(Resources.cancel("sent"), "sent")
    }

    function test_stages_of_vanished_processes_are_dropped() {
        var kept = Resources.prune({ "10": "sent", "11": "done" }, [{ pid: 11 }, { pid: 12 }])
        compare(kept, { "11": "done" })
    }

    // ---- the button ----

    function test_the_button_shows_two_bars_by_default() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(30, 50, 10, 10) })
        verify(button.active)
        tryVerify(function () { return find(button, "cpuBar") !== null })
        verify(find(button, "cpuBar").visible)
        verify(find(button, "ramBar").visible)
        verify(!find(button, "cpuNumber").visible)
        compare(find(button, "cpuBar").value, 0.3)
        compare(find(button, "ramBar").value, 0.5)
    }

    function test_cpu_only_hides_the_ram_bar() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(30, 50, 10, 10), barMode: "cpu" })
        tryVerify(function () { return find(button, "cpuBar") !== null })
        verify(find(button, "cpuBar").visible)
        verify(!find(button, "ramBar").visible)
    }

    function test_numbers_replace_the_bars() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(30, 50, 10, 10), barMode: "numbers" })
        tryVerify(function () { return find(button, "cpuNumber") !== null })
        verify(!find(button, "cpuBar").visible)
        verify(find(button, "cpuNumber").visible)
        compare(find(button, "cpuNumber").text, "30%")
        compare(find(button, "ramNumber").text, "50%")
    }

    function test_the_tooltip_carries_cpu_ram_and_temperature_then_disk_and_network() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(30, 50, 1500000, 500000), units: "decimal" })
        compare(button.tooltip, "CPU 30% · RAM 50% · 55 °C")
        compare(button.tooltipDetail, "700 B free of 1.0 kB · ↓ 1.5 MB/s  ↑ 500 kB/s")
    }

    function test_a_machine_without_a_thermal_zone_drops_the_temperature() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(30, 50, null, null, null) })
        compare(button.tooltip, "CPU 30% · RAM 50%")
        compare(button.tooltipDetail, "700 B free of 1.0 kB")
    }

    function test_the_first_tick_shows_an_empty_cpu_track_not_zero() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: snap(null, 50, null, null) })
        tryVerify(function () { return find(button, "cpuBar") !== null })
        compare(find(button, "cpuBar").value, -1)
        compare(button.cpuText, "--")
    }

    function test_an_unread_snapshot_says_so_and_stays_in_the_bar() {
        var button = createTemporaryObject(buttonComponent, testCase, { snapshot: { error: "unreadable" } })
        verify(button.active)
        compare(button.tooltip, "Resources")
        compare(button.tooltipDetail, "Cannot read the system's resources.")
    }

    // ---- the popup ----

    function test_the_popup_has_a_graph_per_metric_and_a_row_per_process() {
        var data = snap(30, 50, 100, 100)
        data.top = [{ pid: 10, name: "a", cpu: 5, memory: 1000, percent: 1 },
                    { pid: 11, name: "b", cpu: null, memory: 500, percent: 1 }]
        var history = Resources.push(Resources.emptyHistory(), data, 60)
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: data, history: history })
        compare(findAll(panel, "processRow", []).length, 2)
        verify(find(panel, "cpuGraph").hasData)
        verify(find(panel, "networkGraph").hasData)
        compare(find(panel, "cpuGraph").valueText, "30%")
    }

    function test_a_missing_metric_gets_one_calm_line() {
        var data = snap(30, 50, null, null, null)
        data.disk = { used: 0, total: 0, free: 0, percent: 0 }
        var history = Resources.push(Resources.emptyHistory(), data, 60)
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: data, history: history })
        var temperature = find(panel, "temperatureGraph")
        verify(!temperature.hasData)
        compare(find(temperature, "missing").text, "No temperature sensor was found on this machine.")
        verify(find(temperature, "missing").visible)
        verify(!find(temperature, "graph").visible)
        compare(find(find(panel, "diskGraph"), "missing").text, "The disk cannot be read.")
        verify(!find(find(panel, "cpuGraph"), "missing").visible)
    }

    function test_an_unread_snapshot_shows_one_line_instead_of_the_graphs() {
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: { error: "unreadable" } })
        verify(find(panel, "unavailable").visible)
        verify(!find(panel, "cpuGraph").visible)
    }

    function test_end_sends_terminate_then_force_quit_asks_before_it_kills() {
        var data = snap(30, 50, 1, 1)
        data.top = [{ pid: 10, name: "busy", cpu: 90, memory: 1000, percent: 1 }]
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: data })
        killSpy.target = panel
        killSpy.clear()
        var row = findAll(panel, "processRow", [])[0]
        var kill = find(row, "kill")
        compare(kill.text, "End")
        kill.clicked()
        compare(killSpy.count, 1)
        compare(killSpy.signalArguments[0][0], 10)
        compare(killSpy.signalArguments[0][1], false)
        tryCompare(kill, "text", "Force quit")
        kill.clicked()
        compare(killSpy.count, 1, "the confirmation sends nothing")
        tryCompare(kill, "text", "Sure?")
        kill.clicked()
        compare(killSpy.count, 2)
        compare(killSpy.signalArguments[1][0], 10)
        compare(killSpy.signalArguments[1][1], true)
    }

    function test_cancel_leaves_the_confirmation_without_a_signal() {
        var data = snap(30, 50, 1, 1)
        data.top = [{ pid: 10, name: "busy", cpu: 90, memory: 1000, percent: 1 }]
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: data })
        killSpy.target = panel
        killSpy.clear()
        var row = findAll(panel, "processRow", [])[0]
        find(row, "kill").clicked()
        find(row, "kill").clicked()
        tryVerify(function () { return find(row, "cancel").visible })
        find(row, "cancel").clicked()
        tryCompare(find(row, "kill"), "text", "Force quit")
        compare(killSpy.count, 1)
    }

    function test_a_refused_kill_is_said_in_words() {
        var panel = createTemporaryObject(panelComponent, testCase,
                                          { snapshot: snap(30, 50, 1, 1), killResult: { error: "refused", pid: 1 } })
        compare(find(panel, "killError").text, "That process cannot be ended from here.")
        verify(find(panel, "killError").visible)
    }

    function test_the_rows_survive_a_new_tick() {
        var first = snap(30, 50, 1, 1)
        first.top = [{ pid: 10, name: "busy", cpu: 90, memory: 1000, percent: 1 }]
        var panel = createTemporaryObject(panelComponent, testCase, { snapshot: first })
        var row = findAll(panel, "processRow", [])[0]
        var second = snap(31, 50, 1, 1)
        second.top = [{ pid: 10, name: "busy", cpu: 80, memory: 1000, percent: 1 }]
        panel.snapshot = second
        compare(findAll(panel, "processRow", [])[0], row)
        compare(find(row, "cpu").text, "80%")
    }
}
