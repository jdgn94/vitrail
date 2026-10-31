import QtQuick
import QtTest
import "../../shell/worldmap.js" as Map

// World map maths: projection, zoom and pan, nearest zone, search, labels.
TestCase {
    name: "WorldMap"

    readonly property var zones: [
        { id: "Europe/Madrid", lat: 40.4, lon: -3.68, offset: 60, note: "Spain (mainland)" },
        { id: "America/Argentina/Buenos_Aires", lat: -34.6, lon: -58.45, offset: -180, note: "Buenos Aires (BA, CF)" },
        { id: "America/New_York", lat: 40.71, lon: -74.0, offset: -300, note: "Eastern (most areas)" },
        { id: "Asia/Kolkata", lat: 22.53, lon: 88.37, offset: 330, note: "" },
        { id: "Europe/Berlin", lat: 52.5, lon: 13.4, offset: 60, note: "most of Germany" }
    ]

    function test_projection_is_equirectangular() {
        var origin = Map.project(0, 0, 360)
        compare(origin.x, 180)
        compare(origin.y, 90)
        var corner = Map.project(-180, 90, 720)
        compare(corner.x, 0)
        compare(corner.y, 0)
        var far = Map.project(180, -90, 720)
        compare(far.x, 720)
        compare(far.y, 360)
    }

    function test_unproject_inverts_project() {
        var point = Map.project(-3.68, 40.4, 1000)
        var back = Map.unproject(point.x, point.y, 1000)
        fuzzyCompare(back.lon, -3.68, 1e-9)
        fuzzyCompare(back.lat, 40.4, 1e-9)
    }

    function test_names() {
        compare(Map.city("America/Argentina/Buenos_Aires"), "Buenos Aires")
        compare(Map.region("America/Argentina/Buenos_Aires"), "America / Argentina")
        compare(Map.city("UTC"), "UTC")
        compare(Map.region("UTC"), "")
    }

    function test_offset_labels() {
        compare(Map.offsetLabel(0), "UTC")
        compare(Map.offsetLabel(60), "UTC+01:00")
        compare(Map.offsetLabel(-240), "UTC-04:00")
        compare(Map.offsetLabel(330), "UTC+05:30")
        compare(Map.offsetLabel(-210), "UTC-03:30")
    }

    function test_local_time_applies_the_offset_to_utc() {
        var noonUtc = Date.UTC(2026, 0, 15, 12, 0)
        compare(Map.localTime(60, noonUtc), "13:00")
        compare(Map.localTime(-300, noonUtc), "07:00")
        compare(Map.localTime(330, noonUtc), "17:30")
        compare(Map.localTime(720, Date.UTC(2026, 0, 15, 23, 5)), "11:05")
    }

    function test_zoom_keeps_the_point_under_the_pointer() {
        var view = { zoom: 1, ox: 0, oy: 0 }
        var before = Map.unproject(300 - view.ox, 120 - view.oy, 800 * view.zoom)
        var next = Map.zoomAbout(view, 4, 300, 120, 800, 400)
        compare(next.zoom, 4)
        var after = Map.unproject(300 - next.ox, 120 - next.oy, 800 * next.zoom)
        fuzzyCompare(after.lon, before.lon, 1e-9)
        fuzzyCompare(after.lat, before.lat, 1e-9)
    }

    function test_zoom_is_limited_and_never_shows_beyond_the_map() {
        var view = { zoom: 1, ox: 0, oy: 0 }
        compare(Map.zoomAbout(view, 0.2, 400, 200, 800, 400).zoom, 1)
        compare(Map.zoomAbout(view, 500, 400, 200, 800, 400).zoom, Map.maxZoom)
        var zoomed = Map.zoomAbout(view, 3, 0, 0, 800, 400)
        compare(zoomed.ox, 0)
        compare(zoomed.oy, 0)
        var corner = Map.zoomAbout(view, 3, 800, 400, 800, 400)
        compare(corner.ox, 800 - 2400)
        compare(corner.oy, 400 - 1200)
    }

    function test_clamp_keeps_the_map_covering_the_viewport() {
        var clamped = Map.clamp({ zoom: 2, ox: 50, oy: -900 }, 800, 400)
        compare(clamped.ox, 0)
        compare(clamped.oy, -400)
        var whole = Map.clamp({ zoom: 1, ox: -30, oy: 20 }, 800, 400)
        compare(whole.ox, 0)
        compare(whole.oy, 0)
    }

    function test_center_on_puts_a_place_in_the_middle() {
        var view = Map.centerOn(-3.68, 40.4, 4, 800, 400)
        var at = Map.screenOf({ lon: -3.68, lat: 40.4 }, view, 800)
        fuzzyCompare(at.x, 400, 1e-9)
        fuzzyCompare(at.y, 200, 1e-9)
    }

    function test_center_on_near_the_edge_is_clamped() {
        var view = Map.centerOn(-179, 89, 4, 800, 400)
        compare(view.ox, 0)
        compare(view.oy, 0)
    }

    function test_nearest_zone_within_the_radius() {
        var view = { zoom: 1, ox: 0, oy: 0 }
        var madrid = Map.screenOf(zones[0], view, 800)
        var found = Map.nearest(zones, view, 800, madrid.x + 3, madrid.y - 2, 12)
        compare(found.id, "Europe/Madrid")
        compare(Map.nearest(zones, view, 800, madrid.x + 60, madrid.y + 60, 12), null)
    }

    function test_nearest_picks_the_closest_of_two() {
        var view = { zoom: 1, ox: 0, oy: 0 }
        var madrid = Map.screenOf(zones[0], view, 800)
        var berlin = Map.screenOf(zones[4], view, 800)
        var between = Map.nearest(zones, view, 800, (madrid.x * 3 + berlin.x) / 4, (madrid.y * 3 + berlin.y) / 4, 400)
        compare(between.id, "Europe/Madrid")
    }

    function test_search_matches_city_region_and_note() {
        compare(Map.search(zones, "madrid").map(z => z.id), ["Europe/Madrid"])
        compare(Map.search(zones, "buenos aires").map(z => z.id), ["America/Argentina/Buenos_Aires"])
        compare(Map.search(zones, "argentina").map(z => z.id), ["America/Argentina/Buenos_Aires"])
        compare(Map.search(zones, "germany").map(z => z.id), ["Europe/Berlin"])
        compare(Map.search(zones, "  MADRID ").map(z => z.id), ["Europe/Madrid"])
        compare(Map.search(zones, "nowhere"), [])
    }

    function test_search_needs_every_word() {
        compare(Map.search(zones, "europe madrid").map(z => z.id), ["Europe/Madrid"])
        compare(Map.search(zones, "europe york"), [])
    }

    function test_search_ignores_accents() {
        compare(Map.search(zones, "bueños").map(z => z.id), ["America/Argentina/Buenos_Aires"])
    }

    function test_search_puts_cities_that_start_with_the_query_first() {
        var list = [
            { id: "Asia/Aden", lat: 0, lon: 0, offset: 180, note: "" },
            { id: "Africa/Maputo", lat: 0, lon: 0, offset: 120, note: "Mozambique (ad hoc)" },
            { id: "Europe/Madrid", lat: 0, lon: 0, offset: 60, note: "" }
        ]
        compare(Map.search(list, "ad").map(z => z.id), ["Asia/Aden", "Europe/Madrid", "Africa/Maputo"])
    }

    function test_empty_query_lists_everything_by_city() {
        compare(Map.search(zones, "").map(z => Map.city(z.id)),
                ["Berlin", "Buenos Aires", "Kolkata", "Madrid", "New York"])
        compare(Map.search(zones, "   ").length, zones.length)
    }

    function test_find_by_id() {
        compare(Map.find(zones, "Asia/Kolkata").offset, 330)
        compare(Map.find(zones, "Mars/Base"), null)
        compare(Map.find(zones, ""), null)
    }
}
