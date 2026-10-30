import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"
import "../../kit/shapes.js" as Shapes

// VitrailBusy: morphs between library shapes while it runs, sleeps otherwise.
TestCase {
    id: testCase

    name: "VitrailBusy"
    when: windowShown
    visible: true
    width: 200
    height: 200

    VitrailPalette {
        id: palette
    }

    Component {
        id: busyComponent

        VitrailBusy {
            running: true
        }
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function test_the_shape_changes_over_time_within_the_library() {
        var busy = createTemporaryObject(busyComponent, testCase)
        var seen = {}
        var last = ""
        var changes = 0
        var deadline = Date.now() + 3 * VitrailTokens.duration("cycle") + 400
        while (Date.now() < deadline) {
            if (busy.shape !== last) {
                verify(Shapes.names.indexOf(busy.shape) >= 0, busy.shape)
                verify(busy.shape !== last)
                last = busy.shape
                changes++
            }
            wait(20)
        }
        verify(changes >= 3, "changes " + changes)
    }

    function test_stopped_means_no_timer_and_no_visibility() {
        var busy = createTemporaryObject(busyComponent, testCase)
        compare(busy.ticking, true)
        busy.running = false
        tryCompare(busy, "ticking", false)
        compare(busy.visible, false)
        busy.running = true
        tryCompare(busy, "ticking", true)
    }

    function test_a_stopped_indicator_never_ticks() {
        var busy = createTemporaryObject(busyComponent, testCase, { running: false })
        compare(busy.ticking, false)
        compare(busy.shape, "")
    }
}
