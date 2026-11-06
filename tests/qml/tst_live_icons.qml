import QtQuick
import QtTest

// The shell's icons follow Rounded / Sharp / Outlined at once.
//
// The real settings window is loaded and its preference is changed the way the
// Fonts page does it; every icon Text in it (the header's category glyph, the
// subtabs, the sidebar and the buttons) must be drawn with the chosen family
// without reopening the window.
TestCase {
    id: testCase

    name: "LiveIcons"
    when: windowShown

    // The window writes its preference files here; nothing of the user's is
    // touched.
    readonly property string configDir: "/tmp/vitrail-tst-live-icons"

    property var win: null

    readonly property var families: [
        "Material Symbols Rounded",
        "Material Symbols Sharp",
        "Material Symbols Outlined"
    ]

    function collect(item, out) {
        out.push(item)
        var kids = item.children
        if (!kids || kids.length === undefined)
            return out
        for (var i = 0; i < kids.length; i++)
            collect(kids[i], out)
        return out
    }

    // Every Text the window draws with a Material Symbols family.
    function iconTexts() {
        var all = collect(testCase.win.contentItem, [])
        var found = []
        for (var i = 0; i < all.length; i++) {
            var item = all[i]
            if (item.font !== undefined && item.text !== undefined && item.text !== ""
                    && testCase.families.indexOf(item.font.family) >= 0)
                found.push(item)
        }
        return found
    }

    function test_the_window_icons_follow_the_choice() {
        var component = Qt.createComponent("../../shell/main.qml")
        verify(component.status === Component.Ready, component.errorString())
        testCase.win = component.createObject(null, { "configDir": testCase.configDir })
        verify(testCase.win !== null, "the settings window loads")
        wait(400)

        testCase.win.store.uiIcons = "rounded"
        tryCompare(testCase.win.store, "uiIcons", "rounded")
        wait(100)

        var first = testCase.iconTexts()
        // Header, subtabs, sidebar and buttons: the window draws several.
        verify(first.length > 5)
        for (var i = 0; i < first.length; i++) {
            if (first[i].fontInfo.family !== "Material Symbols Rounded")
                console.log("mismatch:", JSON.stringify(first[i].text),
                            first[i].font.family, "->", first[i].fontInfo.family,
                            "visible:", first[i].visible)
            compare(first[i].fontInfo.family, "Material Symbols Rounded")
        }

        testCase.win.store.uiIcons = "sharp"
        tryCompare(testCase.win.store, "uiIcons", "sharp")
        var sharp = testCase.iconTexts()
        compare(sharp.length, first.length)
        for (var j = 0; j < sharp.length; j++) {
            compare(sharp[j].font.family, "Material Symbols Sharp")
            compare(sharp[j].fontInfo.family, "Material Symbols Sharp")
        }

        testCase.win.store.uiIcons = "outlined"
        tryCompare(testCase.win.store, "uiIcons", "outlined")
        var outlined = testCase.iconTexts()
        for (var k = 0; k < outlined.length; k++)
            compare(outlined[k].fontInfo.family, "Material Symbols Outlined")

        testCase.win.store.uiIcons = "rounded"
        testCase.win.close()
        testCase.win.destroy()
        testCase.win = null
    }
}
