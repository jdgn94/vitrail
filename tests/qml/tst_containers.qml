import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/containers"
import "../../bar/containers/containers.js" as Containers

// The containers element: the running count and its "only while active" rule
// (no engine means the element is not shown), the pin order, the button each
// container state allows, and the popup's rows, actions, pin toggle and gear.
TestCase {
    id: testCase

    name: "Containers"
    when: windowShown
    visible: true
    width: 440
    height: 760

    readonly property var strings: ({
        "bar.widget.containers": "Containers",
        "bar.containers.tooltip": "%1 · %2 running",
        "bar.containers.tooltip.one": "%1 · 1 running",
        "bar.containers.down": "Down: %1",
        "bar.containers.unavailable": "Containers unavailable",
        "bar.containers.unreadable": "Cannot read the containers.",
        "bar.containers.noEngine": "No container engine: looked for docker and podman.",
        "bar.containers.error": "%1 could not list the containers: %2",
        "bar.containers.empty": "No containers.",
        "bar.containers.start": "Start",
        "bar.containers.stop": "Stop",
        "bar.containers.logs": "Logs",
        "bar.containers.pin": "Pin",
        "bar.containers.unpin": "Unpin",
        "bar.containers.state.running": "running",
        "bar.containers.state.exited": "exited",
        "bar.containers.state.created": "created",
        "bar.containers.state.paused": "paused",
        "bar.containers.state.restarting": "restarting",
        "bar.containers.state.dead": "dead",
        "bar.containers.health.healthy": "healthy",
        "bar.containers.health.unhealthy": "unhealthy",
        "bar.containers.health.starting": "starting"
    })

    function container(name, state, extra) {
        var base = {
            id: name + "-id",
            name: name,
            image: "example/" + name + ":latest",
            state: state,
            status: state === "running" ? "Up 2 hours" : "Exited (0) 1 hour ago",
            health: "",
            ports: ""
        }
        for (var key in extra)
            base[key] = extra[key]
        return base
    }

    function snapshot(list, engine, error) {
        var containers = list || []
        return {
            engine: engine === undefined ? "docker" : engine,
            running: containers.filter(function (one) { return one.state === "running" }).length,
            containers: containers,
            error: error === undefined ? null : error
        }
    }

    Component {
        id: buttonComponent

        ContainersButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        ContainersPanel {
            width: 400
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: actions; signalName: "actionRequested" }
    SignalSpy { id: pins; signalName: "pinRequested" }
    SignalSpy { id: settings; signalName: "settingsRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // Every descendant with that objectName.
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

    function visibleOnes(item, name) {
        return descendants(item, name).filter(function (one) { return one.visible })
    }

    // --- the plain logic -----------------------------------------------------

    function test_a_snapshot_is_ready_when_it_carries_a_container_list() {
        compare(Containers.ready(snapshot([])), true)
        compare(Containers.ready({}), false)
        compare(Containers.ready({ error: "unreadable" }), false)
        compare(Containers.ready(null), false)
        compare(Containers.engineOf(snapshot([], null)), "")
        compare(Containers.engineOf(snapshot([], "podman")), "podman")
    }

    function test_the_count_is_the_running_containers() {
        var data = snapshot([container("web", "running"), container("db", "exited"), container("job", "running")])
        compare(Containers.count(data), 2)
        compare(Containers.count(snapshot([], "docker")), 0)
        compare(Containers.count({}), 0)
    }

    function test_the_pin_list_is_names_and_keeps_its_order() {
        compare(Containers.parsePinned(""), [])
        compare(Containers.parsePinned("not json"), [])
        compare(Containers.parsePinned('{"name":"web"}'), [])
        compare(Containers.parsePinned('[" web ","web","db","",3]'), ["web", "db"])
        compare(Containers.withPinned("", "web", true), '["web"]')
        compare(Containers.withPinned('["web"]', "web", false), "[]")
        compare(Containers.withPinned('["web"]', "web", true), '["web"]')
        compare(Containers.withPinned('["web"]', "  ", true), '["web"]')
    }

    function test_pinned_containers_come_first_then_the_others() {
        var data = snapshot([container("web", "running"), container("db", "exited"), container("job", "running")])
        compare(Containers.ordered(data, "").map(function (one) { return one.name }), ["web", "db", "job"])
        compare(Containers.ordered(data, '["job","db"]').map(function (one) { return one.name }),
                ["job", "db", "web"])
        compare(Containers.ordered(data, '["gone"]').map(function (one) { return one.name }),
                ["web", "db", "job"])
    }

    function test_a_pinned_container_that_is_down_is_reported() {
        var data = snapshot([container("web", "running"), container("db", "exited")])
        compare(Containers.downPinned(data, ""), [])
        compare(Containers.downPinned(data, '["db"]'), ["db"])
        compare(Containers.downPinned(data, '["web"]'), [])
        // A pin is a name: after a rename the old name is still pinned and down.
        compare(Containers.downPinned(data, '["old-name"]'), ["old-name"])
    }

    function test_each_state_allows_its_own_buttons() {
        var running = container("web", "running")
        var stopped = container("db", "exited")
        compare(Containers.allowed(running, "start"), false)
        compare(Containers.allowed(running, "stop"), true)
        compare(Containers.allowed(running, "logs"), true)
        compare(Containers.allowed(stopped, "start"), true)
        compare(Containers.allowed(stopped, "stop"), false)
        compare(Containers.allowed(stopped, "logs"), true)
        compare(Containers.allowed(null, "logs"), false)
    }

    function test_the_command_names_the_engine_and_the_container() {
        compare(Containers.command("docker", "start", "a1"), ["docker", "start", "a1"])
        compare(Containers.command("podman", "stop", "p1"), ["podman", "stop", "p1"])
        compare(Containers.command("docker", "logs", "a1"), ["docker", "logs", "--tail", "200", "a1"])
        compare(Containers.command("", "start", "a1"), [])
        compare(Containers.command("docker", "remove", "a1"), [])
    }

    function test_the_engine_option_reaches_the_snapshot_arguments() {
        compare(Containers.engineArguments("auto"), [])
        compare(Containers.engineArguments(""), [])
        compare(Containers.engineArguments("docker"), ["--engine", "docker"])
        compare(Containers.engineArguments("podman"), ["--engine", "podman"])
        compare(Containers.engineArguments("other"), [])
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_running_count() {
        var button = make(buttonComponent)
        button.snapshot = snapshot([container("web", "running"), container("db", "exited"),
                                    container("job", "running")])
        compare(button.text, "2")
        compare(button.tooltip, "docker · 2 running")
        compare(button.tooltipDetail, "")
        button.snapshot = snapshot([container("web", "running")])
        compare(button.tooltip, "docker · 1 running")
        button.snapshot = snapshot([], "docker")
        compare(button.text, "0")
        button.snapshot = snapshot([], null)
        compare(button.text, "")
    }

    function test_the_button_is_active_only_with_an_engine() {
        var button = make(buttonComponent)
        button.showMode = "active"
        button.snapshot = snapshot([], null)
        compare(button.active, false)
        compare(button.shown, false)
        button.snapshot = snapshot([], "docker")
        compare(button.active, true)
        compare(button.shown, true)
    }

    function test_the_button_names_the_pinned_containers_that_are_down() {
        var button = make(buttonComponent)
        button.pinned = '["db","gone"]'
        button.snapshot = snapshot([container("web", "running"), container("db", "exited")])
        compare(button.tooltipDetail, "Down: db, gone")
        // The pin is a name: `gone` is still pinned and still down.
        button.snapshot = snapshot([container("web", "running"), container("db", "running")])
        compare(button.tooltipDetail, "Down: gone")
        button.pinned = '["db"]'
        compare(button.tooltipDetail, "")
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_draws_one_row_per_container_in_pin_order() {
        var panel = make(panelComponent)
        panel.pinned = '["db"]'
        panel.snapshot = snapshot([container("web", "running", { ports: "0.0.0.0:8080->80/tcp" }),
                                   container("db", "exited")])
        var rows = descendants(panel, "container")
        compare(rows.length, 2)
        compare(rows[0].container.name, "db")
        compare(rows[1].container.name, "web")
    }

    function test_each_row_offers_the_button_its_state_allows() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([container("web", "running"), container("db", "exited")])
        compare(visibleOnes(panel, "start").length, 1)
        compare(visibleOnes(panel, "stop").length, 1)
        compare(visibleOnes(panel, "logs").length, 2)
        compare(visibleOnes(panel, "pin").length, 2)
    }

    function test_a_row_announces_its_action_and_pin() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([container("db", "exited")])
        actions.target = panel
        pins.target = panel
        actions.clear()
        pins.clear()
        wait(50)
        var start = visibleOnes(panel, "start")[0]
        mouseClick(start, start.width / 2, start.height / 2)
        compare(actions.count, 1)
        compare(actions.signalArguments[0][0], "start")
        compare(actions.signalArguments[0][1], "db-id")
        var pin = visibleOnes(panel, "pin")[0]
        mouseClick(pin, pin.width / 2, pin.height / 2)
        compare(pins.count, 1)
        compare(pins.signalArguments[0][0], "db")
        compare(pins.signalArguments[0][1], true)
    }

    function test_no_engine_is_a_calm_line_and_no_rows() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([], null)
        compare(visibleOnes(panel, "container").length, 0)
        var line = findChild(panel, "noEngine")
        verify(line !== null)
        compare(line.visible, true)
        compare(line.text, "No container engine: looked for docker and podman.")
    }

    function test_an_engine_error_is_a_calm_line_with_the_reason() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([], "docker", "docker ps failed")
        compare(visibleOnes(panel, "container").length, 0)
        var line = findChild(panel, "engineError")
        verify(line !== null)
        compare(line.visible, true)
        verify(line.text.indexOf("docker ps failed") >= 0)
    }

    function test_the_popup_gear_asks_for_settings() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([container("web", "running")])
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        settings.target = panel
        settings.clear()
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(settings.count, 1)
    }
}
