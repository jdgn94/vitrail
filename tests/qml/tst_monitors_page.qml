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
        id: palette
    }

    Component {
        id: pageComponent

        MonitorsPage {
            palette: palette
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
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function init() {
        mockPrefs.monitorOverrides = ""
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
        compare(findChild(page, "details").visible, true)
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
        var details = findChild(page, "details")
        var spacer = findChild(page, "detailsSpacer")
        var bar = findChild(page, "applyBar")
        compare(spacer.height, 0, "no room is kept when there is nothing to apply")
        page.dragMonitor("DP-1", -1200, 0)
        tryVerify(function () { return bar.visible && spacer.height > 0 })
        verify(spacer.height >= bar.height, "the spacer clears the floating bar")
        details.contentY = Math.max(0, details.contentHeight - details.height)
        tryVerify(function () {
            return details.contentY >= details.contentHeight - details.height - 1
        })
        var last = findChild(page, "detailsLast")
        var bottom = last.mapToItem(page, 0, last.height).y
        verify(bottom <= bar.y, "the last row sits above the floating card")
    }
}
