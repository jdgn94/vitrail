import QtQuick
import QtTest
import "../../kit"
import "../../shell/pages"

// The rotation strip: dragging a picture to another place rewrites the
// selection in that order.
TestCase {
    id: testCase

    name: "WallpaperOrder"
    when: windowShown
    visible: true
    width: 900
    height: 700

    VitrailPalette {
        id: palette
    }

    QtObject {
        id: prefs

        property string wallpaper: "/w/a.png"
        property string wallpaperMode: ""
        property string wallpaperDir: ""
        property string wallpaperType: "image"
        property string wallpaperSelection: "/w/a.png|/w/b.png|/w/c.png|/w/d.png"
        property int wallpaperInterval: 45
        property string wallpaperOrder: "sequential"
        property string systemColor: ""
        property string wallpaperImport: ""
        property string wallpaperRemove: ""
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function chips(page) {
        var strip = findChild(page, "strip")
        verify(strip)
        return strip.children.filter(function (child) { return child.objectName === "chip" })
    }

    function make() {
        prefs.wallpaperSelection = "/w/a.png|/w/b.png|/w/c.png|/w/d.png"
        var page = createTemporaryObject(Qt.createComponent("../../shell/pages/WallpaperPage.qml"), testCase, {
            width: 860, height: 640, palette: palette, prefs: prefs, strings: ({ "wallpaper.interval.min": "%1 min", "wallpaper.interval.hour": "%1 h" }), configDir: "/nonexistent"
        })
        verify(page, "page loads")
        tryVerify(function () { return chips(page).length === 4 })
        var strip = findChild(page, "strip")
        tryVerify(function () { return strip.columns >= 3 && Math.abs(chips(page)[1].x - chips(page)[1].slotX) < 1 })
        return page
    }

    function order(page) {
        return chips(page).slice().sort(function (a, b) { return a.slot - b.slot })
            .map(function (chip) { return chip.path })
    }

    function test_the_strip_follows_the_selection_order() {
        var page = make()
        compare(order(page), ["/w/a.png", "/w/b.png", "/w/c.png", "/w/d.png"])
    }

    function test_the_strip_hides_with_a_single_wallpaper() {
        var page = make()
        var strip = findChild(page, "strip")
        compare(strip.visible, true)
        prefs.wallpaperSelection = "/w/a.png"
        tryCompare(strip.parent, "visible", false)
    }

    function test_dragging_a_picture_reorders_the_selection() {
        var page = make()
        var first = chips(page).filter(function (chip) { return chip.path === "/w/a.png" })[0]
        var target = chips(page).filter(function (chip) { return chip.slot === 2 })[0]
        var from = first.mapToItem(testCase, first.width / 2, first.height / 2)
        var to = target.mapToItem(testCase, target.width / 2, target.height / 2)
        mousePress(testCase, from.x, from.y)
        // Small steps, like a hand: a drag counts from where it passes the threshold.
        for (var step = 1; step <= 24; step++)
            mouseMove(testCase, from.x + (to.x - from.x) * step / 24, from.y + (to.y - from.y) * step / 24)
        mouseRelease(testCase, to.x, to.y)
        tryCompare(prefs, "wallpaperSelection", "/w/b.png|/w/c.png|/w/a.png|/w/d.png")
        tryCompare(first, "slot", 2)
        tryVerify(function () { return Math.abs(first.x - first.slotX) < 1 })
    }

    function test_the_interval_list_keeps_an_old_value() {
        var page = make()
        var keys = page.intervalOptions.map(function (option) { return option.key })
        verify(keys.indexOf("45") >= 0)
        compare(page.intervalOptions[0].key, "1")
        compare(page.intervalOptions[keys.length - 1].key, "1440")
    }

    function test_intervals_read_in_minutes_and_hours() {
        var page = make()
        compare(page.duration(5), "5 min")
        compare(page.duration(60), "1 h")
        compare(page.duration(1440), "24 h")
        compare(page.intervalOptions[0].label, "1 min")
    }
}
