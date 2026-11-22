import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/privacy"
import "../../bar/privacy/privacy.js" as Privacy

// The privacy element: which uses light the dot (only the watched kinds, only
// real uses), what the tooltip says, the colour token the dot resolves through
// the palette, and what the popup draws and asks for.
TestCase {
    id: testCase

    name: "Privacy"
    when: windowShown
    visible: true
    width: 420
    height: 700

    readonly property var strings: ({
        "bar.widget.privacy": "Privacy",
        "bar.privacy.kind.microphone": "Microphone",
        "bar.privacy.kind.camera": "Camera",
        "bar.privacy.kind.screen": "Screen sharing",
        "bar.privacy.using": "In use: %1",
        "bar.privacy.idle": "Privacy",
        "bar.privacy.idle.detail": "Nothing is using the microphone, camera or screen",
        "bar.privacy.apps.more": "%1 and %2 more",
        "bar.privacy.unavailable": "Cannot read PipeWire, so nothing can be reported.",
        "bar.privacy.inUse": "In use",
        "bar.privacy.cut": "Cut off"
    })

    function use(kind, app, node, label) {
        return { kind: kind, app: app, label: label === undefined ? "stream-" + node : label, node: node, since: null }
    }

    function make(list, error) {
        return { uses: list, anyUse: list.length > 0, watching: { microphone: true, camera: true, screen: true },
                 error: error || null }
    }

    readonly property var mic: use("microphone", "Firefox", 61)
    readonly property var mic2: use("microphone", "Discord", 62)
    readonly property var cam: use("camera", "Zoom", 70)
    readonly property var screen: use("screen", "OBS", 71)

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    Component {
        id: buttonComponent

        PrivacyButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        PrivacyPanel {
            width: 380
            strings: testCase.strings
        }
    }

    // See tst_health: assign plain JS values, as the shell's bindings do.
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

    function cleanup() {
        VitrailTokens.configure({}, true, "glass", {})
    }

    // --- the dot

    function test_with_nothing_in_use_there_is_no_dot_and_the_element_is_inactive() {
        var button = build(buttonComponent, { snapshot: make([]) })
        verify(!button.inUse)
        verify(!button.active)
        verify(!find(button, "dot")[0].visible)
        // The default mode leaves the bar entirely.
        compare(button.shown, false)
    }

    function test_the_default_mode_is_only_while_active_and_always_keeps_a_glyph() {
        var button = build(buttonComponent, { snapshot: make([]) })
        compare(button.showMode, "active")
        button.showMode = "always"
        verify(button.shown)
        verify(find(button, "idleIcon")[0].visible)
        verify(!find(button, "dot")[0].visible)
    }

    function test_any_watched_use_lights_the_dot() {
        var button = build(buttonComponent, { snapshot: make([mic]) })
        verify(button.inUse)
        verify(button.active)
        verify(button.shown)
        verify(find(button, "dot")[0].visible)
        verify(!find(button, "idleIcon")[0].visible)
    }

    function test_a_use_with_no_name_still_lights_the_dot() {
        var button = build(buttonComponent, { snapshot: make([use("camera", "", 9, "")]) })
        verify(button.inUse)
        compare(button.tooltipDetail, "9")
    }

    function test_an_unwatched_kind_never_lights_the_dot() {
        var snapshot = make([mic, cam])
        var button = build(buttonComponent, { snapshot: snapshot, watch: '["camera"]' })
        compare(button.uses.length, 1)
        compare(button.uses[0].kind, "camera")
        button.watch = '["screen"]'
        verify(!button.inUse)
        button.watch = "[]"
        verify(!button.inUse)
        verify(!find(button, "dot")[0].visible)
    }

    function test_the_watch_preference_parses_and_round_trips() {
        compare(Privacy.parseWatch(undefined), ["microphone", "camera", "screen"])
        compare(Privacy.parseWatch(""), ["microphone", "camera", "screen"])
        compare(Privacy.parseWatch("{broken"), ["microphone", "camera", "screen"])
        compare(Privacy.parseWatch("[]"), [])
        compare(Privacy.parseWatch('["screen","bogus"]'), ["screen"])
        compare(Privacy.withWatch(undefined, "camera", false), '["microphone","screen"]')
        compare(Privacy.withWatch("[]", "screen", true), '["screen"]')
        compare(Privacy.withWatch('["screen"]', "microphone", true), '["microphone","screen"]')
        compare(Privacy.watching('["screen"]', "camera"), false)
    }

    function test_a_preference_that_watches_nothing_is_never_asked_as_all() {
        compare(Privacy.watchArguments(undefined), [])
        compare(Privacy.watchArguments('["camera"]'), ["camera"])
        compare(Privacy.watchArguments('["microphone","camera","screen"]'), [])
        // "No argument" means all to the module; the element filters it out.
        compare(Privacy.watchArguments("[]"), [])
        compare(Privacy.uses(make([mic]), "[]").length, 0)
    }

    function test_an_unreadable_snapshot_is_no_dot() {
        var button = build(buttonComponent, { snapshot: { error: "unreadable" } })
        verify(!button.inUse)
        compare(button.tooltip, "Privacy")
        compare(button.tooltipDetail, "Cannot read PipeWire, so nothing can be reported.")
        button.snapshot = make([], "pw-dump is not available or did not answer")
        verify(!button.inUse)
        compare(button.tooltipDetail, "Cannot read PipeWire, so nothing can be reported.")
    }

    // --- the tooltip

    function test_the_tooltip_lists_the_kinds_and_the_first_two_apps() {
        var button = build(buttonComponent, { snapshot: make([mic, mic2, cam, screen]) })
        compare(button.tooltip, "In use: Microphone, Camera, Screen sharing")
        compare(button.tooltipDetail, "Firefox, Discord and 2 more")
    }

    function test_the_tooltip_names_one_app_plainly() {
        var button = build(buttonComponent, { snapshot: make([mic]) })
        compare(button.tooltip, "In use: Microphone")
        compare(button.tooltipDetail, "Firefox")
    }

    function test_an_app_with_two_streams_is_named_once() {
        compare(Privacy.detail([mic, use("microphone", "Firefox", 63)], t), "Firefox")
        compare(Privacy.detail([mic, mic2, cam], t), "Firefox, Discord and 1 more")
    }

    function test_idle_tooltip_does_not_claim_anything() {
        var button = build(buttonComponent, { snapshot: make([]) })
        compare(button.tooltip, "Privacy")
        compare(button.tooltipDetail, "Nothing is using the microphone, camera or screen")
    }

    // --- the colour

    function test_the_dot_colour_is_a_palette_role_with_an_error_default() {
        compare(Privacy.DOT_COLORS, ["error", "primary", "info"])
        compare(Privacy.dotToken(undefined), "error")
        compare(Privacy.dotToken(""), "error")
        compare(Privacy.dotToken("#ff00ff"), "error")
        compare(Privacy.dotToken("primary"), "primary")
        compare(Privacy.dotToken("info"), "info")
    }

    function test_the_dot_resolves_its_colour_through_the_palette() {
        VitrailTokens.configure({ error: "#ff0000", primary: "#00ff00", info: "#0000ff" }, true, "glass", {})
        var button = build(buttonComponent, { snapshot: make([mic]) })
        compare(find(button, "dot")[0].color.toString(), "#ff0000")
        button.dotColor = "primary"
        compare(find(button, "dot")[0].color.toString(), "#00ff00")
        button.dotColor = "info"
        compare(find(button, "dot")[0].color.toString(), "#0000ff")
        // A colour that is not a token never reaches the dot.
        button.dotColor = "#123456"
        compare(find(button, "dot")[0].color.toString(), "#ff0000")
    }

    // --- the popup

    function test_the_panel_has_one_block_per_kind_in_use_and_none_for_the_rest() {
        var panel = build(panelComponent, { snapshot: make([mic, mic2, screen]) })
        compare(find(panel, "kind-microphone").length, 1)
        compare(find(panel, "kind-camera").length, 0)
        compare(find(panel, "kind-screen").length, 1)
        compare(find(find(panel, "kind-microphone")[0], "use").length, 2)
        compare(find(find(panel, "kind-screen")[0], "use").length, 1)
        verify(!find(panel, "empty")[0].visible)
    }

    function test_each_row_names_the_app_and_has_a_cut_off_button() {
        var panel = build(panelComponent, { snapshot: make([mic]) })
        var row = find(panel, "use")[0]
        compare(find(row, "app")[0].text, "Firefox")
        compare(find(row, "streamLabel")[0].text, "stream-61")
        var cut = find(row, "cut")[0]
        compare(cut.text, "Cut off")
        verify(cut.enabled)
    }

    function test_cut_off_asks_once_for_that_stream_only() {
        var panel = build(panelComponent, { snapshot: make([mic, mic2]) })
        var asked = []
        panel.cutRequested.connect(function (kind, node) { asked.push(kind + ":" + node) })
        find(find(panel, "use")[1], "cut")[0].clicked()
        compare(asked.length, 1)
        compare(asked[0], "microphone:62")
    }

    function test_cut_off_waits_while_one_runs() {
        var panel = build(panelComponent, { snapshot: make([mic]), busy: true })
        verify(!find(panel, "cut")[0].enabled)
    }

    function test_only_the_watched_kinds_are_listed() {
        var panel = build(panelComponent, { snapshot: make([mic, cam]), watch: '["camera"]' })
        compare(find(panel, "kind-microphone").length, 0)
        compare(find(panel, "kind-camera").length, 1)
    }

    function test_a_quiet_machine_gets_a_calm_line_not_empty_cards() {
        var panel = build(panelComponent, { snapshot: make([]) })
        compare(find(panel, "use").length, 0)
        verify(find(panel, "empty")[0].visible)
        verify(!find(panel, "unavailable")[0].visible)
    }

    function test_no_pipewire_is_a_calm_line() {
        var panel = build(panelComponent, { snapshot: make([], "pw-dump is not available or did not answer") })
        verify(find(panel, "unavailable")[0].visible)
        verify(!find(panel, "empty")[0].visible)
        compare(find(panel, "use").length, 0)
    }

    function test_the_popup_never_says_recording() {
        for (var key in strings)
            verify(strings[key].toLowerCase().indexOf("record") < 0, key)
    }

    function test_the_gear_asks_for_settings() {
        var panel = build(panelComponent, { snapshot: make([]) })
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }

    function test_only_a_real_node_can_be_cut() {
        verify(Privacy.cuttable(mic))
        verify(!Privacy.cuttable(use("microphone", "x", -1)))
        verify(!Privacy.cuttable(use("microphone", "x", 1.5)))
        verify(!Privacy.cuttable({ kind: "radar", node: 3 }))
        verify(!Privacy.cuttable(null))
    }
}
