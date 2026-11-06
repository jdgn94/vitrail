import QtQuick
import QtTest
import "../../bar/droplet"
import "../../bar/droplet/droplet.js" as Droplet
import "../../bar/kit"

// The drop's shape: a liquid neck joins it to its birth point while it opens,
// the final rect stays opaque until the fade, and a closing window bursts into
// droplets. The state machine is tested in tst_launch_droplet.
TestCase {
    id: testCase

    name: "LaunchDropletShape"
    when: windowShown
    visible: true
    width: 600
    height: 600

    readonly property var origin: ({ x: 20, y: 100, width: 40, height: 40 })
    readonly property var first: ({ x: 100, y: 100, width: 200, height: 150 })
    readonly property var final: ({ x: 0, y: 0, width: 300, height: 200 })
    readonly property real tint: VitrailTokens.opacity * VitrailTokens.droplet.tint

    Component {
        id: dropletComponent

        LaunchDroplet {
            width: 600
            height: 600
        }
    }

    function initTestCase() {
        VitrailTokens.configure({ primary: "#a8c7fa", info: "#79d9a8" }, true, "glass", ({}))
    }

    function test_the_gooey_neck_joins_a_diagonal_origin_while_it_opens() {
        var shape = createTemporaryObject(dropletComponent, testCase, { screen: "DP-1" })
        verify(shape)
        var diagonalOrigin = { x: 20, y: 400, width: 40, height: 40 }
        var diagonalTarget = { x: 260, y: 60, width: 200, height: 150 }
        var request = Droplet.request({ id: "firefox.desktop" }, diagonalOrigin, diagonalTarget,
                                      1000, 4000, "DP-1")
        shape.request = request
        tryVerify(function () { return shape.goo && shape.goo.neck !== null }, 1000)
        tryVerify(function () { return shape.opening }, 1000)
        verify(shape.goo.neck.length > 0)
        verify(shape.goo.path.indexOf("C") >= 0)
    }

    function test_the_final_rect_stays_opaque_until_the_fade() {
        var shape = createTemporaryObject(dropletComponent, testCase, { screen: "DP-1" })
        verify(shape)
        var drop = findChild(shape, "dropletMass")
        verify(drop)
        var request = Droplet.request({ id: "firefox.desktop" }, origin, first, 1000, 4000, "DP-1")
        shape.request = request
        tryCompare(drop, "width", first.width, 1000)
        tryVerify(function () { return Math.abs(drop.opacity - testCase.tint) < 0.01 }, 1000)

        request = Droplet.arrive(request, final, 1200)
        shape.request = request
        tryCompare(drop, "width", final.width, 1000)
        tryVerify(function () { return Math.abs(drop.opacity - testCase.tint) < 0.01 }, 1000)
        compare(request.phase, "placing")
        tryVerify(function () { return shape.goo.neck === null }, 1000)
        compare(shape.goo.path, shape.goo.massPath)
        verify(shape.goo.massPath.indexOf("C") >= 0)

        request = Droplet.fade(request, 1500)
        shape.request = request
        tryCompare(drop, "opacity", 0, 1000)
        compare(drop.width, final.width)
    }

    function test_a_closing_window_bursts_its_droplets() {
        var shape = createTemporaryObject(dropletComponent, testCase, { screen: "DP-1" })
        verify(shape)
        var drop = findChild(shape, "dropletMass")
        var last = { x: 100, y: 100, width: 300, height: 200 }
        shape.request = Droplet.closing(last, 1000, "DP-1", 1.12)
        tryVerify(function () { return shape.closing }, 1000)
        tryVerify(function () { return shape.burstParticles.length >= 5
                                      && shape.burstParticles.length <= 8 }, 1000)
        var speck = findChild(shape, "burstParticle0")
        verify(speck)
        var startX = speck.x
        wait(100)
        verify(speck.x !== startX)
        tryCompare(drop, "width", 336, 1000)
        tryVerify(function () { return drop.opacity < 0.01 }, 1000)
        tryCompare(speck, "opacity", 0, 1000)
        verify(shape.goo.massPath.indexOf("C") >= 0)
    }
}
