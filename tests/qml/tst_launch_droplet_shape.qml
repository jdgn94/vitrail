import QtQuick
import QtTest
import "../../bar/droplet"
import "../../bar/droplet/droplet.js" as Droplet
import "../../kit"

// The drop's shape: moving to the final rect stays opaque, and only the fade
// after the hold lets it go. The state machine is tested in tst_launch_droplet.
TestCase {
    id: testCase

    name: "LaunchDropletShape"
    when: windowShown
    visible: true
    width: 600
    height: 600

    readonly property var origin: ({ x: 20, y: 20, width: 40, height: 40 })
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
        VitrailTokens.configure({ primary: "#a8c7fa" }, true, "glass", ({}))
    }

    function test_the_final_rect_stays_opaque_until_the_fade() {
        var shape = createTemporaryObject(dropletComponent, testCase, { screen: "DP-1" })
        verify(shape)
        var drop = shape.children[0]
        var request = Droplet.request({ id: "firefox.desktop" }, origin, first, 1000, 4000, "DP-1")
        shape.request = request
        tryCompare(drop, "width", first.width, 1000)
        tryVerify(function () { return Math.abs(drop.opacity - testCase.tint) < 0.01 }, 1000)

        request = Droplet.arrive(request, final, 1200)
        shape.request = request
        tryCompare(drop, "width", final.width, 1000)
        tryVerify(function () { return Math.abs(drop.opacity - testCase.tint) < 0.01 }, 1000)
        compare(request.phase, "placing")

        request = Droplet.fade(request, 1500)
        shape.request = request
        tryCompare(drop, "opacity", 0, 1000)
        compare(drop.width, final.width)
    }
}
