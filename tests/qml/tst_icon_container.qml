import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"

// The container icon style: a circular badge behind the glyph, never a
// Material Symbols FILL. The badge keeps the outlined footprint, so turning
// the style on moves nothing.
TestCase {
    id: testCase

    name: "IconContainer"
    when: windowShown
    visible: true

    readonly property color badgeTone: "#a8c7fa"
    readonly property color ink: "#002f65"

    Component {
        id: iconComponent

        VitrailIcon {
            icon: "lan"
            size: "lg"
        }
    }

    function init() {
        VitrailTokens.configure({
            primary: testCase.badgeTone,
            accentForeground: testCase.ink,
            foreground: "#e6e1e5"
        }, true, "glass", ({}))
        VitrailTokens.iconVariant = "rounded"
        VitrailTokens.iconContainer = false
    }

    function test_outlined_draws_no_badge() {
        var icon = createTemporaryObject(iconComponent, testCase)
        verify(icon !== null)
        var badge = findChild(icon, "badge")
        verify(badge !== null)
        compare(badge.visible, false)
        compare(findChild(icon, "glyph").font.variableAxes["FILL"], 0)
    }

    function test_container_draws_a_circular_badge() {
        VitrailTokens.iconContainer = true
        var icon = createTemporaryObject(iconComponent, testCase)
        verify(icon !== null)
        var badge = findChild(icon, "badge")
        verify(badge !== null)
        compare(badge.visible, true)
        // Primary background, accentForeground glyph: the badge owns its ink.
        compare(badge.color.toString(), testCase.badgeTone.toString())
        var glyph = findChild(icon, "glyph")
        compare(glyph.color.toString(), testCase.ink.toString())
        // A circle, never a rounded rectangle.
        compare(badge.width, badge.height)
        compare(badge.radius, badge.width / 2)
        // The badge never grows past the icon's own footprint.
        verify(badge.width <= icon.width + 0.01)
        // The glyph is smaller inside it, and still outlined.
        compare(glyph.scale, VitrailTokens.icon.scale)
        compare(glyph.font.variableAxes["FILL"], 0)
    }

    function test_the_footprint_is_the_outlined_one() {
        VitrailTokens.iconContainer = false
        var outlined = createTemporaryObject(iconComponent, testCase)
        var width = outlined.implicitWidth
        var height = outlined.implicitHeight
        var glyphHeight = findChild(outlined, "glyph").implicitHeight
        VitrailTokens.iconContainer = true
        var container = createTemporaryObject(iconComponent, testCase)
        compare(container.implicitWidth, width)
        compare(container.implicitHeight, height)
        // The glyph keeps its full layout box; only the drawing scales.
        compare(findChild(container, "glyph").implicitHeight, glyphHeight)
    }

    function test_an_explicit_colour_is_ignored_inside_the_badge() {
        VitrailTokens.iconContainer = true
        var icon = createTemporaryObject(iconComponent, testCase)
        icon.color = "#ff0000"
        compare(findChild(icon, "glyph").color.toString(), testCase.ink.toString())
        // Outlined, the caller's colour is the glyph's.
        VitrailTokens.iconContainer = false
        icon.color = "#ff0000"
        compare(findChild(icon, "glyph").color.toString(), "#ff0000")
    }
}
