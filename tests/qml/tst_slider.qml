import QtQuick
import QtTest
import "../../kit"
import "../../kit/wheel.js" as Wheel

// VitrailSlider: horizontal by default, vertical on request (minimum at the
// bottom, maximum at the top).
TestCase {
    id: testCase

    name: "VitrailSlider"
    when: windowShown
    visible: true
    width: 400
    height: 400

    VitrailPalette {
        id: palette
    }

    Component {
        id: slider

        VitrailSlider {
            from: 0
            to: 100
            value: 50
            size: "md"
        }
    }

    SignalSpy {
        id: spy

        signalName: "moved"
    }

    // The slider shows what its owner says; the owner follows `moved`.
    function make(props) {
        var item = createTemporaryObject(slider, testCase, props)
        verify(item !== null)
        item.moved.connect(function (value) { item.value = value })
        return item
    }

    function test_horizontal_is_the_default() {
        var item = make({ width: 200 })
        compare(item.orientation, Qt.Horizontal)
        compare(item.implicitHeight, item.handleHeight)
    }

    function test_horizontal_right_is_more() {
        var item = make({ width: 200 })
        spy.target = item
        spy.clear()
        mouseClick(item, 190, item.height / 2)
        verify(spy.count > 0)
        verify(item.value > 90)
        mouseClick(item, 10, item.height / 2)
        verify(item.value < 10)
    }

    function test_vertical_is_thin_and_tall() {
        var item = make({ orientation: Qt.Vertical, height: 200 })
        compare(item.implicitWidth, item.handleHeight)
        compare(item.height, 200)
        verify(item.width < item.height)
    }

    function test_vertical_has_a_default_length() {
        var item = make({ orientation: Qt.Vertical })
        compare(item.implicitHeight, VitrailTokens.slider.length)
    }

    function test_vertical_top_is_more_and_bottom_is_less() {
        var item = make({ orientation: Qt.Vertical, height: 200 })
        spy.target = item
        spy.clear()
        mouseClick(item, item.width / 2, 10)
        verify(spy.count > 0)
        verify(item.value > 90)
        mouseClick(item, item.width / 2, 190)
        verify(item.value < 10)
    }

    function test_vertical_dragging_up_raises_the_value() {
        var item = make({ orientation: Qt.Vertical, height: 200, value: 10 })
        mousePress(item, item.width / 2, 180)
        mouseMove(item, item.width / 2, 100)
        mouseRelease(item, item.width / 2, 100)
        verify(item.value > 30 && item.value < 70)
    }

    // --- mouse wheel (opt-in) ----------------------------------------------------

    function test_the_wheel_does_nothing_unless_asked() {
        var item = make({ width: 200 })
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(item.value, 50)
    }

    function test_a_notch_up_moves_by_the_wheel_step() {
        var item = make({ width: 200, wheelStep: 5 })
        spy.target = item
        spy.clear()
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(item.value, 55)
        compare(spy.count, 1)
        mouseWheel(item, 100, item.height / 2, 0, -240)
        compare(item.value, 45)
    }

    function test_a_vertical_slider_follows_the_wheel_too() {
        var item = make({ orientation: Qt.Vertical, height: 200, wheelStep: 5 })
        mouseWheel(item, item.width / 2, 100, 0, 120)
        compare(item.value, 55)
        mouseWheel(item, item.width / 2, 100, 0, -120)
        compare(item.value, 50)
    }

    function test_the_wheel_stops_at_the_ends() {
        var item = make({ width: 200, wheelStep: 5, value: 98 })
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(item.value, 100)
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(item.value, 100)
        var low = make({ width: 200, wheelStep: 5, value: 2 })
        mouseWheel(low, 100, low.height / 2, 0, -120)
        compare(low.value, 0)
    }

    function test_a_fast_spin_counts_from_its_own_value_while_the_owner_lags() {
        var item = createTemporaryObject(slider, testCase, { width: 200, wheelStep: 5 })
        spy.target = item
        spy.clear()
        // The owner ignores `moved`, like a device that answers late.
        mouseWheel(item, 100, item.height / 2, 0, 120)
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(spy.count, 2)
        compare(spy.signalArguments[0][0], 55)
        compare(spy.signalArguments[1][0], 60)
    }

    function test_a_read_only_slider_ignores_the_wheel() {
        var item = make({ width: 200, wheelStep: 5, readOnly: true })
        mouseWheel(item, 100, item.height / 2, 0, 120)
        compare(item.value, 50)
    }

    // Wayland reports a wheel as a touchpad (Qt then refuses it to a WheelHandler
    // left at its default, which takes only "Mouse"), and mouseWheel() here
    // always sends a mouse: the test cannot send the real thing, so it checks
    // what the handler accepts.
    function wheelHandlers(object, found) {
        for (var i = 0; i < object.data.length; i++) {
            var child = object.data[i]
            if (child.rotationScale !== undefined)
                found.push(child)
            if (child.data !== undefined)
                wheelHandlers(child, found)
        }
        return found
    }

    function test_the_wheel_is_taken_from_a_touchpad_too() {
        var found = wheelHandlers(make({ width: 200, wheelStep: 5 }), [])
        compare(found.length, 1)
        verify((found[0].acceptedDevices & PointerDevice.Mouse) !== 0)
        verify((found[0].acceptedDevices & PointerDevice.TouchPad) !== 0)
    }

    // --- the pure accumulation ---------------------------------------------------

    function test_a_notch_is_120_angle_units() {
        compare(Wheel.notches(120, 0, 120, 60), 1)
        compare(Wheel.notches(-60, 0, 120, 60), -0.5)
        compare(Wheel.notches(0, 0, 120, 60), 0)
    }

    function test_a_touchpad_scrolls_by_pixels() {
        verify(Wheel.notches(0, 10, 120, VitrailTokens.slider.wheelPixels) > 0)
        verify(Wheel.notches(0, -10, 120, VitrailTokens.slider.wheelPixels) < 0)
        compare(Wheel.notches(0, 10, 120, VitrailTokens.slider.wheelPixels), 10 / VitrailTokens.slider.wheelPixels)
        // Pixels win over the angle when both come.
        compare(Wheel.notches(120, 10, 120, VitrailTokens.slider.wheelPixels), 10 / VitrailTokens.slider.wheelPixels)
    }

    function test_small_deltas_accumulate_until_a_whole_step() {
        var state = Wheel.advance(0, 0.1, 5, 1, 50, 0, 100)
        compare(state.value, 50)
        compare(state.acc, 0.5)
        state = Wheel.advance(state.acc, 0.1, 5, 1, state.value, 0, 100)
        compare(state.value, 51)
        compare(state.acc, 0)
    }

    function test_the_value_moves_in_multiples_of_the_step_size() {
        var state = Wheel.advance(0, 1, 5, 2, 50, 0, 100)
        compare(state.value, 54)
        compare(state.acc, 1)
        state = Wheel.advance(state.acc, 1, 5, 2, state.value, 0, 100)
        compare(state.value, 60)
        compare(state.acc, 0)
    }

    function test_the_remainder_is_dropped_at_the_end() {
        var state = Wheel.advance(0, 1, 5, 1, 98, 0, 100)
        compare(state.value, 100)
        compare(state.acc, 0)
        state = Wheel.advance(state.acc, -1, 5, 1, state.value, 0, 100)
        compare(state.value, 95)
    }
}
