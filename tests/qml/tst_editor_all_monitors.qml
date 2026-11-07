import QtQuick
import QtTest
import "../../bar/desktop"
import "../../bar/layouts.js" as Layouts
import "../../bar/barview.js" as BarView
import "../../kit"

// The editor on every monitor: one global bar/panel document, the desktop
// shared or per-monitor (`desktopSync`), and the per-monitor placements (bar
// edge, notification side, OSD edge) that the tabs write for the edited screen.
TestCase {
    id: testCase

    name: "EditorAllMonitors"
    when: windowShown
    visible: true
    width: 1100
    height: 820

    VitrailPalette {
        id: palette
    }

    Component {
        id: modeComponent

        DesktopEditMode {
            width: 1000
            height: 760
            monitor: "DP-1"
            screenMonitor: "HDMI-A-1"
            screenWidth: 1920
            screenHeight: 1080
            strings: ({})
            fonts: ["Inter", "DejaVu Sans"]
            monitors: [{ name: "DP-1" }, { name: "HDMI-A-1" }]
        }
    }

    Component {
        id: changedSpyComponent

        SignalSpy { signalName: "layoutChanged" }
    }

    Component {
        id: prefSpyComponent

        SignalSpy { signalName: "prefChanged" }
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

    function makeMode(extra) {
        var mode = createTemporaryObject(modeComponent, testCase, extra || ({}))
        verify(mode !== null)
        wait(20)
        return mode
    }

    function watch(component, target) {
        return createTemporaryObject(component, testCase, { target: target })
    }

    function lastText(spy) {
        return spy.signalArguments[spy.count - 1][1]
    }

    // --- the shared desktop ---------------------------------------------------

    function test_a_synced_desktop_writes_one_shared_list() {
        var mode = makeMode({ desktopSync: true })
        mode.tab = "desktop"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("clock", "compact")
        wait(20)
        var doc = Layouts.sanitize(lastText(spy), "desktop")
        verify(Array.isArray(doc.shared))
        compare(doc.shared.length, 1)
        compare(doc.monitors, {})
        var one = Layouts.effective(lastText(spy), "DP-1", null, "desktop", true).widgets
        var other = Layouts.effective(lastText(spy), "HDMI-A-1", null, "desktop", true).widgets
        compare(one.length, 1)
        compare(other.length, 1)
        compare(one[0].id, other[0].id)
    }

    function test_an_unsynced_desktop_keeps_one_list_per_monitor() {
        var mode = makeMode({ desktopSync: false })
        mode.tab = "desktop"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("clock", "compact")
        wait(20)
        var text = lastText(spy)
        var doc = Layouts.sanitize(text, "desktop")
        compare(doc.shared, undefined)
        compare(doc.monitors["DP-1"].widgets.length, 1)
        compare(Layouts.effective(text, "HDMI-A-1", null, "desktop", false).widgets, [])
    }

    function test_a_legacy_per_monitor_document_still_reads_when_synced() {
        var legacy = '{"monitors":{"DP-1":{"widgets":[' +
                     '{"id":"clock","x":0.2,"y":0.3,"size":"md","style":""}]}}}'
        var widgets = Layouts.effective(legacy, "DP-1", null, "desktop", true).widgets
        compare(widgets.length, 1)
        compare(widgets[0].id, "clock")
        compare(Layouts.effective(legacy, "HDMI-A-1", null, "desktop", true).widgets, [])
    }

    function test_the_desktop_sync_switch_writes_the_preference() {
        var mode = makeMode()
        mode.tab = "desktop"
        var spy = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "desktopEditSync").toggled(false)
        wait(20)
        compare(spy.signalArguments[0][0], "desktopSync")
        compare(spy.signalArguments[0][1], false)
        compare(mode.sync, false)
    }

    // --- the global bar document ---------------------------------------------

    function test_two_editors_show_the_same_global_bar_document() {
        var first = makeMode()
        var second = makeMode()
        first.tab = "bar"
        second.tab = "bar"
        var spy = watch(changedSpyComponent, first)
        wait(20)
        findChild(first, "editorBarGroup-clock").selected("start")
        wait(20)
        var text = lastText(spy)
        second.barLayout = text
        wait(20)
        compare(second.barText, text)
        var doc = Layouts.sanitize(second.barText)
        verify(doc.order.start.indexOf("clock") >= 0)
    }

    // --- the per-monitor placements ------------------------------------------

    function test_the_bar_edge_writes_only_the_edited_monitor() {
        var mode = makeMode()
        mode.tab = "bar"
        var layouts = watch(changedSpyComponent, mode)
        var prefs = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarPosition").selected("top")
        wait(20)
        compare(prefs.signalArguments[0][0], "barMonitors")
        var doc = BarView.document(prefs.signalArguments[0][1])
        compare(doc["HDMI-A-1"].edge, "top")
        compare(doc["DP-1"], undefined)
        compare(layouts.count, 0)
    }

    function test_the_osd_edge_writes_only_the_edited_monitor() {
        var mode = makeMode()
        mode.tab = "bar"
        var prefs = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarOsdEdge").selected("bottom")
        wait(20)
        var doc = BarView.document(prefs.signalArguments[0][1])
        compare(doc["HDMI-A-1"].osdEdge, "bottom")
        compare(doc["DP-1"], undefined)
    }

    function test_the_notification_side_writes_only_the_edited_monitor() {
        var mode = makeMode()
        mode.tab = "panel"
        var prefs = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "editorPanelSide").selected("left")
        wait(20)
        compare(prefs.signalArguments[0][0], "barMonitors")
        var doc = BarView.document(prefs.signalArguments[0][1])
        compare(doc["HDMI-A-1"].notificationSide, "left")
        compare(doc["DP-1"], undefined)
    }

    function test_a_placement_does_not_touch_the_global_preference() {
        var mode = makeMode()
        mode.tab = "bar"
        var prefs = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarPosition").selected("right")
        wait(20)
        for (var i = 0; i < prefs.count; i++)
            verify(prefs.signalArguments[i][0] !== "barEdge")
    }
}
