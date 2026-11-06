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
                iconPreviews: {}, cursorPreviews: {}
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
}
