import QtQuick
import QtTest
import "../../bar/osd"
import "../../kit"
import "../../bar/osd/osd.js" as Osd
import "../../kit/frame.js" as Frame
import "../../kit/tokens.js" as Tokens
import "../../bar/osd/icons.js" as Icons
import "../../bar/osd/brightness.js" as Brightness
import "../../bar/osd/audio.js" as Audio

// Where the OSD sits, how big it is, which icon it shows, and how brightness
// is stepped and written.
TestCase {
    id: testCase
    name: "Osd"
    when: windowShown
    visible: true
    width: 400
    height: 400

    readonly property var metrics: ({ thickness: 32, length: 100, icon: 32, textWide: 40, textTall: 16,
                                      gear: 32, pad: 8, spacing: 8, inner: 4 })
    // A frame 6 px thick on every side, 1000 x 800 screen.
    readonly property var bounds: ({ left: 6, top: 6, right: 6, bottom: 6 })

    // --- which edge ---------------------------------------------------------

    function test_the_edge_is_opposite_the_notifications() {
        compare(Osd.edgeFor("top-right", "top"), "left")
        compare(Osd.edgeFor("bottom-right", "top"), "left")
        compare(Osd.edgeFor("top-left", "bottom"), "right")
        compare(Osd.edgeFor("bottom-left", "bottom"), "right")
        compare(Osd.edgeFor("top-center", "left"), "bottom")
        compare(Osd.edgeFor("bottom-center", "left"), "top")
    }

    function test_an_unknown_position_reads_as_top_right() {
        compare(Osd.edgeFor("", "bottom"), "left")
        compare(Osd.edgeFor("nonsense", "bottom"), "left")
    }

    function test_the_bars_edge_gives_way_to_the_top() {
        compare(Osd.edgeFor("top-right", "left"), "top")
        compare(Osd.edgeFor("top-left", "right"), "top")
        compare(Osd.edgeFor("top-center", "bottom"), "top")
    }

    function test_when_the_top_is_the_bars_the_bottom_is_next() {
        compare(Osd.edgeFor("bottom-center", "top"), "bottom")
    }

    // --- sizes -----------------------------------------------------------------

    function test_a_cell_is_vertical_on_the_side_edges() {
        var cell = Osd.cell(true, metrics)
        compare(cell.width, 32)
        // icon, slider, text, gear, with an inner gap between each
        compare(cell.height, 32 + 4 + 100 + 4 + 16 + 4 + 32)
    }

    function test_a_cell_is_horizontal_on_the_top_and_bottom_edges() {
        var cell = Osd.cell(false, metrics)
        compare(cell.height, 32)
        compare(cell.width, 32 + 4 + 100 + 4 + 40 + 4 + 32)
    }

    function test_every_cell_has_a_settings_button() {
        var cell = createTemporaryObject(cellComponent, testCase)
        verify(cell !== null)
        verify(findChild(cell, "osdSettings") !== null)
    }

    function test_a_side_panel_stacks_its_cells() {
        var cell = Osd.cell(true, metrics)
        var panel = Osd.panelSize("left", 3, metrics)
        compare(panel.width, 32 + 2 * 8)
        compare(panel.height, 3 * cell.height + 2 * 8 + 2 * 8)
    }

    function test_a_top_panel_puts_its_cells_side_by_side() {
        var cell = Osd.cell(false, metrics)
        var panel = Osd.panelSize("bottom", 3, metrics)
        compare(panel.height, 32 + 2 * 8)
        compare(panel.width, 3 * cell.width + 2 * 8 + 2 * 8)
    }

    function test_one_cell_makes_a_shorter_panel() {
        verify(Osd.panelSize("left", 1, metrics).height < Osd.panelSize("left", 3, metrics).height)
    }

    // --- the same place on every monitor ---------------------------------------

    // Frame sizes as the bar passes them to Frame.layout.
    readonly property var sizes: ({ frame: 6, bar: 36, gap: 8, radius: 12 })
    readonly property var frameStyle: ({ border: true, corners: true })
    readonly property var barStyle: ({ docked: true, islands: false })

    function test_a_screen_without_a_bar_has_the_primary_bars_edge() {
        var primary = Frame.layout(frameStyle, barStyle, "left", sizes)
        var secondary = Frame.layout(frameStyle, null, "left", sizes)
        compare(secondary.edge, primary.edge)
        compare(Osd.edgeFor("top-right", secondary.edge), Osd.edgeFor("top-right", primary.edge))
        compare(Osd.edgeFor("top-right", secondary.edge), "top")
    }

    function test_the_edge_is_centred_in_the_primarys_bounds_on_every_monitor() {
        var primary = Frame.layout(frameStyle, barStyle, "left", sizes)
        var secondary = Frame.layout(frameStyle, null, "left", sizes)
        var size = Osd.panelSize("top", 3, metrics)
        var want = Osd.panelRect("top", 1000, 800, size, primary.dock, 0)
        var own = Osd.alignBounds("top", secondary.dock, primary.dock)
        var got = Osd.panelRect("top", 1000, 800, size, own, 0)
        compare(got.x, want.x)
        compare(got.y, want.y)
        // Without alignment the panel would shift by half the bar.
        verify(Osd.panelRect("top", 1000, 800, size, secondary.dock, 0).x !== want.x)
    }

    function test_the_screens_own_frame_sets_the_docking_side() {
        var own = { left: 6, top: 6, right: 6, bottom: 6 }
        var ref = { left: 36, top: 8, right: 6, bottom: 9 }
        var top = Osd.alignBounds("top", own, ref)
        compare(top.top, 6)
        compare(top.bottom, 6)
        compare(top.left, 36)
        compare(top.right, 6)
        var side = Osd.alignBounds("right", own, ref)
        compare(side.left, 6)
        compare(side.right, 6)
        compare(side.top, 8)
        compare(side.bottom, 9)
    }

    // --- placement -------------------------------------------------------------

    function test_the_left_panel_is_glued_to_the_frame_and_centred() {
        var size = Osd.panelSize("left", 3, metrics)
        var rect = Osd.panelRect("left", 1000, 800, size, bounds, 0)
        compare(rect.x, 6)
        compare(rect.y, 6 + (800 - 12 - size.height) / 2)
        compare(rect.width, size.width)
        compare(rect.height, size.height)
    }

    function test_the_right_panel_ends_at_the_frame() {
        var size = Osd.panelSize("right", 3, metrics)
        var rect = Osd.panelRect("right", 1000, 800, size, bounds, 0)
        compare(rect.x, 1000 - 6 - size.width)
    }

    function test_the_top_and_bottom_panels_are_centred_across() {
        var size = Osd.panelSize("bottom", 3, metrics)
        var bottom = Osd.panelRect("bottom", 1000, 800, size, bounds, 0)
        compare(bottom.y, 800 - 6 - size.height)
        compare(bottom.x, 6 + (1000 - 12 - size.width) / 2)
        var top = Osd.panelRect("top", 1000, 800, size, bounds, 0)
        compare(top.y, 6)
    }

    function test_the_panel_centres_in_what_a_bar_leaves() {
        // a bar 36 px thick on the top: the hole is 6 .. 794 vertically starting at 36
        var size = Osd.panelSize("left", 3, metrics)
        var rect = Osd.panelRect("left", 1000, 800, size, { left: 6, top: 36, right: 6, bottom: 6 }, 0)
        compare(rect.y, 36 + (800 - 36 - 6 - size.height) / 2)
    }

    function test_a_floating_panel_keeps_a_gap_from_the_frame() {
        var size = Osd.panelSize("left", 3, metrics)
        compare(Osd.panelRect("left", 1000, 800, size, bounds, 10).x, 16)
        compare(Osd.panelRect("right", 1000, 800, size, bounds, 10).x, 1000 - 16 - size.width)
    }

    // --- hot zone --------------------------------------------------------------

    function test_the_hot_zone_is_a_strip_along_the_edge_as_long_as_the_panel() {
        var size = Osd.panelSize("left", 3, metrics)
        var panel = Osd.panelRect("left", 1000, 800, size, bounds, 0)
        var zone = Osd.hotZone("left", 1000, 800, panel, 6, 5)
        compare(zone.x, 0)
        compare(zone.width, 11)
        compare(zone.y, panel.y)
        compare(zone.height, panel.height)
    }

    function test_the_hot_zone_hugs_each_edge() {
        var size = Osd.panelSize("bottom", 3, metrics)
        var panel = Osd.panelRect("bottom", 1000, 800, size, bounds, 0)
        var bottom = Osd.hotZone("bottom", 1000, 800, panel, 6, 5)
        compare(bottom.y, 800 - 11)
        compare(bottom.height, 11)
        compare(bottom.x, panel.x)
        compare(bottom.width, panel.width)
        var right = Osd.hotZone("right", 1000, 800, Osd.panelRect("right", 1000, 800, size, bounds, 0), 6, 5)
        compare(right.x, 1000 - 11)
        var top = Osd.hotZone("top", 1000, 800, Osd.panelRect("top", 1000, 800, size, bounds, 0), 6, 5)
        compare(top.y, 0)
    }

    function test_the_hot_zone_has_a_strip_without_a_frame_border() {
        var panel = Osd.panelRect("left", 1000, 800, Osd.panelSize("left", 3, metrics), { left: 0, top: 0, right: 0, bottom: 0 }, 0)
        compare(Osd.hotZone("left", 1000, 800, panel, 0, 5).width, 5)
    }

    // --- cells and the extension card ------------------------------------------

    function test_a_cells_rect_is_inside_the_panel() {
        var size = Osd.panelSize("left", 3, metrics)
        var panel = Osd.panelRect("left", 1000, 800, size, bounds, 0)
        var cell = Osd.cell(true, metrics)
        var second = Osd.cellRect("left", panel, 1, metrics)
        compare(second.x, panel.x + 8)
        compare(second.y, panel.y + 8 + cell.height + 8)
        compare(second.width, cell.width)
        compare(second.height, cell.height)
        var side = Osd.cellRect("bottom", Osd.panelRect("bottom", 1000, 800, Osd.panelSize("bottom", 3, metrics), bounds, 0), 2, metrics)
        compare(side.width, Osd.cell(false, metrics).width)
    }

    function test_the_card_opens_toward_the_interior_beside_its_cell() {
        var panel = Osd.panelRect("left", 1000, 800, Osd.panelSize("left", 3, metrics), bounds, 0)
        var cell = Osd.cellRect("left", panel, 1, metrics)
        var card = Osd.cardRect("left", panel, cell, { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(card.x, panel.x + panel.width + 12)
        compare(card.y, cell.y + cell.height / 2 - 60)
        compare(card.width, 200)
        var right = Osd.panelRect("right", 1000, 800, Osd.panelSize("right", 3, metrics), bounds, 0)
        var rightCard = Osd.cardRect("right", right, Osd.cellRect("right", right, 0, metrics), { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(rightCard.x, right.x - 12 - 200)
    }

    function test_the_card_hangs_below_a_top_panel_and_above_a_bottom_one() {
        var top = Osd.panelRect("top", 1000, 800, Osd.panelSize("top", 3, metrics), bounds, 0)
        var cell = Osd.cellRect("top", top, 0, metrics)
        var below = Osd.cardRect("top", top, cell, { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(below.y, top.y + top.height + 12)
        var bottom = Osd.panelRect("bottom", 1000, 800, Osd.panelSize("bottom", 3, metrics), bounds, 0)
        var above = Osd.cardRect("bottom", bottom, Osd.cellRect("bottom", bottom, 0, metrics), { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(above.y, bottom.y - 12 - 120)
    }

    function test_the_card_stays_inside_the_screen() {
        var panel = Osd.panelRect("left", 1000, 800, Osd.panelSize("left", 3, metrics), bounds, 0)
        var card = Osd.cardRect("left", panel, { x: panel.x, y: 5, width: 32, height: 20 }, { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(card.y, 6 + 12)
        var low = Osd.cardRect("left", panel, { x: panel.x, y: 790, width: 32, height: 20 }, { width: 200, height: 120 }, bounds, 12, 1000, 800)
        compare(low.y, 800 - 6 - 12 - 120)
    }

    // --- icons -----------------------------------------------------------------

    function test_the_volume_icon_follows_level_and_mute() {
        compare(Icons.volume(0.8, false), "volume_up")
        compare(Icons.volume(0.5, false), "volume_up")
        compare(Icons.volume(0.3, false), "volume_down")
        compare(Icons.volume(0, false), "volume_mute")
        compare(Icons.volume(0.8, true), "volume_off")
        compare(Icons.volume(0, true), "volume_off")
    }

    function test_the_microphone_icon_follows_mute() {
        compare(Icons.mic(false), "mic")
        compare(Icons.mic(true), "mic_off")
    }

    function test_the_brightness_icon_follows_level() {
        compare(Icons.brightness(0.1), "brightness_low")
        compare(Icons.brightness(0.5), "brightness_medium")
        compare(Icons.brightness(0.9), "brightness_high")
        compare(Icons.brightness(1), "brightness_high")
    }

    // --- apps ------------------------------------------------------------------

    function test_the_app_key_prefers_the_application_name() {
        compare(Audio.appKey({ "application.name": "Firefox",
                               "application.process.binary": "firefox" }, "node"), "Firefox")
        compare(Audio.appKey({ "application.process.binary": "firefox" }, "node"), "firefox")
        compare(Audio.appKey({}, "node-7"), "node-7")
    }

    function test_streams_of_one_app_become_one_group() {
        var groups = Audio.groups([
            { key: "Firefox", name: "Firefox", icon: "", binary: "firefox", node: 1 },
            { key: "Firefox", name: "Firefox", icon: "", binary: "firefox", node: 2 },
            { key: "mpv", name: "mpv", icon: "mpv", binary: "mpv", node: 3 }
        ])
        compare(groups.length, 2)
        compare(groups[0].key, "Firefox")
        compare(groups[0].nodes.length, 2)
        compare(groups[1].nodes.length, 1)
    }

    function test_the_icon_name_is_optional() {
        compare(Audio.iconName({ "application.icon-name": "mpv" }), "mpv")
        compare(Audio.iconName({}), "")
    }

    function test_a_window_class_matches_its_stream_case_insensitively() {
        verify(Audio.classMatches("firefox", "Firefox", "firefox"))
        verify(Audio.classMatches("firefox", "Firefox", "Firefox"))
        verify(Audio.classMatches("", "mpv", "mpv"))
        verify(!Audio.classMatches("firefox", "Firefox", ""))
        verify(!Audio.classMatches("firefox", "Firefox", "kitty"))
    }

    function test_an_app_row_shows_its_own_percentage() {
        var row = createTemporaryObject(appRowComponent, testCase)
        verify(row !== null)
        compare(row.level, 50)
        compare(findChild(row, "percent").text, "50%")
    }

    function test_an_app_row_is_the_mean_of_its_streams() {
        var row = createTemporaryObject(appRowComponent, testCase)
        row.group = ({ key: "mpv", name: "mpv", icon: "mpv", binary: "mpv",
                       nodes: [ { audio: { volume: 0.4, muted: false } },
                                { audio: { volume: 0.6, muted: false } } ] })
        compare(row.level, 50)
        compare(findChild(row, "percent").text, "50%")
    }

    function test_the_wheel_over_an_app_row_moves_its_slider() {
        var row = createTemporaryObject(appRowComponent, testCase)
        var slider = findChild(row, "slider")
        moved.target = row
        moved.clear()
        mouseWheel(slider, slider.width / 2, slider.height / 2, 0, 120)
        compare(moved.count, 1)
        compare(moved.signalArguments[0][0], 55)
    }

    // --- brightness ------------------------------------------------------------

    function test_a_step_moves_and_clamps() {
        compare(Brightness.step(50, 1, 5), 55)
        compare(Brightness.step(50, -1, 5), 45)
        compare(Brightness.step(98, 1, 5), 100)
        compare(Brightness.step(2, -1, 5), 0)
        compare(Brightness.step(50.4, 1, 5), 55)
    }

    function test_clamp_keeps_a_percent_whole_and_in_range() {
        compare(Brightness.clamp(-4), 0)
        compare(Brightness.clamp(104), 100)
        compare(Brightness.clamp(33.6), 34)
        compare(Brightness.clamp(NaN), 0)
    }

    function test_the_main_level_is_the_mean_of_the_displays() {
        compare(Brightness.level([]), 0)
        compare(Brightness.level([{ percent: 30 }, { percent: 71 }]), 51)
        compare(Brightness.level([{ percent: 40 }]), 40)
    }

    function test_an_external_display_is_written_over_ddc() {
        compare(Brightness.command({ kind: "ddc", bus: 6, max: 100 }, 42),
                ["ddcutil", "setvcp", "10", "42", "--bus", "6", "--noverify"])
        // a monitor whose scale is not 0..100
        compare(Brightness.command({ kind: "ddc", bus: 7, max: 255 }, 50)[3], "128")
    }

    function test_a_laptop_panel_is_written_with_brightnessctl() {
        compare(Brightness.command({ kind: "backlight", name: "eDP-1", device: "intel_backlight" }, 30),
                ["brightnessctl", "--quiet", "--device=intel_backlight", "set", "30%"])
    }

    function test_the_list_the_helper_prints_is_read_safely() {
        var parsed = Brightness.parse('{"status": "ok", "devices": [{"name": "DP-1", "kind": "ddc", "bus": 6, "percent": 70, "max": 100}]}')
        compare(parsed.status, "ok")
        compare(parsed.devices.length, 1)
        compare(parsed.devices[0].name, "DP-1")
        compare(Brightness.parse("not json").status, "none")
        compare(Brightness.parse("").devices.length, 0)
    }

    function test_each_state_without_displays_has_its_own_reason() {
        compare(Brightness.reason("access"), "osd.brightnessAccess")
        compare(Brightness.reason("missing"), "osd.brightnessMissing")
        compare(Brightness.reason("none"), "osd.brightnessNone")
        compare(Brightness.reason("loading"), "osd.brightnessLoading")
        compare(Brightness.reason("ok"), "")
    }

    // --- the wheel over a slider -----------------------------------------------

    VitrailPalette {
        id: palette
    }

    Component {
        id: cellComponent

        OsdCell {
            kind: "volume"
            vertical: true
            metrics: testCase.metrics
            value: 50
            icon: "volume_up"
            muteable: true
        }
    }

    Component {
        id: appRowComponent

        AppRow {
            width: 300
            step: 5
            group: ({ key: "mpv", name: "mpv", icon: "mpv", binary: "mpv",
                      nodes: [ { audio: { volume: 0.5, muted: false } } ] })
        }
    }

    SignalSpy {
        id: moved

        signalName: "moved"
    }

    // The cell as the panel builds it: a vertical slider among a hover handler,
    // the mute button and the percentage.
    function test_the_wheel_over_a_vertical_cell_moves_its_slider() {
        var cell = createTemporaryObject(cellComponent, testCase)
        verify(cell !== null)
        moved.target = cell
        moved.clear()
        // The middle of the cell is the slider (icon above, percentage below).
        mouseWheel(cell, cell.width / 2, cell.height / 2, 0, 120)
        compare(moved.count, 1)
        compare(moved.signalArguments[0][0], 50 + VitrailTokens.osd.step)
        mouseWheel(cell, cell.width / 2, cell.height / 2, 0, -240)
        compare(moved.count, 2)
        compare(moved.signalArguments[1][0], 50 - VitrailTokens.osd.step)
    }

    // --- dwell before opening ---------------------------------------------------

    Component {
        id: gateComponent

        DwellGate { interval: 60 }
    }

    function test_the_pointer_must_stay_for_the_whole_dwell() {
        var gate = createTemporaryObject(gateComponent, testCase)
        verify(!gate.ready)
        gate.hovered = true
        wait(20)
        verify(!gate.ready)
        tryVerify(function () { return gate.ready }, 500)
    }

    function test_leaving_early_cancels_and_entering_again_restarts() {
        var gate = createTemporaryObject(gateComponent, testCase)
        gate.hovered = true
        wait(40)
        gate.hovered = false
        wait(80)
        verify(!gate.ready)
        gate.hovered = true
        wait(40)
        verify(!gate.ready)
        tryVerify(function () { return gate.ready }, 500)
    }

    function test_leaving_after_the_dwell_resets_the_gate() {
        var gate = createTemporaryObject(gateComponent, testCase)
        gate.hovered = true
        tryVerify(function () { return gate.ready }, 500)
        gate.hovered = false
        verify(!gate.ready)
    }

    function test_the_dwell_is_a_token() {
        compare(Tokens.motion.dwell, 150)
    }
}
