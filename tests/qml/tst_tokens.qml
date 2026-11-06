import QtQuick
import QtQml
import QtTest
import "../../kit"
import "../../kit/base"

// The user-tunable tokens: the font family and the icon family travel with the
// preferences, and an unknown icon variant falls back instead of inventing a
// family name the font stack does not have.
TestCase {
    id: testCase

    name: "Tokens"

    // The path main.qml and the bar use: the stored key is bound to the token,
    // the token derives the family, and every Text follows without a restart.
    QtObject {
        id: source

        property string uiIcons: "rounded"
    }

    Binding {
        target: VitrailTokens
        property: "iconVariant"
        value: VitrailTokens.font.iconVariantOf(source.uiIcons)
    }

    VitrailText {
        id: glyph

        variant: "icon"
        text: "settings"
    }

    function init() {
        source.uiIcons = "rounded"
    }

    function test_every_icon_variant_names_an_installed_family() {
        compare(VitrailTokens.font.iconVariants.rounded, "Material Symbols Rounded")
        compare(VitrailTokens.font.iconVariants.sharp, "Material Symbols Sharp")
        compare(VitrailTokens.font.iconVariants.outlined, "Material Symbols Outlined")
    }

    function test_an_unknown_icon_variant_falls_back_to_rounded() {
        compare(VitrailTokens.font.iconVariantOf("nope"), "rounded")
        compare(VitrailTokens.font.iconVariantOf("sharp"), "sharp")
        compare(VitrailTokens.font.iconFamilyOf("nope"), "Material Symbols Rounded")
        compare(VitrailTokens.font.iconFamilyOf("outlined"), "Material Symbols Outlined")
        // Inherited object members are not variants.
        compare(VitrailTokens.font.iconVariantOf("constructor"), "rounded")
        compare(VitrailTokens.font.iconVariantOf("__proto__"), "rounded")
        compare(VitrailTokens.font.iconVariantOf("toString"), "rounded")
    }

    function test_the_family_is_derived_from_the_variant() {
        VitrailTokens.iconVariant = "sharp"
        compare(VitrailTokens.iconFamily, "Material Symbols Sharp")
        VitrailTokens.iconVariant = "outlined"
        compare(VitrailTokens.iconFamily, "Material Symbols Outlined")
        VitrailTokens.iconVariant = "rounded"
        compare(VitrailTokens.iconFamily, "Material Symbols Rounded")
    }

    function test_changing_the_preference_reaches_the_drawn_face() {
        source.uiIcons = "rounded"
        compare(glyph.font.family, "Material Symbols Rounded")
        // `fontInfo` is the face Qt resolved and shapes with, not the request.
        compare(glyph.fontInfo.family, "Material Symbols Rounded")
        source.uiIcons = "sharp"
        compare(glyph.font.family, "Material Symbols Sharp")
        compare(glyph.fontInfo.family, "Material Symbols Sharp")
        source.uiIcons = "outlined"
        compare(glyph.fontInfo.family, "Material Symbols Outlined")
    }

    function test_icons_are_never_filled() {
        source.uiIcons = "sharp"
        // The glyph stays outlined: the variant changes the shape, never FILL.
        verify(glyph.font.variableAxes["FILL"] === undefined)
    }

    function test_the_cursor_range_is_the_token_range() {
        compare(VitrailTokens.ranges.cursor.value, 24)
        compare(VitrailTokens.ranges.cursor.min, 16)
        compare(VitrailTokens.ranges.cursor.max, 64)
    }
}
