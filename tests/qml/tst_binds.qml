import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/binds"
import "../../bar/binds/binds.js" as Binds

// The keybind cheatsheet: the filter, the empty and unavailable states, and
// the keys that drive it (arrows move, Enter does nothing, Escape closes).
TestCase {
    id: testCase

    name: "Binds"
    when: windowShown
    visible: true
    width: 520
    height: 760

    VitrailPalette {
        id: palette
    }

    readonly property var sample: [
        { mods: "Super", key: "Q", dispatcher: "__lua", arg: "5", description: "window/close" },
        { mods: "Super+Shift", key: "←", dispatcher: "__lua", arg: "41", description: "move/left" },
        { mods: "", key: "Volume Up", dispatcher: "__lua", arg: "93", description: "media/volume-up" }
    ]

    readonly property var strings: ({
        "binds.title": "Keyboard shortcuts",
        "binds.search": "Search shortcuts",
        "binds.empty": "No shortcut matches",
        "binds.unavailable": "Hyprland is not running",
        "binds.count": "%1 shortcuts",
        "binds.hint.navigate": "↑↓ Move",
        "binds.hint.close": "Esc Close",
        "binds.group.window": "Windows",
        "binds.group.move": "Move windows",
        "binds.group.media": "Media"
    })

    Component {
        id: control

        BindsOverlay {
            width: 440
            strings: testCase.strings
        }
    }

    SignalSpy {
        id: dismissed

        signalName: "dismissed"
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

    function make(props) {
        var box = createTemporaryObject(control, testCase, props || {})
        verify(box)
        return box
    }

    function test_an_empty_query_shows_every_shortcut() {
        compare(Binds.filter(sample, "").length, 3)
        compare(Binds.filter(sample, "   ").length, 3)
        compare(Binds.filter([], "").length, 0)
    }

    function test_the_filter_matches_keys_modifiers_and_descriptions() {
        compare(Binds.filter(sample, "super").length, 2)
        compare(Binds.filter(sample, "super shift").length, 1)
        compare(Binds.filter(sample, "close").length, 1)
        compare(Binds.filter(sample, "CLOSE").length, 1)
        compare(Binds.filter(sample, "media").length, 1)
        compare(Binds.filter(sample, "nope").length, 0)
    }

    function test_a_combo_joins_the_modifiers_and_the_key() {
        compare(Binds.combo(sample[0]), "Super+Q")
        compare(Binds.combo(sample[1]), "Super+Shift+←")
        compare(Binds.combo(sample[2]), "Volume Up")
    }

    function test_a_description_is_grouped_and_readable() {
        var t = function (key) { return strings[key] === undefined ? key : strings[key] }
        compare(Binds.label(sample[0], t), "Windows · Close")
        compare(Binds.label(sample[1], t), "Move windows · Left")
        compare(Binds.label(sample[2], t), "Media · Volume Up")
        compare(Binds.label({ description: "custom/thing-to-do" }, t), "Custom · Thing To Do")
    }

    function test_the_state_parser_tolerates_a_broken_answer() {
        var state = Binds.parseState('{"available":true,"rows":[{"key":"Q"}]}')
        compare(state.available, true)
        compare(state.rows.length, 1)
        compare(Binds.parseState("not json").available, false)
        compare(Binds.parseState("not json").rows.length, 0)
        compare(Binds.parseState('{"available":false,"rows":[{"key":"Q"}]}').available, false)
        compare(Binds.parseState('{"available":false,"rows":[{"key":"Q"}]}').rows.length, 0)
    }

    function test_typing_filters_the_rendered_list() {
        var box = make({ rows: sample, available: true })
        compare(box.query, "")
        compare(box.filtered.length, 3)
        box.query = "super shift"
        compare(box.filtered.length, 1)
        compare(box.filtered[0].description, "move/left")
        compare(box.current, 0)
    }

    function test_an_empty_result_says_so() {
        var box = make({ rows: sample, available: true })
        box.query = "nothing matches this"
        compare(box.filtered.length, 0)
        verify(findChild(box, "bindsEmpty").visible)
        verify(!findChild(box, "bindsUnavailable").visible)
    }

    function test_without_hyprland_the_reason_shows() {
        var box = make({ rows: [], available: false })
        verify(findChild(box, "bindsUnavailable").visible)
        verify(!findChild(box, "bindsEmpty").visible)
    }

    function test_the_arrows_move_within_the_list_and_stop_at_the_ends() {
        var box = make({ rows: sample, available: true })
        compare(box.current, 0)
        box.move(1)
        compare(box.current, 1)
        box.move(99)
        compare(box.current, 2)
        box.move(-99)
        compare(box.current, 0)
    }

    function test_enter_does_nothing_and_escape_closes() {
        var box = make({ rows: sample, available: true })
        dismissed.target = box
        dismissed.clear()
        var enter = { key: Qt.Key_Return, accepted: false }
        box.handleKey(enter)
        compare(enter.accepted, true)
        compare(dismissed.count, 0)

        var down = { key: Qt.Key_Down, accepted: false }
        box.handleKey(down)
        compare(down.accepted, true)
        compare(box.current, 1)

        var escape = { key: Qt.Key_Escape, accepted: false }
        box.handleKey(escape)
        compare(escape.accepted, true)
        compare(dismissed.count, 1)
    }
}
