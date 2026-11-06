import QtQuick
import QtTest
import "../../bar/droplet/burst.js" as Burst

// The closing burst: a deterministic ring, varied sizes and distances, every
// droplet gone by the token duration.
TestCase {
    name: "DropletBurst"

    function test_the_ring_has_the_requested_droplets_without_repeating_angles() {
        var list = Burst.particles(7, 100, 250, 8)
        compare(list.length, 7)
        var seen = ({})
        for (var i = 0; i < list.length; i++) {
            verify(list[i].angle >= 0 && list[i].angle < 2 * Math.PI)
            var key = String(Math.round(list[i].angle * 100))
            verify(seen[key] !== true)
            seen[key] = true
            verify(list[i].distance > 0)
        }
    }

    function test_sizes_and_distances_vary_but_stay_bounded() {
        var list = Burst.particles(8, 120, 250, 8)
        var lowSize = Infinity, highSize = -Infinity
        var lowDistance = Infinity, highDistance = -Infinity
        for (var i = 0; i < list.length; i++) {
            lowSize = Math.min(lowSize, list[i].size)
            highSize = Math.max(highSize, list[i].size)
            lowDistance = Math.min(lowDistance, list[i].distance)
            highDistance = Math.max(highDistance, list[i].distance)
        }
        verify(highSize > lowSize)
        verify(highDistance > lowDistance)
        verify(lowSize > 0 && highSize <= 8)
        verify(lowDistance > 0 && highDistance <= 120)
    }

    function test_every_droplet_ends_by_the_burst_duration() {
        var list = Burst.particles(7, 100, 250, 7)
        for (var i = 0; i < list.length; i++) {
            verify(list[i].delay >= 0)
            verify(list[i].duration > 0)
            verify(list[i].delay + list[i].duration <= 250)
        }
    }

    function test_no_particles_for_an_empty_burst() {
        compare(Burst.particles(0, 100, 250, 7).length, 0)
    }
}
