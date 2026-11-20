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
        property string cursorImport: ""
        property string cursorRemove: ""
        property bool cursorThemeSplit: false
        property bool cursorAdaptive: true
        property bool cursorMonochrome: false
        property string iconTheme: "Adwaita"
        property bool iconAdaptive: true
        property string iconFill: "pack"
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
                cursorThemes: ["Adwaita", "Bibata", "vitrail-Adwaita", "vitrail-cursor"],
                cursorDesigns: ["Adwaita", "Bibata"],
                cursorUser: ["Adwaita"],
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

    function test_the_icon_list_is_one_list_of_packs() {
        var rows = page.item.iconOptions("")
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++)
            compare(rows[i].key.indexOf("vitrail-icons-"), -1)
        var keys = rows.map(function (row) { return row.key })
        verify(keys.indexOf("Adwaita") >= 0)
        verify(keys.indexOf("Papirus") >= 0)
    }

    function test_the_icon_picker_has_no_tabs() {
        page.item.tab = "icons"
        wait(50)
        var picker = findObject(page.item, "iconThemePicker")
        verify(picker !== null)
        compare(picker.tabs.length, 0)
    }

    function test_the_icon_switches_write_the_preferences() {
        page.item.tab = "icons"
        wait(50)
        var adaptive = findObject(page.item, "iconAdaptiveSwitch")
        var fill = findObject(page.item, "iconFillSelect")
        verify(adaptive !== null && fill !== null)
        adaptive.toggled(false)
        compare(prefs.iconAdaptive, false)
        compare(fill.enabled, false)
        adaptive.toggled(true)
        compare(prefs.iconAdaptive, true)
        compare(fill.enabled, true)
        fill.selected("light")
        compare(prefs.iconFill, "light")
    }

    function test_the_cursor_list_is_one_list_of_packs() {
        var rows = page.item.cursorOptions("", false)
        verify(rows.length > 0)
        for (var i = 0; i < rows.length; i++) {
            compare(rows[i].key.indexOf("vitrail-"), -1)
            compare(rows[i].tab, undefined)
        }
    }

    function test_the_cursor_picker_has_no_tabs() {
        prefs.cursorThemeSplit = false
        page.item.tab = "cursor"
        wait(50)
        var card = findObject(page.item, "cursorSharedCard")
        var picker = findObject(card, "cursorThemePicker")
        compare(picker.tabs.length, 0)
    }

    function test_the_cursor_picker_can_import_and_delete() {
        prefs.cursorThemeSplit = false
        page.item.tab = "cursor"
        wait(50)
        var card = findObject(page.item, "cursorSharedCard")
        var picker = findObject(card, "cursorThemePicker")
        compare(picker.actions.length, 2)
        compare(picker.actions[0].key, "import")
        compare(picker.actions[1].key, "delete")
        compare(picker.actions[1].enabled, true)
    }

    function test_the_switches_write_the_preferences() {
        page.item.tab = "cursor"
        wait(50)
        var adaptive = findObject(page.item, "cursorAdaptiveSwitch")
        var mono = findObject(page.item, "cursorMonochromeSwitch")
        verify(adaptive !== null && mono !== null)
        adaptive.toggled(false)
        compare(prefs.cursorAdaptive, false)
        compare(mono.enabled, false)
        adaptive.toggled(true)
        compare(prefs.cursorAdaptive, true)
        compare(mono.enabled, true)
        mono.toggled(true)
        compare(prefs.cursorMonochrome, true)
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
