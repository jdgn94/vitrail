import QtQuick
import QtQml
import QtTest
import "../../kit"
import "../../kit/base"

// One resolver for every icon: a known name draws itself, an unknown or empty
// one draws `question_mark`, and the family / FILL it draws with follow the
// icon style the user picked.
TestCase {
    id: testCase

    name: "IconResolver"

    VitrailText {
        id: known

        variant: "icon"
        icon: "wifi"
    }

    VitrailText {
        id: misspelt

        variant: "icon"
        icon: "wiffi"
    }

    VitrailText {
        id: plain

        variant: "body"
        text: "wiffi"
    }

    VitrailIcon {
        id: primitive

        icon: "settings"
    }

    VitrailIcon {
        id: primitiveUnknown

        icon: "nope_not_an_icon"
    }

    function init() {
        VitrailTokens.iconVariant = "rounded"
        VitrailTokens.iconFill = 0
    }

    function test_a_known_name_resolves_to_itself() {
        compare(VitrailIcons.resolve("wifi"), "wifi")
        compare(VitrailIcons.resolve("settings"), "settings")
        compare(VitrailIcons.available("wifi"), true)
    }

    function test_an_unknown_or_empty_name_is_the_question_mark() {
        compare(VitrailIcons.resolve("wiffi"), "question_mark")
        compare(VitrailIcons.resolve(""), "question_mark")
        compare(VitrailIcons.resolve("   "), "question_mark")
        compare(VitrailIcons.resolve(undefined), "question_mark")
        compare(VitrailIcons.available("wiffi"), false)
        compare(VitrailIcons.resolve(VitrailIcons.fallback), VitrailIcons.fallback)
    }

    function test_the_name_is_normalized_before_looking_it_up() {
        compare(VitrailIcons.resolve("  WiFi "), "wifi")
        // Inherited object members are not icons.
        compare(VitrailIcons.available("constructor"), false)
        compare(VitrailIcons.resolve("__proto__"), "question_mark")
    }

    function test_the_drawn_text_goes_through_the_resolver() {
        compare(known.text, "wifi")
        compare(misspelt.text, "question_mark")
        compare(primitive.glyph, "settings")
        compare(primitiveUnknown.glyph, "question_mark")
        // Plain text is untouched: no icon, no question mark.
        compare(plain.text, "wiffi")
    }

    function test_the_active_style_is_the_token_style() {
        compare(VitrailIcons.style.family, VitrailTokens.iconFamily)
        compare(VitrailIcons.style.fill, VitrailTokens.iconFill)

        VitrailTokens.iconVariant = "sharp"
        VitrailTokens.iconFill = 1
        compare(VitrailIcons.style.family, "Material Symbols Sharp")
        compare(VitrailIcons.style.fill, 1)
        // The drawn glyph follows the same style.
        compare(known.fontInfo.family, "Material Symbols Sharp")
        compare(known.font.variableAxes["FILL"], 1)
    }
}
