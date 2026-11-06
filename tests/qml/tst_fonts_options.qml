import QtQuick
import QtTest
import "../../kit"

// The Fonts page's option builders: every adaptive tab entry must be a
// Vitrail layer (`vitrail-*` / `vitrail-icons-*`), and the normal tab must not
// contain one.
TestCase {
    id: testCase

    name: "FontsOptions"
    when: windowShown
    visible: true
    width: 900
    height: 700

    QtObject {
        id: prefs

        property string cursorTheme: "Adwaita"
        property string cursorThemeLight: ""
        property string cursorThemeDark: ""
        property bool cursorThemeSplit: false
        property string iconTheme: "Adwaita"
        property string fontSystem: "Roboto"
        property string fontConsole: "Hack"
        property int cursorSize: 24
    }

    Loader {
        id: page

        source: "../../shell/pages/FontsPage.qml"
        onLoaded: {
            item.palette = ({ foreground: "white", primary: "blue", muted: "gray", surfaceHigh: "#222" })
            item.prefs = prefs
            item.strings = ({})
            item.fonts = ({
                fonts: [], monospace: [],
                iconThemes: ["Adwaita", "Papirus", "vitrail-icons-Adwaita"],
                iconDesigns: ["Adwaita", "Papirus"],
                iconUser: ["vitrail-icons-Adwaita"],
                cursorThemes: ["Adwaita", "Bibata", "vitrail-Adwaita"],
                cursorDesigns: ["Adwaita", "Bibata"],
                iconPreviews: {
                    Adwaita: ["base.svg"],
                    "vitrail-icons-Adwaita@light": ["light.svg"],
                    "vitrail-icons-Adwaita@solid": ["solid.svg"]
                },
                cursorPreviews: {}
            })
        }
    }

    function initTestCase() {
        tryCompare(page, "status", Loader.Ready)
    }

    function test_adaptive_icons_are_only_vitrail_icons() {
        var rows = page.item.adaptiveIconOptions("")
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++)
            compare(rows[i].key.indexOf("vitrail-icons-"), 0)
    }

    function test_each_fill_variant_shows_its_own_previews() {
        var rows = page.item.adaptiveIconOptions("")
        function iconOf(key) {
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].key === key)
                    return rows[i].icons[0]
            }
            return ""
        }
        compare(iconOf("vitrail-icons-Adwaita@light"), "light.svg")
        compare(iconOf("vitrail-icons-Adwaita@solid"), "solid.svg")
        compare(iconOf("vitrail-icons-Adwaita"), "base.svg")
    }

    function test_each_adaptive_icon_pack_has_three_fill_variants() {
        var keys = page.item.adaptiveIconOptions("").map(function (row) {
            return row.key
        })
        verify(keys.indexOf("vitrail-icons-Adwaita") >= 0)
        verify(keys.indexOf("vitrail-icons-Adwaita@light") >= 0)
        verify(keys.indexOf("vitrail-icons-Adwaita@solid") >= 0)
    }

    function test_normal_icons_exclude_vitrail_icons() {
        var rows = page.item.normalIconOptions("Adwaita")
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++)
            compare(rows[i].key.indexOf("vitrail-icons-"), -1)
    }

    function test_adaptive_cursors_are_only_vitrail_layers() {
        var rows = page.item.cursorOptions("", true).filter(function (row) {
            return row.tab === "adaptive"
        })
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++)
            compare(rows[i].key.indexOf("vitrail-"), 0)
    }

    function test_normal_cursors_exclude_vitrail_layers() {
        var rows = page.item.cursorOptions("", true).filter(function (row) {
            return row.tab === "normal"
        })
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++)
            compare(rows[i].key.indexOf("vitrail-"), -1)
    }

    function test_the_inherit_row_is_only_offered_for_a_split() {
        var split = page.item.cursorOptions("", true)
        var shared = page.item.cursorOptions("", false)
        compare(split[0].key, "")
        compare(shared[0].key === "", false)
    }

    function findObject(item, name) {
        if (item.objectName === name)
            return item
        for (var i = 0; i < item.children.length; i++) {
            var found = findObject(item.children[i], name)
            if (found)
                return found
        }
        return null
    }

    function test_the_single_cursor_card_is_centred() {
        prefs.cursorThemeSplit = false
        page.item.tab = "cursor"
        wait(50)
        var card = findObject(page.item, "cursorSharedCard")
        verify(card !== null)
        verify(card.visible)
        var row = card.parent
        var place = card.mapToItem(row, 0, 0)
        verify(Math.abs(place.x + card.width / 2 - row.width / 2) < 4)
        // Fixed width: the card and its picker do not stretch with the row.
        verify(Math.abs(card.width - 240) < 2)
        var picker = findObject(card, "cursorThemePicker")
        verify(picker !== null)
        verify(Math.abs(picker.width - 240) < 2)
        verify(card.width < row.width)
    }

    function test_the_icon_pack_sits_below_its_header_centred_and_fixed() {
        page.item.tab = "icons"
        wait(50)
        var header = findObject(page.item, "iconPickerHeader")
        var picker = findObject(page.item, "iconThemePicker")
        verify(header !== null)
        verify(picker !== null)
        var head = header.mapToItem(page.item, 0, 0)
        var pack = picker.mapToItem(page.item, 0, 0)
        verify(pack.y >= head.y + header.height - 2)
        var row = picker.parent
        var place = picker.mapToItem(row, 0, 0)
        verify(Math.abs(place.x + picker.width / 2 - row.width / 2) < 4)
        verify(Math.abs(picker.width - 240) < 2)
    }

    function test_split_cursors_sit_side_by_side_in_equal_columns() {
        prefs.cursorThemeSplit = true
        page.item.tab = "cursor"
        wait(50)
        var light = findObject(page.item, "cursorLightPicker")
        var dark = findObject(page.item, "cursorDarkPicker")
        verify(light !== null)
        verify(dark !== null)
        verify(light.visible && dark.visible)
        var left = light.mapToItem(page.item, 0, 0)
        var right = dark.mapToItem(page.item, 0, 0)
        verify(Math.abs(left.y - right.y) < 2)
        verify(left.x < right.x)
        verify(Math.abs(light.width - dark.width) < 2)
        verify(Math.abs(light.width - 240) < 2)
        verify(Math.abs(dark.width - 240) < 2)
        prefs.cursorThemeSplit = false
    }
}
