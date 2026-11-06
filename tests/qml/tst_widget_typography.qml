import QtQuick
import QtTest
import "../../bar/layouts.js" as Layouts

// The per-widget typography of the desktop and panel documents (bar.ini
// `desktopLayout` / `panelLayout`): a font family ("" inherits), a weight
// ("" inherit, regular, medium, bold) and italic. bar/layouts.js validates and
// normalises every value and keeps the rest of the widget setting.
TestCase {
    name: "WidgetTypography"

    function test_a_new_desktop_widget_inherits_the_typography() {
        var widget = Layouts.desktopAdd([], "clock", 0.2, 0.3)[0]
        compare(widget.font, "")
        compare(widget.weight, "")
        compare(widget.italic, false)
    }

    function test_a_desktop_document_keeps_each_widgets_typography() {
        var text = JSON.stringify({
            monitors: {
                "DP-1": {
                    widgets: [
                        { id: "clock", x: 0.2, y: 0.3, size: "lg", style: "full",
                          font: " Inter ", weight: "bold", italic: true },
                        { id: "weather", x: 0.4, y: 0.5 }
                    ]
                }
            }
        })
        var widgets = Layouts.effective(text, "DP-1", null, "desktop").widgets
        compare(widgets[0].font, "Inter")
        compare(widgets[0].weight, "bold")
        compare(widgets[0].italic, true)
        compare(widgets[0].size, "lg")
        compare(widgets[0].style, "full")
        compare(widgets[1].font, "")
        compare(widgets[1].weight, "")
        compare(widgets[1].italic, false)
    }

    function test_invalid_typography_falls_back_to_inheriting() {
        var text = JSON.stringify({
            monitors: {
                "DP-1": {
                    widgets: [{
                        id: "clock", font: 42, weight: "heavy", italic: "yes"
                    }]
                }
            }
        })
        var widget = Layouts.effective(text, "DP-1", null, "desktop").widgets[0]
        compare(widget.font, "")
        compare(widget.weight, "")
        compare(widget.italic, false)
        compare(widget.size, "md")
        compare(widget.style, "")
    }

    function test_weights_are_normalised_and_italic_is_strict_boolean() {
        var text = JSON.stringify({
            monitors: {
                "DP-1": {
                    widgets: [
                        { id: "clock", weight: " Bold ", italic: true },
                        { id: "weather", weight: "Medium" },
                        { id: "resources", weight: "regular", italic: 1 },
                        { id: "calendar", weight: "nonsense" }
                    ]
                }
            }
        })
        var widgets = Layouts.effective(text, "DP-1", null, "desktop").widgets
        compare(widgets[0].weight, "bold")
        compare(widgets[0].italic, true)
        compare(widgets[1].weight, "medium")
        compare(widgets[2].weight, "regular")
        compare(widgets[2].italic, false)
        compare(widgets[3].weight, "")
    }

    function test_configure_sets_one_typography_field_and_keeps_the_rest() {
        var widgets = Layouts.desktopAdd([], "clock", 0.2, 0.3)
        widgets = Layouts.desktopConfigure(widgets, "clock", { size: "lg", style: "compact" })
        widgets = Layouts.desktopConfigure(widgets, "clock", { font: "Inter" })
        compare(widgets[0].font, "Inter")
        compare(widgets[0].size, "lg")
        compare(widgets[0].style, "compact")
        widgets = Layouts.desktopConfigure(widgets, "clock", { weight: "medium", italic: true })
        compare(widgets[0].font, "Inter")
        compare(widgets[0].weight, "medium")
        compare(widgets[0].italic, true)
        widgets = Layouts.desktopConfigure(widgets, "clock", { font: "", weight: "", italic: false })
        compare(widgets[0].font, "")
        compare(widgets[0].weight, "")
        compare(widgets[0].italic, false)
    }

    function test_configure_never_changes_the_input_or_an_unknown_widget() {
        var original = Layouts.desktopAdd([], "clock", 0.2, 0.3)
        var patched = Layouts.desktopConfigure(original, "clock", { font: "Inter", weight: "bold" })
        compare(original[0].font, "")
        compare(original[0].weight, "")
        compare(patched[0].font, "Inter")
        compare(Layouts.desktopConfigure(original, "ghost", { font: "Inter" })[0].font, "")
    }

    function test_invalid_patches_are_normalised_in_the_same_step() {
        var widgets = Layouts.desktopConfigure(Layouts.desktopAdd([], "clock", 0.5, 0.5),
                                               "clock",
                                               { font: " Inter ", weight: "Bold", italic: true })
        compare(widgets[0].font, "Inter")
        compare(widgets[0].weight, "bold")
        var broken = Layouts.desktopConfigure(widgets, "clock", { weight: "heavy", italic: "yes" })
        compare(broken[0].weight, "")
        compare(broken[0].italic, false)
    }

    function test_write_keeps_each_widgets_typography() {
        var widgets = Layouts.desktopAdd([], "clock", 0.1, 0.2)
        widgets = Layouts.desktopConfigure(widgets, "clock", { font: " Inter ", weight: "Bold", italic: true })
        var text = Layouts.write("", "DP-1", { widgets: widgets }, "desktop")
        var stored = Layouts.sanitize(text, "desktop").monitors["DP-1"].widgets[0]
        compare(stored.font, "Inter")
        compare(stored.weight, "bold")
        compare(stored.italic, true)
    }

    function test_panel_widgets_carry_the_same_typography() {
        var doc = Layouts.sanitize(JSON.stringify({
            widgets: {
                media: { size: "lg", style: "cassette", font: " Inter ",
                         weight: "medium", italic: true },
                notes: { font: 7, weight: "heavy", italic: "yes" }
            }
        }), "panel")
        compare(doc.widgets.media, { size: "lg", style: "cassette", font: "Inter",
                                     weight: "medium", italic: true })
        compare(doc.widgets.notes, { size: "md", style: "", font: "",
                                     weight: "", italic: false })
        compare(Layouts.setting(doc, "media", "panel").font, "Inter")
        var widgets = Layouts.configure(doc.widgets, "media", { font: "", weight: "bold" }, "panel")
        compare(widgets.media.font, "")
        compare(widgets.media.weight, "bold")
        compare(widgets.media.size, "lg")
    }

    function test_a_panel_document_written_from_the_editor_keeps_typography() {
        var widgets = Layouts.configure({}, "notes", { font: "Inter", weight: "regular",
                                                       italic: true }, "panel")
        var text = Layouts.write("", "", { widgets: widgets }, "panel")
        compare(Layouts.sanitize(text, "panel").widgets.notes,
                { size: "md", style: "", font: "Inter", weight: "regular", italic: true })
        compare(Layouts.effective(text, "", null, "panel").widgets.notes.font, "Inter")
    }
}
