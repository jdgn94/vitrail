import QtQuick
import QtTest
import "../../bar/desktop"
import "../../bar/layouts.js" as Layouts
import "../../kit"

// The in-place editor's Bar and Panel tabs: the bar's groups, chips, dividers,
// visibility, density and per-monitor override, and the panel's widgets with
// their order, size, style and typography. Every edit is one whole document
// write, and the document is what the real bar and panel read.
TestCase {
    id: testCase

    name: "EditorBarPanel"
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

    function makeMode() {
        var mode = createTemporaryObject(modeComponent, testCase, { active: true })
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

    function barTab(mode) {
        return findChild(mode, "editorBarTab")
    }

    function panelTab(mode) {
        return findChild(mode, "editorPanelTab")
    }

    function barDocument(spy) {
        return Layouts.sanitize(lastText(spy))
    }

    function panelDocument(spy) {
        return Layouts.sanitize(lastText(spy), "panel")
    }

    // --- the two tabs ---------------------------------------------------------

    function test_the_bar_and_panel_tabs_are_editors_not_notices() {
        var mode = makeMode()
        compare(mode.tabs.map(function (tab) { return tab.key }),
                ["bar", "desktop", "dock", "panel"])
        mode.tab = "bar"
        wait(20)
        verify(barTab(mode).visible)
        verify(findChild(mode, "editorBarGroup-clock") !== null)
        mode.tab = "panel"
        wait(20)
        verify(panelTab(mode).visible)
        verify(findChild(mode, "editorPanelCard.media") !== null)
    }

    // --- the bar's groups, chips and dividers --------------------------------

    function test_the_group_selector_moves_an_element_between_groups() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        var picker = findChild(mode, "editorBarGroup-clock")
        verify(picker !== null)
        verify(picker.visible)
        picker.selected("start")
        wait(20)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "bar")
        var doc = barDocument(spy)
        verify(doc.order.start.indexOf("clock") >= 0)
        compare(doc.order.center.indexOf("clock"), -1)
    }

    function test_a_fixed_element_keeps_its_group_and_has_no_selector() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        var picker = findChild(mode, "editorBarGroup-launcher")
        verify(picker !== null)
        verify(!picker.visible)
        compare(barTab(mode).entryDescription("launcher"), "bar.editor.fixed")
        barTab(mode).moveEntry("launcher", "end")
        compare(spy.count, 0)
    }

    function test_a_divider_is_added_and_removed_inside_a_group() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarAddDivider-center").clicked()
        wait(20)
        var doc = barDocument(spy)
        compare(doc.order.center[doc.order.center.length - 1], "divider")
        findChild(mode, "editorBarRemove-divider").clicked()
        wait(20)
        doc = barDocument(spy)
        compare(doc.order.center.indexOf("divider"), -1)
    }

    function test_a_divider_moves_to_another_group() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarAddDivider-center").clicked()
        wait(20)
        findChild(mode, "editorBarGroup-divider").selected("start")
        wait(20)
        var doc = barDocument(spy)
        verify(doc.order.start.indexOf("divider") >= 0)
        compare(doc.order.center.indexOf("divider"), -1)
    }

    function test_a_chip_is_created_filled_and_removed() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarAddChip-end").clicked()
        wait(20)
        var doc = barDocument(spy)
        verify(doc.chips["chip-1"] !== undefined)
        compare(doc.chips["chip-1"].members, [])
        verify(doc.order.end.indexOf("@chip-1") >= 0)

        findChild(mode, "editorBarChipAdd-chip-1-clock").clicked()
        wait(20)
        doc = barDocument(spy)
        compare(doc.chips["chip-1"].members, ["clock"])
        compare(doc.order.center.indexOf("clock"), -1)

        findChild(mode, "editorBarChipRemove-chip-1-clock").clicked()
        wait(20)
        doc = barDocument(spy)
        compare(doc.chips["chip-1"].members, [])
        var at = doc.order.end.indexOf("@chip-1")
        compare(doc.order.end[at + 1], "clock")

        findChild(mode, "editorBarRemove-@chip-1").clicked()
        wait(20)
        doc = barDocument(spy)
        compare(doc.chips["chip-1"], undefined)
        compare(doc.order.end.indexOf("@chip-1"), -1)
    }

    function test_visibility_survives_a_move_between_groups() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        var toggle = findChild(mode, "editorBarVisible-clock")
        verify(toggle !== null)
        toggle.toggled(false)
        wait(20)
        verify(barDocument(spy).hidden.indexOf("clock") >= 0)
        findChild(mode, "editorBarGroup-clock").selected("start")
        wait(20)
        var doc = barDocument(spy)
        verify(doc.hidden.indexOf("clock") >= 0)
        verify(doc.order.start.indexOf("clock") >= 0)
    }

    function test_density_and_fullscreen_are_written_globally() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarDensity").selected("compact")
        wait(20)
        compare(barDocument(spy).density, "compact")
        findChild(mode, "editorBarFullscreen").toggled(false)
        wait(20)
        compare(barDocument(spy).hideFullscreen, false)
    }

    function test_a_monitor_override_leaves_the_global_bar_alone() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarMonitor").selected("DP-1")
        wait(20)
        findChild(mode, "editorBarGroup-clock").selected("start")
        wait(20)
        var doc = barDocument(spy)
        verify(doc.monitors["DP-1"].order.start.indexOf("clock") >= 0)
        verify(doc.order.center.indexOf("clock") >= 0)
    }

    // --- the bar's own options moved out of Settings -------------------------

    function test_the_bar_options_write_their_preferences() {
        var mode = makeMode()
        mode.tab = "bar"
        var spy = watch(prefSpyComponent, mode)
        wait(20)
        findChild(mode, "editorBarEdge").selected("right")
        compare(spy.signalArguments[0][0], "barEdge")
        compare(spy.signalArguments[0][1], "right")
        findChild(mode, "editorBarStyle").selected("floating")
        compare(spy.signalArguments[1][0], "barStyle")
        compare(spy.signalArguments[1][1], "floating")
        findChild(mode, "editorBarOpacityMode").selected("own")
        compare(spy.signalArguments[2][0], "barOpacityFollow")
        compare(spy.signalArguments[2][1], false)
    }

    // --- the panel ------------------------------------------------------------

    function test_the_panel_widget_writes_size_style_and_typography() {
        var mode = makeMode()
        mode.tab = "panel"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorPanelSize.media").selected("lg")
        wait(20)
        findChild(mode, "editorPanelStyle.media").selected("cassette")
        wait(20)
        findChild(mode, "editorPanelFont.media").selected("Inter")
        wait(20)
        findChild(mode, "editorPanelWeight.media").selected("bold")
        wait(20)
        findChild(mode, "editorPanelItalic.media").toggled(true)
        wait(20)
        var doc = panelDocument(spy)
        compare(doc.widgets.media.size, "lg")
        compare(doc.widgets.media.style, "cassette")
        compare(doc.widgets.media.font, "Inter")
        compare(doc.widgets.media.weight, "bold")
        compare(doc.widgets.media.italic, true)
        compare(spy.signalArguments[spy.count - 1][0], "panel")
    }

    function test_the_panel_order_and_visibility_are_one_document() {
        var mode = makeMode()
        mode.tab = "panel"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        var before = Layouts.sanitize(mode.panelText, "panel").order
        findChild(mode, "editorPanelDown.media").clicked()
        wait(20)
        var doc = panelDocument(spy)
        compare(doc.order.indexOf("media"), 1)
        findChild(mode, "editorPanelVisible.toggles").toggled(false)
        wait(20)
        doc = panelDocument(spy)
        verify(doc.hidden.indexOf("toggles") >= 0)
        compare(doc.order.length, before.length)
    }

    function test_the_panel_document_is_valid_and_round_trips() {
        var mode = makeMode()
        mode.tab = "panel"
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        findChild(mode, "editorPanelSize.notes").selected("sm")
        wait(20)
        var text = lastText(spy)
        var effective = Layouts.effective(text, "", null, "panel")
        compare(effective.hidden, [])
        compare(effective.widgets.notes.size, "sm")
        compare(Layouts.sanitize(text, "panel").widgets.notes.size, "sm")
    }
}
