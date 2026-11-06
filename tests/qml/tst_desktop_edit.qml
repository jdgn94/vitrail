import QtQuick
import QtTest
import "../../bar/desktop"
import "../../bar/layouts.js" as Layouts
import "../../bar/widgets.js" as Widgets
import "../../bar/desktop/desktopEditor.js" as Editor
import "../../bar/desktop/policy.js" as Policy
import "../../kit"

// The desktop's in-place editor: the right-click menu, the global edit flag,
// the three tabs, the palette (four widgets, three variants each), dragging,
// resizing, typography, the fullscreen policy and both ways out.
TestCase {
    id: testCase

    name: "DesktopEdit"
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
        }
    }

    Component {
        id: menuComponent

        DesktopMenu {
            strings: ({})
        }
    }

    Component {
        id: catcherComponent

        DesktopClickCatcher {
            width: 400
            height: 300
        }
    }

    Component {
        id: editSpyComponent

        SignalSpy { signalName: "editRequested" }
    }

    Component {
        id: changedSpyComponent

        SignalSpy { signalName: "layoutChanged" }
    }

    Component {
        id: finishedSpyComponent

        SignalSpy { signalName: "finished" }
    }

    Component {
        id: menuSpyComponent

        SignalSpy { signalName: "menuRequested" }
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
        var values = extra || ({})
        var mode = createTemporaryObject(modeComponent, testCase, values)
        verify(mode !== null)
        return mode
    }

    function watch(component, target) {
        return createTemporaryObject(component, testCase, { target: target })
    }

    function lastText(spy) {
        return spy.signalArguments[spy.count - 1][0]
    }

    function apply(mode, spy) {
        var text = lastText(spy)
        mode.layoutText = text
        return Layouts.effective(text, "DP-1", null, "desktop").widgets
    }

    // --- the right-click menu -------------------------------------------------

    function test_the_context_menu_offers_edit() {
        var menu = createTemporaryObject(menuComponent, testCase)
        var spy = watch(editSpyComponent, menu)
        var button = findChild(menu, "desktopMenuEdit")
        verify(button !== null)
        compare(spy.count, 0)
        mouseClick(button, button.width / 2, button.height / 2)
        compare(spy.count, 1)
    }

    function test_the_desktop_takes_the_secondary_button() {
        var catcher = createTemporaryObject(catcherComponent, testCase)
        var spy = watch(menuSpyComponent, catcher)
        mouseClick(catcher, 24, 32, Qt.RightButton)
        compare(spy.count, 1)
        compare(Math.round(spy.signalArguments[0][0]), 24)
        compare(Math.round(spy.signalArguments[0][1]), 32)
        mouseClick(catcher, 10, 10, Qt.LeftButton)
        compare(spy.count, 1)
    }

    // --- the flag and the three tabs -----------------------------------------

    function test_the_edit_flag_shows_and_hides_the_container() {
        var mode = makeMode()
        verify(!mode.visible)
        mode.active = true
        tryCompare(mode, "progress", 1, 1000)
        verify(mode.visible)
        mode.active = false
        tryCompare(mode, "progress", 0, 1000)
        verify(!mode.visible)
    }

    function test_the_three_tabs_put_the_desktop_in_the_middle() {
        var mode = makeMode({ active: true })
        wait(20)
        compare(mode.tabs.map(function (tab) { return tab.key }), ["bar", "desktop", "panel"])
        compare(mode.tab, "desktop")
        var tabs = findChild(mode, "desktopEditTabs")
        verify(tabs !== null)
        compare(tabs.current, "desktop")
        mode.tab = "bar"
        wait(20)
        compare(tabs.current, "bar")
        verify(!findChild(mode, "desktopEditPalette").visible)
        mode.tab = "panel"
        wait(20)
        compare(tabs.current, "panel")
        mode.tab = "desktop"
        wait(20)
        verify(findChild(mode, "desktopEditPalette").visible)
    }

    // --- the palette ----------------------------------------------------------

    function test_the_palette_lists_four_widgets_with_three_variants_each() {
        var mode = makeMode({ active: true })
        wait(20)
        compare(mode.paletteWidgets, ["clock", "media", "image", "notes"])
        for (var i = 0; i < mode.paletteWidgets.length; i++) {
            var id = mode.paletteWidgets[i]
            compare(mode.variants(id).length, 3, id)
            verify(findChild(mode, "desktopPalette." + id) !== null, id)
        }
        verify(findChild(mode, "desktopPalette.clock") !== null)
        mode.chooseWidget("clock")
        wait(20)
        for (var j = 0; j < mode.variants("clock").length; j++) {
            var style = mode.variants("clock")[j]
            verify(findChild(mode, "desktopVariant.clock." + style) !== null, style)
        }
    }

    function test_choosing_a_variant_places_the_widget_and_writes_the_document() {
        var mode = makeMode({ active: true, layoutText: "" })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("clock", "compact")
        compare(spy.count, 1)
        var widgets = apply(mode, spy)
        compare(widgets.length, 1)
        compare(widgets[0].id, "clock")
        compare(widgets[0].style, "compact")
        compare(mode.selection, "clock")
    }

    function test_a_placed_widget_takes_the_new_variant_without_moving() {
        var start = JSON.stringify({
            monitors: { "DP-1": { widgets: [
                { id: "media", x: 0.2, y: 0.3, size: "lg", style: "disc" }
            ] } }
        })
        var mode = makeMode({ active: true, layoutText: start })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("media", "minimal")
        var widgets = apply(mode, spy)
        compare(widgets.length, 1)
        compare(widgets[0].x, 0.2)
        compare(widgets[0].y, 0.3)
        compare(widgets[0].size, "lg")
        compare(widgets[0].style, "minimal")
    }

    // --- drag, resize and typography -----------------------------------------

    function test_a_drag_keeps_the_card_inside_the_desktop() {
        var corner = Editor.moveTo(-50, -50, 100, 50, 500, 400)
        compare(corner.x, 0)
        compare(corner.y, 0)
        corner = Editor.moveTo(900, 900, 100, 50, 500, 400)
        compare(corner.x, 0.8)
        compare(corner.y, 0.875)
        corner = Editor.moveTo(100, 50, 100, 50, 500, 400)
        compare(corner.x, 0.2)
        compare(corner.y, 0.125)

        var start = JSON.stringify({
            monitors: { "DP-1": { widgets: [{ id: "clock", x: 0.2, y: 0.2 }] } }
        })
        var mode = makeMode({ active: true, layoutText: start })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.moveWidget("clock", 400, 300, 200, 80, 1000, 600)
        var widgets = apply(mode, spy)
        compare(widgets[0].x, 0.4)
        compare(widgets[0].y, 0.5)
        mode.moveWidget("clock", -80, 900, 200, 80, 1000, 600)
        widgets = apply(mode, spy)
        compare(widgets[0].x, 0)
        compare(widgets[0].y, 1 - 80 / 600)
    }

    function test_a_corner_drag_maps_to_the_registry_size() {
        compare(Widgets.sizeForWidth("clock", 1), "sm")
        compare(Widgets.sizeForWidth("clock", 2000), "lg")
        compare(Widgets.sizeForWidth("clock", Widgets.widthOf("clock", "md")), "md")

        var mode = makeMode({ active: true, layoutText: "" })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("image", "cover")
        apply(mode, spy)
        mode.resizeWidget("image", 2000)
        var widgets = apply(mode, spy)
        compare(widgets[0].size, "lg")
        mode.resizeWidget("image", 1)
        widgets = apply(mode, spy)
        compare(widgets[0].size, "sm")
        verify(findChild(mode, "desktopResizeHandle") !== null)
    }

    function test_the_inspector_writes_font_weight_and_italic() {
        var mode = makeMode({ active: true, layoutText: "" })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("notes", "plain")
        apply(mode, spy)
        compare(mode.fontOptions().map(function (option) { return option.key }),
                ["", "Inter", "DejaVu Sans"])
        compare(mode.weightOptions().length, 4)
        mode.setFont("notes", "DejaVu Sans")
        apply(mode, spy)
        mode.setWeight("notes", "bold")
        apply(mode, spy)
        mode.setItalic("notes", true)
        var widgets = apply(mode, spy)
        compare(widgets[0].font, "DejaVu Sans")
        compare(widgets[0].weight, "bold")
        compare(widgets[0].italic, true)
        verify(findChild(mode, "desktopEditInspector") !== null)
        verify(findChild(mode, "desktopEditFont") !== null)
    }

    function test_removing_the_selected_widget_clears_the_selection() {
        var mode = makeMode({ active: true, layoutText: "" })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("clock", "full")
        apply(mode, spy)
        mode.removeWidget("clock")
        var widgets = apply(mode, spy)
        compare(widgets.length, 0)
        compare(mode.selection, "")
    }

    // --- stale and empty documents -------------------------------------------

    function test_a_stale_or_empty_document_is_an_empty_desktop() {
        var bad = makeMode({ active: true, layoutText: "not json" })
        compare(bad.placed.length, 0)
        var stale = makeMode({ active: true, layoutText: JSON.stringify({
            monitors: { "DP-1": { widgets: [{ id: "ghost", x: 0.5, y: 0.5 }] } }
        }) })
        compare(stale.placed.length, 0)
        var clamped = makeMode({ active: true, layoutText: JSON.stringify({
            monitors: { "DP-1": { widgets: [{ id: "clock", x: 4, y: -4 }] } }
        }) })
        compare(clamped.placed.length, 1)
        compare(clamped.placed[0].x, 1)
        compare(clamped.placed[0].y, 0)
    }

    function test_another_monitor_is_left_alone() {
        var start = JSON.stringify({
            monitors: { "HDMI-A-1": { widgets: [{ id: "weather", x: 0.1, y: 0.1 }] } }
        })
        var mode = makeMode({ active: true, layoutText: start })
        var spy = watch(changedSpyComponent, mode)
        wait(20)
        mode.chooseVariant("clock", "minimal")
        var widgets = apply(mode, spy)
        compare(widgets.length, 1)
        var text = lastText(spy)
        compare(Layouts.desktopCount(text), 2)
        compare(Layouts.effective(text, "HDMI-A-1", null, "desktop").widgets[0].id, "weather")
    }

    // --- the fullscreen policy and the exit ----------------------------------

    function test_the_notification_panel_and_toasts_stay_out_of_fullscreen_and_the_editor() {
        verify(Policy.notificationsAllowed(false, false))
        verify(!Policy.notificationsAllowed(true, false))
        verify(!Policy.notificationsAllowed(false, true))
        verify(!Policy.notificationsAllowed(true, true))
        verify(Policy.toastsAllowed(false, false))
        verify(!Policy.toastsAllowed(true, false))
        verify(!Policy.toastsAllowed(false, true))
        verify(Policy.barDrawn(false, false))
        verify(!Policy.barDrawn(false, true))
        verify(!Policy.barDrawn(true, false))
        verify(Policy.barWindowAlive())
        verify(Policy.osdAllowed())
    }

    function test_done_and_escape_both_close_the_editor() {
        var mode = makeMode({ active: true })
        var spy = watch(finishedSpyComponent, mode)
        wait(20)
        mode.forceActiveFocus()
        wait(20)
        keyPress(Qt.Key_Escape)
        compare(spy.count, 1)
        var done = findChild(mode, "desktopEditDone")
        verify(done !== null)
        mouseClick(done, done.width / 2, done.height / 2)
        compare(spy.count, 2)
    }
}
