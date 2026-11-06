// Slider interaction turned into the handle's height: pure, tested in
// tests/qml/tst_slider.qml.
.pragma library

// How much taller the handle is: 1 at rest, `grow` while the pointer holds it
// or the wheel turns. Keyboard focus does not make it taller (that would stay
// after a click): it thickens the handle and turns it accent instead.
function handleScale(pressed, wheel, grow) {
    return pressed || wheel ? grow : 1
}
