import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"
import "../../kit/composed"
import "../../kit/visualiser.js" as Vis

// The visualiser: cava's frame numbers become bar levels, and the five
// approved looks resolve to their primitive (bars, reflection, panel, circle,
// waves).
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

    Component {
        id: radialComponent

        VitrailRadial {
            width: 400
            height: 120
            values: [0, 25, 50, 75, 100]
        }
    }

    Component {
        id: wavesComponent

        VitrailWaves {
            width: 400
            height: 120
            values: [0, 25, 50, 75, 100]
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

    function test_the_five_looks_resolve() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        verify(visualiser)

        compare(visualiser.shape, "bars")
        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)

        visualiser.variant = "reflection"
        compare(visualiser.shape, "bars")
        compare(visualiser.look.reflection, true)
        compare(visualiser.look.panel, false)

        visualiser.variant = "panel"
        compare(visualiser.shape, "bars")
        compare(visualiser.look.panel, true)
        compare(visualiser.look.reflection, false)

        visualiser.variant = "circle"
        compare(visualiser.shape, "circle")
        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)

        visualiser.variant = "waves"
        compare(visualiser.shape, "waves")
        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)
    }

    function test_an_unknown_look_falls_back_to_bars() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        visualiser.variant = "helix"
        compare(visualiser.shape, "bars")
        compare(visualiser.look.panel, false)
        compare(visualiser.look.reflection, false)
    }

    function test_the_component_keeps_the_frame_values() {
        var visualiser = createTemporaryObject(visualiserComponent, testCase)
        visualiser.values = [0, 25, 100]
        compare(visualiser.values, [0, 25, 100])
        compare(visualiser.bars, VitrailTokens.visualiser.bars)
    }

    function test_the_radial_places_one_bar_per_level_around_the_centre() {
        var ring = { radius: 1.0, inner: 0.5, coverage: 0.5 }
        var bars = Vis.radial([0, 50, 75, 100], 4, 200, 100, ring, 0.04)

        compare(bars.length, 4)
        compare(bars[0].rotation, -180)
        fuzzyCompare(bars[0].x, 100, 0.0001)
        verify(bars[0].y < 50)
        fuzzyCompare(bars[2].x, 100, 0.0001)
        verify(bars[2].y > 50)
        verify(bars[3].length > bars[1].length)
        verify(bars[1].length > bars[0].length)
        fuzzyCompare(bars[0].length, 50 * 0.04, 0.0001)
        compare(bars[0].thickness, bars[3].thickness)
        verify(bars[0].thickness >= 1)
    }

    function test_the_radial_uses_the_token_count() {
        var radial = createTemporaryObject(radialComponent, testCase)
        verify(radial)

        compare(radial.count, VitrailTokens.visualiser.circle.count)
        compare(radial.bars.length, VitrailTokens.visualiser.circle.count)
        verify(radial.bars[0].rotation === -180)
    }

    function test_the_waves_paint_one_polyline_per_line() {
        var wave = { lines: 3, amplitude: 0.4, spread: 0.2 }
        var lines = Vis.wave([50, 50, 50, 50], 4, 300, 100, wave)

        compare(lines.length, 3)
        compare(lines[0].length, 4)
        fuzzyCompare(lines[0][0].x, 0, 0.0001)
        fuzzyCompare(lines[0][3].x, 300, 0.0001)
        fuzzyCompare(lines[0][0].y, 30, 0.0001)
        fuzzyCompare(lines[1][0].y, 50, 0.0001)
        fuzzyCompare(lines[2][0].y, 70, 0.0001)

        var loud = Vis.wave([100, 100], 2, 100, 100, wave)
        fuzzyCompare(loud[1][0].y, 50 - 40, 0.0001)
    }

    function test_the_waves_component_uses_the_token_points() {
        var wave = createTemporaryObject(wavesComponent, testCase)
        verify(wave)

        compare(wave.count, VitrailTokens.visualiser.waves.count)
        compare(wave.lines.length, VitrailTokens.visualiser.waves.lines)
        for (var i = 0; i < wave.lines.length; i++)
            compare(wave.lines[i].length, VitrailTokens.visualiser.waves.count)
    }
}
