import QtQuick
import QtTest
import "../../bar/popup.js" as Popup

// The popup's containment rule: a point is inside a rect with a margin of
// grace on every side. The shell feeds it the pointer and the card, the tray
// menu and the invoking button's rects.
TestCase {
    name: "Popup"

    readonly property var rect: Qt.rect(100, 50, 200, 120)

    function test_a_point_inside_is_inside() {
        verify(Popup.inside(Qt.point(200, 100), rect, 0))
        verify(Popup.inside(Qt.point(100, 50), rect, 0))
        verify(Popup.inside(Qt.point(300, 170), rect, 0))
    }

    function test_a_point_outside_is_outside() {
        verify(!Popup.inside(Qt.point(99, 100), rect, 0))
        verify(!Popup.inside(Qt.point(301, 100), rect, 0))
        verify(!Popup.inside(Qt.point(200, 49), rect, 0))
        verify(!Popup.inside(Qt.point(200, 171), rect, 0))
    }

    function test_the_margin_holds_the_edges() {
        verify(Popup.inside(Qt.point(95, 100), rect, 5))
        verify(Popup.inside(Qt.point(305, 100), rect, 5))
        verify(Popup.inside(Qt.point(200, 45), rect, 5))
        verify(Popup.inside(Qt.point(200, 175), rect, 5))
        verify(!Popup.inside(Qt.point(94, 100), rect, 5))
        verify(!Popup.inside(Qt.point(200, 176), rect, 5))
    }

    function test_a_missing_point_or_rect_is_outside() {
        verify(!Popup.inside(null, rect, 5))
        verify(!Popup.inside(Qt.point(200, 100), null, 5))
    }

    function test_any_rect_counts() {
        var menu = Qt.rect(320, 60, 100, 80)
        verify(Popup.insideAny(Qt.point(350, 80), [rect, menu], 0))
        verify(Popup.insideAny(Qt.point(120, 60), [rect, menu], 0))
        verify(!Popup.insideAny(Qt.point(310, 80), [rect, menu], 0))
        verify(!Popup.insideAny(Qt.point(350, 80), [rect, null], 0))
    }
}
