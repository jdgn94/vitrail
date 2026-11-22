import QtQuick
import QtTest
import "../../kit"
import "../../shell/pages"
import "../../shell/monitorsview.js" as View

// The Monitors page: the canvas edits a draft, Apply writes it, Discard puts
// the applied document back, and the page marks the output it is editing.
TestCase {
    id: testCase

    name: "MonitorsPage"
    when: windowShown
    visible: true
    width: 1000
    height: 700

    readonly property var first: ({
        name: "DP-1", description: "Microstep MSI MAG 275QF", width: 2560, height: 1440,
        refresh: 180, x: 0, y: 0, scale: 1, transform: 0, disabled: false, mirror: "",
        focused: true, mode: "2560x1440@180.00", modes: ["2560x1440@59.95", "2560x1440@180.00"]
    })
    readonly property var second: ({
        name: "HDMI-A-1", description: "Dell U2415", width: 1920, height: 1200,
        refresh: 59.95, x: 2560, y: 0, scale: 1.25, transform: 1, disabled: false, mirror: "",
        focused: false, mode: "1920x1200@59.95", modes: ["1920x1200@59.95"]
    })

    QtObject {
        id: mockPrefs

        property string monitorOverrides: ""
        property string wallpaperMonitors: "{}"
        property string barMonitors: "{}"
        property string wallpaper: ""
        property string wallpaperDir: "/tmp/vitrail-qml-monitors"
        property string barEdge: "left"
        property real surfaceOpacity: 0.9
    }

    VitrailPalette {
        id: theme
    }

    Component {
        id: pageComponent

        MonitorsPage {
            palette: theme
            prefs: mockPrefs
            strings: ({})
            configDir: "/tmp/vitrail-qml-monitors"
            cacheDir: ""
            monitors: ({
                available: true,
                monitors: [testCase.first, testCase.second]
            })
        }
    }

    function initTestCase() {
        VitrailTokens.configure(theme, true, "glass", ({}))
    }

    function init() {
        mockPrefs.monitorOverrides = ""
        mockPrefs.barMonitors = "{}"
    }

    function make() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 640 })
        verify(page)
        return page
    }

    function test_the_first_output_is_selected_and_the_draft_is_clean() {
        var page = make()
        compare(page.selected, "DP-1")
        compare(page.dirty, false)
        compare(page.changes, 0)
        compare(findChild(page, "applyBar").visible, false)
    }

    function test_dragging_updates_the_draft_and_not_the_preference() {
        var page = make()
        page.dragMonitor("DP-1", -1200, 120)
        compare(View.position(page.draftDoc["DP-1"]).x, -1200)
        compare(page.dirty, true)
        compare(page.changes, 1)
        compare(mockPrefs.monitorOverrides, "", "no preference is written while dragging")
        compare(findChild(page, "applyBar").visible, true)
    }

    function test_selecting_an_output_loads_its_panel() {
        var page = make()
        page.select("HDMI-A-1")
        compare(page.selected, "HDMI-A-1")
        compare(page.selectedSpec.mode, "1920x1200@59.95")
        compare(page.selectedSpec.scale, 1.25)
        compare(findChild(page, "rotation").current, "90", "the panel shows the output's own turn")
    }

    function test_discard_returns_to_the_applied_configuration() {
        var page = make()
        page.dragMonitor("DP-1", -1200, 0)
        compare(page.dirty, true)
        page.discardDraft()
        compare(page.dirty, false)
        compare(mockPrefs.monitorOverrides, "", "a draft that was never applied is not written")
        compare(findChild(page, "applyBar").visible, false)
    }

    function test_apply_writes_the_draft_and_clears_the_bar() {
        var page = make()
        page.dragMonitor("DP-1", -1200, 0)
        page.applyDraft()
        verify(mockPrefs.monitorOverrides !== "")
        compare(page.pending, true)
        var saved = View.parse(mockPrefs.monitorOverrides)
        compare(saved["DP-1"].position, "-1200x0")
        page.read(JSON.stringify({
            updated: page.sent + 1,
            available: true,
            monitors: [testCase.first, testCase.second],
            result: { code: 0 }
        }))
        compare(page.pending, false)
        compare(page.dirty, false)
        compare(findChild(page, "applyBar").visible, false)
    }

    function test_a_refused_apply_keeps_the_draft_and_discard_reverts() {
        var page = make()
        page.dragMonitor("DP-1", -1200, 0)
        page.applyDraft()
        page.read(JSON.stringify({
            updated: page.sent + 1,
            available: true,
            monitors: [testCase.first, testCase.second],
            result: { code: 1, failed: ["DP-1"] }
        }))
        compare(page.pending, false)
        compare(page.dirty, true, "the draft survives a refused apply")
        verify(page.error !== "")
        page.discardDraft()
        compare(page.dirty, false)
        var reverted = View.parse(mockPrefs.monitorOverrides)
        compare(View.primaryOf(reverted), "DP-1")
        compare(reverted["DP-1"].position, "0x0", "the applied position comes back")
    }

    function test_the_selected_output_is_the_one_marked_on_screen() {
        var page = make()
        compare(View.parseIndicator(page.indicatorState).name, "DP-1")
        page.select("HDMI-A-1")
        compare(View.parseIndicator(page.indicatorState), ({ active: true, name: "HDMI-A-1" }))
        page.visible = false
        compare(View.parseIndicator(page.indicatorState), ({ active: false, name: "" }))
    }

    function test_the_apply_bar_shrinks_to_its_controls() {
        var page = make()
        page.dragMonitor("DP-1", -1200, 0)
        var bar = findChild(page, "applyBar")
        var row = findChild(page, "applyRow")
        tryVerify(function () { return bar.visible && row.implicitWidth > 0 })
        compare(bar.width, Math.min(page.width - 2 * VitrailTokens.gap("md"),
                                    row.implicitWidth + 2 * VitrailTokens.gap("md")))
        verify(bar.width < page.width - VitrailTokens.gap("md"),
               "the card no longer spans the page")
    }

    function test_the_last_option_can_scroll_above_the_apply_bar() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 480 })
        verify(page)
        var scroll = findChild(page, "pageScroll")
        var spacer = findChild(page, "detailsSpacer")
        var bar = findChild(page, "applyBar")
        compare(spacer.height, 0, "no room is kept when there is nothing to apply")
        page.dragMonitor("DP-1", -1200, 0)
        tryVerify(function () { return bar.visible && spacer.height > 0 })
        verify(spacer.height >= bar.height, "the spacer clears the floating bar")
        scroll.contentY = Math.max(0, scroll.contentHeight - scroll.height)
        tryVerify(function () {
            return scroll.contentY >= scroll.contentHeight - scroll.height - 1
        })
        var last = findChild(page, "detailsLast")
        var bottom = last.mapToItem(page, 0, last.height).y
        verify(bottom <= bar.y, "the last row sits above the floating card")
    }

    function test_the_canvas_and_the_settings_share_one_scroll() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 480 })
        verify(page)
        var scroll = findChild(page, "pageScroll")
        var canvas = findChild(page, "canvas")
        verify(scroll && canvas)
        tryVerify(function () { return scroll.contentHeight > scroll.height })
        scroll.contentY = scroll.contentHeight - scroll.height
        verify(canvas.mapToItem(page, 0, 0).y < 0, "the canvas leaves the top")
    }

    function test_the_canvas_frame_holds_still_while_dragging() {
        var page = make()
        page.beginDrag()
        var scale = page.frameFor(900, 300).scale
        page.dragMonitor("DP-1", -4000, 2000)
        compare(page.frameFor(900, 300).scale, scale, "the scale does not follow the drag")
        page.endDrag()
        verify(page.dragFrame === null)
        verify(page.frameFor(900, 300).scale !== scale, "it re-fits once the drag ends")
    }

    function test_a_pointer_drag_moves_the_output_by_the_pixels_travelled() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 640 })
        verify(page)
        var canvas = findChild(page, "canvas")
        var tile = findChild(page, "canvasMonitor.DP-1")
        var scroll = findChild(page, "pageScroll")
        verify(canvas && tile)
        tryVerify(function () { return tile.width > 0 })
        var scale = page.canvasFit(canvas.width, canvas.height).scale
        var from = View.position(page.draftDoc["DP-1"])
        var at = tile.mapToItem(testCase, tile.width / 2, tile.height / 2)
        mousePress(testCase, at.x, at.y)
        mouseMove(testCase, at.x + 24, at.y)
        compare(View.position(page.draftDoc["DP-1"]).x, from.x + Math.round(24 / scale))
        verify(scroll.contentY === 0, "dragging a monitor does not scroll the page")
        mouseRelease(testCase, at.x + 24, at.y)
    }

    function test_a_drag_in_several_steps_keeps_its_tile_and_lands_snapped() {
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 640 })
        verify(page)
        var canvas = findChild(page, "canvas")
        var tile = findChild(page, "canvasMonitor.HDMI-A-1")
        verify(canvas && tile)
        tryVerify(function () { return tile.width > 0 })
        var scale = page.canvasFit(canvas.width, canvas.height).scale
        var from = View.position(page.draftDoc["HDMI-A-1"])
        var at = tile.mapToItem(testCase, tile.width / 2, tile.height / 2)
        mousePress(testCase, at.x, at.y)
        for (var step = 1; step <= 5; step++) {
            mouseMove(testCase, at.x - 10 * step, at.y + 4 * step)
            verify(findChild(page, "canvasMonitor.HDMI-A-1") === tile,
                   "the dragged tile survives move " + step)
            compare(View.position(page.draftDoc["HDMI-A-1"]).x, from.x + Math.round(-10 * step / scale))
        }
        compare(View.position(page.draftDoc["HDMI-A-1"]).y, from.y + Math.round(20 / scale))
        mouseRelease(testCase, at.x - 50, at.y + 20)
        verify(findChild(page, "canvasMonitor.HDMI-A-1") === tile, "the tile survives the release")
        var landed = View.rectOfName(page.live, page.draftDoc, "HDMI-A-1")
        var other = View.rectOfName(page.live, page.draftDoc, "DP-1")
        verify(!View.overlaps(landed, other), "it lands beside the other output, not on it")
        compare(page.dragFrame, null, "the frame is free again")
        compare(mockPrefs.monitorOverrides, "", "nothing is written before Apply")
    }

    function test_the_drop_joins_the_outputs_without_a_gap() {
        var page = make()
        var other = View.rectOfName(page.live, page.draftDoc, "DP-1")
        // Dropped below the first output with a gap, then released.
        page.dragMonitor("HDMI-A-1", 300, other.height + 400)
        page.dropMonitor("HDMI-A-1")
        var landed = View.rectOfName(page.live, page.draftDoc, "HDMI-A-1")
        compare(landed.y, other.y + other.height, "flush below, not floating under it")
        verify(View.touching(landed, other))
    }

    function test_guide_lines_show_while_dragging_and_go_on_release() {
        var page = make()
        var other = View.rectOfName(page.live, page.draftDoc, "DP-1")
        compare(page.guideLines.length, 0)
        page.beginDrag()
        // Its top lines up with the first output's top, a little to the right.
        page.dragMonitor("HDMI-A-1", other.width + 40, other.y + 6)
        verify(page.guideLines.some(function (guide) { return guide.axis === "y" && guide.at === other.y }),
               "the tops line up")
        var line = findChild(page, "guide.y." + other.y)
        verify(line, "the line is drawn")
        verify(line.visible && line.width > 0)
        page.endDrag()
        compare(page.guideLines.length, 0, "no guides after the release")
        compare(findChild(page, "guide.y." + other.y), null)
    }

    function test_an_automatic_output_can_be_dragged_and_is_pinned() {
        mockPrefs.monitorOverrides = JSON.stringify({ "HDMI-A-1": { position: "auto" } })
        var page = createTemporaryObject(pageComponent, testCase, { width: 900, height: 640 })
        verify(page)
        verify(View.position(page.draftDoc["HDMI-A-1"]).auto)
        var canvas = findChild(page, "canvas")
        var tile = findChild(page, "canvasMonitor.HDMI-A-1")
        tryVerify(function () { return tile.width > 0 })
        var scale = page.canvasFit(canvas.width, canvas.height).scale
        var at = tile.mapToItem(testCase, tile.width / 2, tile.height / 2)
        mousePress(testCase, at.x, at.y)
        mouseMove(testCase, at.x + 8, at.y)
        mouseMove(testCase, at.x + 16, at.y)
        var place = View.position(page.draftDoc["HDMI-A-1"])
        compare(place.auto, false, "dragging pins the position")
        compare(place.x, 2560 + Math.round(16 / scale), "it starts from where it is on screen")
        mouseRelease(testCase, at.x + 16, at.y)
    }

    function test_the_rotation_control_is_the_monitor_turned() {
        var page = make()
        page.select("HDMI-A-1")
        var control = findChild(page, "rotation")
        verify(control)
        compare(control.current, "90")
        compare(control.options[1].rotation, 90)
        control.selected("270")
        compare(page.draftDoc["HDMI-A-1"].transform, 3)
        compare(page.dirty, true)
    }
}
