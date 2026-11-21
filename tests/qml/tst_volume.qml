import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/volume"
import "../../bar/volume/volume.js" as Volume

// The volume element: the button's face and tooltip, the wheel arithmetic,
// the middle-click mute, the popup's rows and what it asks the shell to run.
TestCase {
    id: testCase

    name: "Volume"
    when: windowShown
    visible: true
    width: 400
    height: 600

    readonly property var strings: ({
        "bar.volume.unavailable": "Volume",
        "bar.volume.unavailableDetail": "No audio server",
        "bar.volume.level": "%1%",
        "bar.volume.mutedAt": "Muted (%1%)",
        "bar.volume.unreadable": "Cannot read the audio server",
        "bar.volume.noApps": "Nothing is playing"
    })

    function snapshot(volume, muted) {
        return {
            defaultSink: { id: 1, name: "speakers", description: "Speakers", volume: volume, muted: muted },
            defaultSource: { id: 3, name: "mic", description: "Microphone", volume: 100, muted: false },
            sinks: [{ id: 1, name: "speakers", description: "Speakers", volume: volume, muted: muted },
                    { id: 2, name: "headset", description: "Headset", volume: 10, muted: false }],
            sources: [{ id: 3, name: "mic", description: "Microphone", volume: 100, muted: false }],
            streams: [{ id: 10, serial: 110, app: "Firefox", name: "Video", icon: "", volume: 80, muted: false, corked: false, sink: 1 },
                      { id: 11, serial: 111, app: "Player", name: "Song", icon: "", volume: 35, muted: false, corked: true, sink: 1 }],
            error: null
        }
    }

    Component {
        id: buttonComponent

        VolumeButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        VolumePanel {
            width: 360
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: actions; signalName: "audioAction" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // --- the plain logic -----------------------------------------------------

    function test_the_step_is_a_whole_percent_from_one_to_twenty_five() {
        compare(Volume.step(5), 5)
        compare(Volume.step(0), 1)
        compare(Volume.step(99), 25)
        compare(Volume.step("7"), 7)
        compare(Volume.step(2.6), 3)
        compare(Volume.step("loud"), 5)
        compare(Volume.step(undefined), 5)
    }

    function test_a_notch_is_one_step_and_the_direction_is_the_sign() {
        compare(Volume.wheelChange(120, 5), 5)
        compare(Volume.wheelChange(-120, 5), -5)
        compare(Volume.wheelChange(240, 5), 10)
        compare(Volume.wheelChange(120, 99), 25)
        compare(Volume.wheelChange(0, 5), 0)
        compare(Volume.wheelChange(NaN, 5), 0)
    }

    function test_a_smooth_wheel_still_moves_at_least_one_percent() {
        compare(Volume.wheelChange(10, 5), 1)
        compare(Volume.wheelChange(-10, 5), -1)
    }

    function test_the_glyph_follows_the_level() {
        compare(Volume.icon(snapshot(80, false)), "volume_up")
        compare(Volume.icon(snapshot(50, false)), "volume_up")
        compare(Volume.icon(snapshot(30, false)), "volume_down")
        compare(Volume.icon(snapshot(0, false)), "volume_mute")
        compare(Volume.icon(snapshot(80, true)), "volume_off")
        compare(Volume.icon({ error: "unreadable" }), "volume_off")
        compare(Volume.icon({}), "volume_off")
    }

    function test_silent_streams_are_the_paused_ones() {
        var data = snapshot(50, false)
        compare(Volume.streams(data, false).length, 2)
        var shown = Volume.streams(data, true)
        compare(shown.length, 1)
        compare(shown[0].app, "Firefox")
        compare(Volume.streams({}, true), [])
    }

    function test_the_actions_are_the_audio_modules_arguments() {
        compare(Volume.stepArgs("sink", 5), ["volume", "sink", "+5"])
        compare(Volume.stepArgs("sink", -5), ["volume", "sink", "-5"])
        compare(Volume.volumeArgs(10, 42.4), ["volume", "10", "42"])
        compare(Volume.volumeArgs("sink", 140), ["volume", "sink", "100"])
        compare(Volume.volumeArgs("sink", -3), ["volume", "sink", "0"])
        compare(Volume.muteArgs("source"), ["mute", "source"])
        compare(Volume.defaultArgs(2), ["default", "2"])
        compare(Volume.moveArgs({ serial: 110 }, "headset"), ["move", "110", "headset"])
        compare(Volume.sinkName(snapshot(50, false), "2"), "headset")
        compare(Volume.sinkName(snapshot(50, false), "9"), "")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_device_and_its_level() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(64, false)
        compare(item.icon, "volume_up")
        compare(item.tooltip, "Speakers")
        compare(item.tooltipDetail, "64%")
        compare(item.text, "")
        compare(item.active, true)
    }

    function test_the_level_is_text_only_when_asked_and_not_while_muted() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(64, false)
        item.showPercent = true
        compare(item.text, "64%")
        item.snapshot = snapshot(64, true)
        compare(item.text, "")
        compare(item.icon, "volume_off")
        compare(item.tooltipDetail, "Muted (64%)")
    }

    function test_the_tooltip_follows_the_snapshot() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(10, false)
        compare(item.tooltipDetail, "10%")
        item.snapshot = snapshot(90, false)
        compare(item.tooltipDetail, "90%")
    }

    function test_without_an_audio_server_the_button_is_neutral() {
        var item = make(buttonComponent)
        item.showPercent = true
        for (var data of [{}, { error: "unreadable" }, { defaultSink: null, error: "pw-dump is missing" }]) {
            item.snapshot = data
            compare(item.ready, false)
            compare(item.icon, "volume_off")
            compare(item.tone, "secondary")
            compare(item.text, "")
            compare(item.tooltip, "Volume")
            compare(item.tooltipDetail, "No audio server")
        }
        actions.target = item
        actions.clear()
        mouseWheel(item, 20, 20, 0, 120)
        mouseClick(item, 20, 20, Qt.MiddleButton)
        compare(actions.count, 0)
    }

    function test_one_notch_is_one_step_call() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(50, false)
        item.step = 7
        actions.target = item
        actions.clear()
        mouseWheel(item, 20, 20, 0, 120)
        compare(actions.count, 1)
        compare(actions.signalArguments[0][0], ["volume", "sink", "+7"])
        mouseWheel(item, 20, 20, 0, -120)
        compare(actions.count, 2)
        compare(actions.signalArguments[1][0], ["volume", "sink", "-7"])
    }

    function test_a_middle_click_toggles_the_default_outputs_mute() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(50, false)
        actions.target = item
        actions.clear()
        mouseClick(item, 20, 20, Qt.MiddleButton)
        compare(actions.count, 1)
        compare(actions.signalArguments[0][0], ["mute", "sink"])
    }

    function test_a_left_click_opens_the_popup_not_an_action() {
        var item = make(buttonComponent)
        item.snapshot = snapshot(50, false)
        actions.target = item
        actions.clear()
        var clicks = 0
        item.clicked.connect(function () { clicks++ })
        mouseClick(item, 20, 20, Qt.LeftButton)
        compare(clicks, 1)
        compare(actions.count, 0)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_panel_lists_one_row_per_stream_and_hides_the_silent_ones() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot(50, false)
        compare(panel.streamIds, ["10", "11"])
        panel.hideSilent = true
        compare(panel.streamIds, ["10"])
        panel.hideSilent = false
        compare(panel.streamIds, ["10", "11"])
    }

    function test_a_poll_with_the_same_streams_keeps_the_rows() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot(50, false)
        var ids = panel.streamIds
        panel.snapshot = snapshot(51, false)
        verify(panel.streamIds === ids)
    }

    function test_the_panel_without_an_audio_server_draws_no_sliders() {
        var panel = make(panelComponent)
        panel.snapshot = { error: "unreadable" }
        compare(panel.ready, false)
        compare(findChild(panel, "unavailable").visible, true)
        compare(findChild(panel, "master").visible, false)
        compare(findChild(panel, "micRow").visible, false)
        compare(findChild(panel, "outputDevice").visible, false)
        compare(panel.streamIds, [])
        verify(findChild(panel, "popupSettings") !== null)
    }

    function test_the_panels_controls_leave_as_audio_actions() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot(50, false)
        actions.target = panel
        actions.clear()

        findChild(panel, "micMute").toggled(true)
        compare(actions.signalArguments[0][0], ["mute", "source"])

        findChild(panel, "outputDevice").selected("2")
        compare(actions.signalArguments[1][0], ["default", "2"])

        findChild(panel, "inputDevice").selected("3")
        compare(actions.signalArguments[2][0], ["default", "3"])

        var master = findChild(panel, "master")
        master.muteRequested()
        compare(actions.signalArguments[3][0], ["mute", "sink"])
        master.volumeRequested(33)
        compare(actions.signalArguments[4][0], ["volume", "sink", "33"])
    }

    function test_a_stream_row_changes_its_own_node_and_moves_by_the_sinks_name() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot(50, false)
        actions.target = panel
        actions.clear()
        var row = null
        for (var i = 0; i < panel.children.length && row === null; i++)
            row = findChild(panel.children[i], "stream")
        verify(row !== null)
        row.muteRequested()
        compare(actions.signalArguments[0][0], ["mute", "10"])
        row.volumeRequested(20)
        compare(actions.signalArguments[1][0], ["volume", "10", "20"])
        row.outputRequested("2")
        compare(actions.signalArguments[2][0], ["move", "110", "headset"])
    }

    function test_a_dragged_row_asks_at_most_once_per_throttle() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot(50, false)
        var master = findChild(panel, "master")
        var asked = []
        master.volumeRequested.connect(function (value) { asked.push(value) })
        master.request(10)
        master.request(11)
        master.request(12)
        compare(asked, [10])
        tryCompare(master, "pending", -1, 1000)
        compare(asked, [10, 12])
        compare(master.shown, 12)
    }

    function test_the_panel_gear_asks_for_settings() {
        var panel = make(panelComponent)
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }
}
