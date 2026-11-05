import QtQuick
import QtTest
import "../../bar/widgets.js" as Widgets
import "../../bar/layouts.js" as Layouts

// The shared widget registry (bar/widgets.js), the flat panel document
// (bar.ini `panelLayout`) and the per-monitor desktop document
// (bar.ini `desktopLayout`). An empty document is today's panel or no
// desktop widgets.
TestCase {
    name: "Widgets"

    readonly property var panelIds: ["media", "toggles", "capture", "notes", "session"]

    function test_the_registry_names_every_surface() {
        var panel = Widgets.WIDGETS.filter(function (widget) {
            return widget.surfaces.indexOf("panel") >= 0
        })
        compare(panel.map(function (widget) { return widget.id }), panelIds)
        var desktop = Widgets.WIDGETS.filter(function (widget) {
            return widget.surfaces.indexOf("desktop") >= 0
        }).map(function (widget) { return widget.id })
        var desktopIds = ["clock", "weather", "resources", "pomodoro", "timer", "calendar",
                          "media", "toggles", "notes"]
        for (var i = 0; i < desktopIds.length; i++)
            verify(desktop.indexOf(desktopIds[i]) >= 0, desktopIds[i])
        for (var j = 0; j < Widgets.WIDGETS.length; j++) {
            var widget = Widgets.WIDGETS[j]
            verify(widget.id !== "")
            verify(widget.labelKey !== "")
            verify(widget.icon !== "")
            verify(Array.isArray(widget.sizes))
            verify(Array.isArray(widget.styles))
            verify(widget.surfaces.length > 0)
        }
    }

    function test_the_empty_panel_document_is_todays_panel() {
        var doc = Layouts.sanitize("", "panel")
        compare(doc.order, panelIds)
        compare(doc.hidden, [])
        compare(doc.widgets, {})
        var effective = Layouts.effective("", "", null, "panel")
        compare(effective.order, panelIds)
        compare(effective.hidden, [])
        compare(effective.widgets, {})
    }

    function test_invalid_panel_json_is_the_default_document() {
        var bad = ["not json", "[]", "null", "1", '{"order":1}', '{"widgets":[]}']
        for (var i = 0; i < bad.length; i++)
            compare(JSON.stringify(Layouts.sanitize(bad[i], "panel")),
                    JSON.stringify(Layouts.defaults("panel")))
    }

    function test_unknown_and_duplicate_panel_ids_are_dropped() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: ["ghost", "session", "session", "media"],
            hidden: ["ghost", "notes", "notes"]
        }), "panel")
        compare(doc.order, ["session", "media", "toggles", "capture", "notes"])
        compare(doc.hidden, ["notes"])
    }

    function test_a_missing_panel_widget_returns_to_its_place() {
        var doc = Layouts.sanitize(JSON.stringify({ order: ["session", "media"] }), "panel")
        compare(doc.order, ["session", "media", "toggles", "capture", "notes"])
    }

    function test_widget_settings_default_to_medium_and_the_widget_style() {
        var setting = Layouts.setting(Layouts.defaults("panel"), "media", "panel")
        compare(setting.size, "md")
        compare(setting.style, "")
        var noWidget = Layouts.setting(Layouts.defaults("panel"), "ghost", "panel")
        compare(noWidget.size, "md")
        compare(noWidget.style, "")
    }

    function test_widget_settings_are_checked_against_the_registry() {
        var doc = Layouts.sanitize(JSON.stringify({
            widgets: {
                media: { size: "lg", style: "cassette" },
                notes: { size: "huge", style: "ghost" },
                ghost: { size: "sm", style: "disc" }
            }
        }), "panel")
        compare(doc.widgets.media, { size: "lg", style: "cassette" })
        compare(doc.widgets.notes, { size: "md", style: "" })
        compare(doc.widgets.ghost, undefined)
        compare(Layouts.setting(doc, "media", "panel").style, "cassette")
    }

    function test_configure_merges_one_widget_and_survives_validation() {
        var widgets = Layouts.configure(Layouts.defaults("panel").widgets, "media",
                                        { size: "lg" }, "panel")
        compare(widgets.media, { size: "lg", style: "" })
        widgets = Layouts.configure(widgets, "media", { style: "cassette" }, "panel")
        compare(widgets.media, { size: "lg", style: "cassette" })
        widgets = Layouts.configure(widgets, "media", { size: "nope", style: "nope" }, "panel")
        compare(widgets.media, { size: "md", style: "" })
        var original = Layouts.configure(Layouts.defaults("panel").widgets, "media",
                                         { size: "lg" }, "panel")
        compare(original.media.size, "lg")
        compare(widgets.media.size, "md")
    }

    function test_move_and_reorder_keep_the_panel_order_whole() {
        var order = Layouts.defaults("panel").order
        compare(Layouts.move(order, "notes", -1), ["media", "toggles", "notes", "capture", "session"])
        compare(Layouts.move(order, "media", 1), ["toggles", "media", "capture", "notes", "session"])
        compare(Layouts.move(order, "media", -1), panelIds)
        compare(Layouts.reorder(order, 0, 2), ["toggles", "capture", "media", "notes", "session"])
        compare(Layouts.reorder(order, 4, 0), ["session", "media", "toggles", "capture", "notes"])
        compare(Layouts.reorder(order, 0, 99), ["toggles", "capture", "notes", "session", "media"])
        compare(order, panelIds)
    }

    function test_toggle_and_write_the_panel_document() {
        var hidden = Layouts.toggle([], "notes")
        compare(hidden, ["notes"])
        var text = Layouts.write("", "", { hidden: hidden }, "panel")
        compare(Layouts.sanitize(text, "panel").hidden, ["notes"])
        compare(Layouts.write(text, "", { hidden: ["notes"] }, "panel"), null)

        text = Layouts.write("", "", { order: Layouts.reorder(panelIds, 0, 2) }, "panel")
        compare(Layouts.sanitize(text, "panel").order,
                ["toggles", "capture", "media", "notes", "session"])
        compare(Layouts.sanitize(text, "panel").hidden, [])
    }

    function test_write_records_widget_settings_and_keeps_the_rest() {
        var widgets = Layouts.configure({}, "media", { size: "lg", style: "cassette" }, "panel")
        var text = Layouts.write("", "", { order: Layouts.reorder(panelIds, 0, 1), widgets: widgets }, "panel")
        var doc = Layouts.sanitize(text, "panel")
        compare(doc.order, ["toggles", "media", "capture", "notes", "session"])
        compare(doc.widgets.media, { size: "lg", style: "cassette" })
        compare(Layouts.effective(text, "", null, "panel").widgets.media,
                { size: "lg", style: "cassette" })
    }

    function test_the_panel_well_known_registry_entries_keep_the_panels_services() {
        for (var i = 0; i < panelIds.length; i++) {
            var widget = Layouts.find(panelIds[i], "panel")
            verify(widget !== null, panelIds[i])
            compare(widget.labelKey.indexOf("panel.widget."), 0)
        }
        compare(Layouts.groups("panel"), [])
        compare(Layouts.widgets("panel").length, panelIds.length)
    }

    // --- the desktop document: widgets placed on each monitor ----------------

    function test_the_empty_desktop_document_has_no_widgets() {
        compare(Layouts.sanitize("", "desktop"), { monitors: {} })
        compare(Layouts.defaults("desktop"), { monitors: {} })
        compare(Layouts.effective("", "DP-1", null, "desktop"), { widgets: [] })
        compare(Layouts.desktopCount(""), 0)
    }

    function test_invalid_desktop_json_is_the_default_document() {
        var bad = ["not json", "[]", "null", "1", '{"monitors":[]}']
        for (var i = 0; i < bad.length; i++)
            compare(JSON.stringify(Layouts.sanitize(bad[i], "desktop")),
                    JSON.stringify(Layouts.defaults("desktop")))
    }

    function test_desktop_widgets_are_checked_and_placed_inside_the_monitor() {
        var text = JSON.stringify({
            monitors: {
                "DP-1": {
                    widgets: [
                        { id: "clock", x: -0.5, y: 2, size: "lg", style: "compact" },
                        { id: "clock", x: 0.2, y: 0.2 },
                        { id: "ghost", x: 0.1, y: 0.1 },
                        { id: "weather", size: "huge", style: "ghost" }
                    ]
                }
            }
        })
        var widgets = Layouts.effective(text, "DP-1", null, "desktop").widgets
        compare(widgets.length, 2)
        compare(widgets[0].id, "clock")
        compare(widgets[0].x, 0)
        compare(widgets[0].y, 1)
        compare(widgets[0].size, "lg")
        compare(widgets[0].style, "compact")
        compare(widgets[1].id, "weather")
        compare(widgets[1].x, 0.5)
        compare(widgets[1].y, 0.5)
        compare(widgets[1].size, "md")
        compare(widgets[1].style, "")
        compare(Layouts.effective(text, "HDMI-A-1", null, "desktop").widgets, [])
    }

    function test_desktop_add_remove_and_configure_never_change_the_input() {
        var widgets = Layouts.desktopAdd([], "clock", 0.25, 0.75)
        compare(widgets.length, 1)
        compare(widgets[0], { id: "clock", x: 0.25, y: 0.75, size: "md", style: "" })
        compare(Layouts.desktopAdd(widgets, "clock", 0.1, 0.1).length, 1)
        compare(Layouts.desktopAdd(widgets, "ghost", 0.1, 0.1).length, 1)
        widgets = Layouts.desktopConfigure(widgets, "clock", { size: "lg", style: "compact" })
        compare(widgets[0].size, "lg")
        compare(widgets[0].style, "compact")
        compare(Layouts.desktopRemove(widgets, "clock"), [])
        compare(Layouts.desktopAdd([], "clock", 0.25, 0.75)[0].x, 0.25)
    }

    function test_desktop_move_clamps_and_keeps_the_other_settings() {
        var widgets = Layouts.desktopAdd([], "weather", 0.5, 0.5)
        widgets = Layouts.desktopConfigure(widgets, "weather", { size: "sm" })
        widgets = Layouts.desktopMove(widgets, "weather", 1.4, -0.2)
        compare(widgets[0].x, 1)
        compare(widgets[0].y, 0)
        compare(widgets[0].size, "sm")
        compare(Layouts.desktopMove(widgets, "ghost", 0.1, 0.1)[0].x, 1)
    }

    function test_desktop_write_keeps_the_other_monitors_and_empty_entries() {
        var dp = Layouts.desktopAdd([], "clock", 0.1, 0.2)
        var text = Layouts.write("", "DP-1", { widgets: dp }, "desktop")
        compare(Layouts.sanitize(text, "desktop").monitors["DP-1"].widgets.length, 1)
        var hdmi = Layouts.desktopAdd([], "weather", 0.3, 0.4)
        text = Layouts.write(text, "HDMI-A-1", { widgets: hdmi }, "desktop")
        compare(Layouts.desktopCount(text), 2)
        compare(Layouts.write(text, "DP-1", { widgets: dp }, "desktop"), null)
        text = Layouts.write(text, "DP-1", { widgets: [] }, "desktop")
        compare(Layouts.sanitize(text, "desktop").monitors["DP-1"], undefined)
        compare(Layouts.sanitize(text, "desktop").monitors["HDMI-A-1"].widgets.length, 1)
    }
}
