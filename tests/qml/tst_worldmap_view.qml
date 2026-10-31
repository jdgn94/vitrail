import QtQuick
import QtTest
import "../../kit"
import "../../shell/pages"

// WorldMap: click picks the nearest zone, the wheel zooms around the pointer,
// dragging pans, a zone chosen elsewhere is brought into view.
TestCase {
    id: testCase

    name: "WorldMapView"
    when: windowShown
    visible: true
    width: 820
    height: 460

    VitrailPalette {
        id: palette
    }

    readonly property var zones: [
        { id: "Europe/Madrid", lat: 40.4, lon: -3.68, offset: 60, note: "" },
        { id: "Asia/Tokyo", lat: 35.68, lon: 139.75, offset: 540, note: "" },
        { id: "Pacific/Auckland", lat: -36.85, lon: 174.76, offset: 720, note: "" }
    ]

    Component {
        id: map

        WorldMap {
            width: 800
            zones: testCase.zones
        }
    }

    SignalSpy {
        id: spy

        signalName: "picked"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make() {
        var item = createTemporaryObject(map, testCase)
        verify(item)
        spy.target = item
        spy.clear()
        return item
    }

    function place(item, zone) {
        var x = (zone.lon + 180) / 360 * item.width * item.goal.zoom + item.goal.ox
        var y = (90 - zone.lat) / 180 * item.width / 2 * item.goal.zoom + item.goal.oy
        return Qt.point(x, y)
    }

    function test_it_is_twice_as_wide_as_tall() {
        var item = make()
        compare(item.height, 400)
    }

    function test_clicking_a_dot_picks_its_zone() {
        var item = make()
        var at = place(item, zones[1])
        mouseClick(item, at.x + 3, at.y - 2)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "Asia/Tokyo")
    }

    function test_clicking_the_sea_picks_nothing() {
        var item = make()
        mouseClick(item, 10, 10)
        compare(spy.count, 0)
    }

    function test_hovering_a_dot_names_it() {
        var item = make()
        var at = place(item, zones[0])
        mouseMove(item, at.x + 2, at.y + 2)
        compare(item.hovered.id, "Europe/Madrid")
        mouseMove(item, 5, 395)
        compare(item.hovered, null)
    }

    function test_the_wheel_zooms_in_and_out() {
        var item = make()
        mouseWheel(item, 400, 200, 0, 120)
        verify(item.goal.zoom > 1)
        var zoomed = item.goal.zoom
        mouseWheel(item, 400, 200, 0, -120)
        verify(item.goal.zoom < zoomed)
        mouseWheel(item, 400, 200, 0, -1200)
        compare(item.goal.zoom, 1)
    }

    function test_dragging_pans_without_picking() {
        var item = make()
        item.show({ zoom: 3, ox: -400, oy: -200 }, false)
        mousePress(item, 400, 200)
        mouseMove(item, 450, 230)
        mouseMove(item, 500, 260)
        mouseRelease(item, 500, 260)
        compare(item.goal.ox, -300)
        compare(item.goal.oy, -140)
        compare(spy.count, 0)
    }

    function test_the_view_never_leaves_the_map() {
        var item = make()
        item.show({ zoom: 3, ox: -400, oy: -200 }, false)
        mousePress(item, 400, 200)
        mouseMove(item, 900, 600)
        mouseRelease(item, 900, 600)
        compare(item.goal.ox, 0)
        compare(item.goal.oy, 0)
    }

    function test_a_zone_chosen_elsewhere_is_brought_into_view() {
        var item = make()
        item.show({ zoom: 6, ox: 0, oy: 0 }, false)
        item.selected = "Asia/Tokyo"
        var at = place(item, zones[1])
        verify(at.x > 0 && at.x < 800)
        verify(at.y > 0 && at.y < 400)
    }

    function test_a_zone_already_in_view_does_not_move_the_map() {
        var item = make()
        item.selected = "Europe/Madrid"
        compare(item.goal.zoom, 1)
        compare(item.goal.ox, 0)
    }
}
