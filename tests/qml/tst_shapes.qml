import QtQuick
import QtTest
import "../../kit/shapes.js" as Shapes

// The shape library behind the password field and the busy indicator.
TestCase {
    name: "Shapes"

    function numbers(path) {
        return (path.match(/-?\d+(\.\d+)?/g) || []).map(Number)
    }

    function test_library_has_the_expressive_set() {
        verify(Shapes.names.length >= 12)
        for (var wanted of ["circle", "square", "triangle", "pentagon", "gem", "cookie4",
                            "cookie6", "cookie9", "cookie12", "clover4", "clover8", "flower",
                            "sunny", "burst"])
            verify(Shapes.names.indexOf(wanted) >= 0, wanted)
    }

    function test_every_shape_is_a_closed_path_inside_its_box() {
        for (var i = 0; i < Shapes.names.length; i++) {
            var path = Shapes.path(Shapes.names[i], 40)
            verify(/^M[^Z]+Z$/.test(path), Shapes.names[i])
            var values = numbers(path)
            verify(values.length > 0, Shapes.names[i])
            for (var j = 0; j < values.length; j++)
                verify(values[j] >= 0 && values[j] <= 40, Shapes.names[i] + " " + values[j])
        }
    }

    function test_shapes_fill_the_box() {
        for (var i = 0; i < Shapes.names.length; i++) {
            var values = numbers(Shapes.path(Shapes.names[i], 100))
            verify(Math.max.apply(null, values) > 95, Shapes.names[i])
            verify(Math.min.apply(null, values) < 5, Shapes.names[i])
        }
    }

    function test_unknown_name_falls_back_to_a_shape() {
        verify(Shapes.path("nope", 10).length > 0)
    }

    function test_random_never_repeats_the_previous() {
        var previous = ""
        for (var i = 0; i < 300; i++) {
            var next = Shapes.random(previous)
            verify(Shapes.names.indexOf(next) >= 0)
            verify(next !== previous)
            previous = next
        }
    }

    function test_random_with_a_pool_stays_inside_it_and_never_repeats() {
        var pool = ["circle", "square", "triangle"]
        var previous = ""
        for (var i = 0; i < 300; i++) {
            var next = Shapes.random(previous, pool)
            verify(pool.indexOf(next) >= 0, next)
            verify(next !== previous)
            previous = next
        }
    }

    function test_distinct_shapes_are_a_subset_of_the_library() {
        compare(Shapes.distinct.length, 6)
        for (var i = 0; i < Shapes.distinct.length; i++)
            verify(Shapes.names.indexOf(Shapes.distinct[i]) >= 0, Shapes.distinct[i])
    }

    function test_outline_without_a_gap_is_closed() {
        var path = Shapes.outlinePath(200, 50, 10, 20, 0)
        verify(/^M/.test(path))
        verify(/Z$/.test(path))
        var start = path.match(/^M\s*(-?[\d.]+)\s+(-?[\d.]+)/)
        var end = path.match(/(-?[\d.]+)\s+(-?[\d.]+)\s*Z$/)
        compare(Number(end[1]), Number(start[1]))
        compare(Number(end[2]), Number(start[2]))
    }

    function test_outline_with_a_gap_is_open_exactly_there() {
        var path = Shapes.outlinePath(200, 50, 10, 30, 60)
        verify(!/Z/.test(path))
        var start = path.match(/^M\s*(-?[\d.]+)\s+(-?[\d.]+)/)
        var end = path.match(/(-?[\d.]+)\s+(-?[\d.]+)\s*$/)
        compare(Number(start[1]), 90)
        compare(Number(start[2]), 0)
        compare(Number(end[1]), 30)
        compare(Number(end[2]), 0)
    }

    function test_outline_stays_inside_its_box() {
        var values = numbers(Shapes.outlinePath(200, 50, 10, 30, 60))
        for (var i = 0; i < values.length; i++)
            verify(values[i] >= 0 && values[i] <= 200)
    }
}
