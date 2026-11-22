import QtQuick
import QtTest
import "../../bar/desktop"
import "../../bar/layouts.js" as Layouts
import "../../bar/elements.js" as Elements
import "../../kit"

// The editor's bar preview is the bar: the strip alone, the real element
// buttons with the registry's glyph, the bar's chip and divider, the bar's
// edge and style, hidden elements dimmed and the drop target marked.
TestCase {
    id: testCase

    name: "BarPreview"
    when: windowShown
    visible: true
    width: 1200
    height: 900

    VitrailPalette {
        id: palette
    }

    Component {
        id: previewComponent

        BarPreview {
            width: 1100
            height: 800
            strings: ({})
        }
    }

    function initTestCase() {
        VitrailTokens.configure({
            surface: palette.surface,
            surfaceHigh: palette.surfaceHigh,
            foreground: palette.foreground,
            muted: palette.muted,
            primary: palette.primary,
            accentForeground: palette.accentForeground
        }, true, "glass", ({}))
    }

    function documentWith(patch) {
        var doc = Layouts.effective("", "", null, "bar")
        for (var key in patch)
            doc[key] = patch[key]
        return doc
    }

    // The document is assigned after creation: passed as a creation property
    // it would arrive as a QVariantMap whose lists are no longer JS arrays.
    function make(properties) {
        var doc = properties.doc
        delete properties.doc
        var preview = createTemporaryObject(previewComponent, testCase, properties)
        verify(preview !== null)
        preview.doc = doc
        wait(20)
        return preview
    }

    function element(preview, id) {
        return findChild(preview, "barPreviewElement-" + id)
    }

    function test_an_element_is_drawn_as_its_own_bar_button() {
        var preview = make({ doc: documentWith({}), edge: "top" })
        var clock = element(preview, "clock")
        var g = findChild(preview, "barPreviewGroup-center")
        verify(clock !== null)
        verify(clock.visible)
        // A BarElementBase, with the registry's glyph, at the bar's size.
        verify(clock.shown !== undefined)
        compare(clock.icon, Elements.icon("clock"))
        compare(clock.icon, "schedule")
        compare(clock.size, "sm")
        compare(clock.opacity, 1)
    }

    function test_a_chip_is_the_bars_pill_around_its_members() {
        var preview = make({ doc: documentWith({}), edge: "top" })
        var chip = findChild(preview, "barPreviewChip-connections")
        verify(chip !== null)
        verify(chip.visible)
        compare(chip.ids, ["network", "bluetooth", "vpn", "profile"])
        var member = element(chip, "network")
        verify(member !== null)
        compare(member.icon, Elements.icon("network"))
    }

    function test_a_divider_is_the_bars_hairline() {
        var doc = documentWith({})
        doc.order.center = ["title", "divider", "clock"]
        var preview = make({ doc: doc, edge: "top" })
        var divider = findChild(preview, "barPreviewDivider-divider")
        verify(divider !== null)
        verify(divider.visible)
        verify(findChild(divider, "barDividerLine") !== null)
    }

    function test_a_hidden_element_is_drawn_dimmed_not_left_out() {
        var preview = make({ doc: documentWith({ hidden: ["clock"] }), edge: "top" })
        var clock = element(preview, "clock")
        verify(clock !== null)
        verify(clock.visible)
        compare(clock.opacity, VitrailTokens.barPreview.hidden)
        verify(preview.anyHidden)
        preview.doc = documentWith({ hidden: [] })
        wait(10)
        verify(!preview.anyHidden)
        compare(element(preview, "clock").opacity, 1)
    }

    function test_a_hidden_chip_member_is_dimmed_inside_the_pill() {
        var preview = make({ doc: documentWith({ hidden: ["vpn"] }), edge: "top" })
        var chip = findChild(preview, "barPreviewChip-connections")
        compare(element(chip, "vpn").opacity, VitrailTokens.barPreview.hidden)
        compare(element(chip, "network").opacity, 1)
    }

    function test_a_drag_marks_the_group_or_chip_it_would_land_in() {
        var preview = make({ doc: documentWith({}), edge: "top" })
        verify(!findChild(preview, "barPreviewTarget-end").visible)
        preview.target = { kind: "group", group: "end", index: 0 }
        wait(10)
        verify(findChild(preview, "barPreviewTarget-end").visible)
        verify(!findChild(preview, "barPreviewTarget-start").visible)
        preview.target = { kind: "chip", chip: "connections", index: 0 }
        wait(10)
        verify(!findChild(preview, "barPreviewTarget-end").visible)
        verify(findChild(preview, "barPreviewChipTarget-connections").visible)
    }

    function test_the_strip_follows_the_edge() {
        var preview = make({ doc: documentWith({}), edge: "top" })
        var strip = findChild(preview, "barPreviewStrip")
        verify(!preview.vertical)
        verify(strip.width > strip.height)
        compare(strip.height, VitrailTokens.bar)
        verify(preview.implicitHeight > 0)
        preview.edge = "left"
        wait(10)
        verify(preview.vertical)
        verify(strip.height > strip.width)
        compare(strip.width, VitrailTokens.bar)
        verify(preview.implicitWidth > 0)
        compare(findChild(preview, "barPreviewGroup-start").flow, 1) // TopToBottom
    }

    function test_docked_is_square_and_floating_is_an_island() {
        var preview = make({ doc: documentWith({}), edge: "top", variant: "docked" })
        var surface = findChild(preview, "barPreviewSurface")
        compare(surface.radius, 0)
        compare(preview.inset, 0)
        preview.variant = "floating"
        wait(10)
        compare(surface.radius, VitrailTokens.radius)
        verify(preview.inset > 0)
    }

    function test_the_density_tightens_the_gaps() {
        var preview = make({ doc: documentWith({ density: "comfortable" }), edge: "top" })
        var wide = preview.gap
        preview.doc = documentWith({ density: "compact" })
        wait(10)
        verify(preview.gap < wide)
    }

    function test_a_long_bar_shrinks_to_fit_its_box() {
        var preview = make({ doc: documentWith({ hidden: [] }), edge: "left" })
        preview.height = 200
        wait(10)
        verify(preview.fit < 1)
        verify(preview.naturalLength * preview.fit <= 200)
    }
}
