import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"

// The user-tunable tokens: the font family and the icon family travel with the
// preferences, and an unknown icon variant falls back instead of inventing a
// family name the font stack does not have.
TestCase {
    name: "Tokens"

    // The path main.qml and the bar use: a preference changes, the token
    // values change, and the Text items follow without a restart.
    QtObject {
        id: source

        property string uiIcons: "rounded"
    }

    QtObject {
        id: live

        readonly property var tokenValues: ({
            iconFamily: VitrailTokens.font.iconFamilyOf(source.uiIcons)
        })
        onTokenValuesChanged: VitrailTokens.configure({}, true, "glass", live.tokenValues)
    }

    VitrailText {
        id: glyph

        variant: "icon"
        text: "interests"
    }

    function test_every_icon_variant_names_an_installed_family() {
        compare(VitrailTokens.font.iconVariants.rounded, "Material Symbols Rounded")
        compare(VitrailTokens.font.iconVariants.sharp, "Material Symbols Sharp")
        compare(VitrailTokens.font.iconVariants.outlined, "Material Symbols Outlined")
    }

    function test_an_unknown_icon_variant_falls_back_to_rounded() {
        compare(VitrailTokens.font.iconFamilyOf("nope"), "Material Symbols Rounded")
        compare(VitrailTokens.font.iconFamilyOf("sharp"), "Material Symbols Sharp")
        // Inherited object members are not variants.
        compare(VitrailTokens.font.iconFamilyOf("constructor"), "Material Symbols Rounded")
        compare(VitrailTokens.font.iconFamilyOf("__proto__"), "Material Symbols Rounded")
        compare(VitrailTokens.font.iconFamilyOf("toString"), "Material Symbols Rounded")
    }

    function test_configure_carries_the_font_and_icon_family() {
        VitrailTokens.configure({}, true, "glass",
                                { fontFamily: "Inter", iconFamily: "Material Symbols Sharp" })
        compare(VitrailTokens.fontFamily, "Inter")
        compare(VitrailTokens.iconFamily, "Material Symbols Sharp")
        VitrailTokens.configure({}, true, "glass",
                                { fontFamily: "Roboto", iconFamily: "Material Symbols Rounded" })
    }

    function test_changing_the_variant_reaches_the_ui() {
        source.uiIcons = "rounded"
        compare(VitrailTokens.iconFamily, "Material Symbols Rounded")
        compare(glyph.font.family, "Material Symbols Rounded")
        source.uiIcons = "sharp"
        compare(VitrailTokens.iconFamily, "Material Symbols Sharp")
        compare(glyph.font.family, "Material Symbols Sharp")
        // The glyph stays outlined: the variant changes the shape, not FILL.
        compare(glyph.font.variableAxes["FILL"], 0)
    }

    function test_the_cursor_range_is_the_token_range() {
        compare(VitrailTokens.ranges.cursor.value, 24)
        compare(VitrailTokens.ranges.cursor.min, 16)
        compare(VitrailTokens.ranges.cursor.max, 64)
    }
}
