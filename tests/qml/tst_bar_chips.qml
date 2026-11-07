import QtQuick
import QtTest
import "../../bar"
import "../../kit"

// The bar's chips and dividers: a chip hands every member id to the bar's own
// component and draws them side by side inside one pill; a divider is a 1 px
// hairline from tokens that takes no input (bar/BarChip.qml, bar/BarDivider.qml).
TestCase {
    id: testCase

    name: "BarChips"
    when: windowShown
    visible: true
    width: 400
    height: 100

    VitrailPalette {
        id: palette
    }

    Component {
        id: memberComponent

        Item {
            implicitWidth: 24
            implicitHeight: 20
        }
    }

    Component {
        id: chipComponent

        BarChip {
        }
    }

    Component {
        id: dividerComponent

        BarDivider {
        }
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

    function test_a_chip_draws_a_pill_around_every_member() {
        var asked = []
        var chip = createTemporaryObject(chipComponent, testCase, {
            ids: ["network", "bluetooth", "vpn"],
            componentFor: function (id) {
                asked.push(id)
                return memberComponent
            }
        })
        verify(chip !== null)
        tryCompare(chip, "implicitWidth", 72)
        compare(asked, ["network", "bluetooth", "vpn"])
        compare(chip.implicitHeight, 22)
    }

    function test_a_vertical_chip_stacks_its_members() {
        var chip = createTemporaryObject(chipComponent, testCase, {
            ids: ["network", "bluetooth"],
            vertical: true,
            componentFor: function (id) { return memberComponent }
        })
        verify(chip !== null)
        tryCompare(chip, "implicitHeight", 42)
        compare(chip.implicitWidth, 24)
    }

    function test_an_unknown_member_draws_nothing_but_takes_no_width() {
        var chip = createTemporaryObject(chipComponent, testCase, {
            ids: ["network", "ghost"],
            componentFor: function (id) {
                return id === "network" ? memberComponent : null
            }
        })
        verify(chip !== null)
        tryCompare(chip, "implicitWidth", 24)
    }

    function test_a_divider_is_one_pixel_thick_and_token_long() {
        var divider = createTemporaryObject(dividerComponent, testCase)
        verify(divider !== null)
        compare(divider.implicitWidth, 1)
        compare(divider.implicitHeight, VitrailTokens.gap("lg"))
        var line = findChild(divider, "barDividerLine")
        verify(line !== null)
        compare(line.width, 1)
        compare(line.height, divider.implicitHeight)
        verify(line.color.a > 0)
        compare(line.color, divider.tone)
    }

    function test_a_vertical_bar_draws_a_horizontal_line() {
        var divider = createTemporaryObject(dividerComponent, testCase, { vertical: true })
        verify(divider !== null)
        compare(divider.implicitWidth, VitrailTokens.gap("lg"))
        compare(divider.implicitHeight, 1)
        var line = findChild(divider, "barDividerLine")
        verify(line !== null)
        compare(line.width, divider.implicitWidth)
        compare(line.height, 1)
    }
}
