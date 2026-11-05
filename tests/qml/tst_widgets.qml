import QtQuick
import QtTest
import "../../bar/widgets.js" as Widgets
import "../../bar/layouts.js" as Layouts

// The shared widget registry (bar/widgets.js) and the flat panel document
// (bar.ini `panelLayout`). The panel's empty document is today's panel.
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
        for (var i = 0; i < ["clock", "weather", "resources", "pomodoro", "calendar"].length; i++)
            verify(desktop.indexOf(["clock", "weather", "resources", "pomodoro", "calendar"][i]) >= 0)
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
}
