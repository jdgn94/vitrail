import QtQuick
import QtTest
import "../../kit"
import "../../kit/composed"
import "../../kit/visualiser.js" as Vis

// The visualiser: cava's frame numbers become bar levels, and the three
// approved looks resolve to their variant (bars, reflection, panel).
TestCase {
    id: testCase

    name: "Visualiser"
    when: windowShown
    visible: true
    width: 800
    height: 400

    VitrailPalette {
        id: palette
    }

    Component {
        id: visualiserComponent

        VitrailVisualiser {
            width: 400
            height: 120
        }
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function test_a_frame_is_padded_truncated_and_clamped() {
        var values = Vis.values("10;200;-5;oops", 6)
        compare(values.length, 6)
        compare(values[0], 10)
        compare(values[1], 100)
        compare(values[2], 0)
        compare(values[3], 0)
        compare(values[4], 0)
        compare(values[5], 0)
        compare(Vis.values("1;2;3", 2), [1, 2])
    }

    function test_a_document_is_accepted() {
        compare(Vis.values({ values: [25, 75] }, 3), [25, 75, 0])
        compare(Vis.values([40], 2), [40, 0])
    }

    function test_a_level_is_a_fraction_of_cava_max_range() {
        compare(Vis.level(0), 0)
        compare(Vis.level(50), 0.5)
        compare(Vis.level(100), 1)
        compare(Vis.level(undefined), 0)
        compare(Vis.level("120"), 1)
    }

    function test_the_three_approved_looks_resolve() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        verify(visualiser)

        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)

        visualiser.variant = "reflection"
        compare(visualiser.look.reflection, true)
        compare(visualiser.look.panel, false)

        visualiser.variant = "panel"
        compare(visualiser.look.panel, true)
        compare(visualiser.look.reflection, false)
    }

    function test_an_unknown_look_falls_back_to_bars() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        visualiser.variant = "circle"
        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)
    }

    function test_the_component_keeps_the_frame_values() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        visualiser.values = [0, 25, 100]
        compare(visualiser.values, [0, 25, 100])
        compare(visualiser.bars, VitrailTokens.visualiser.bars)
    }
}
