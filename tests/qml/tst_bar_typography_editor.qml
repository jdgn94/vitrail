import QtQuick
import QtTest
import "../../shell/pages"
import "../../bar/layouts.js" as Layouts
import "../../kit"

// The desktop editor (Bar → Editor → Desktop): selecting a widget shows its
// Typography section, and the font, weight and italic controls write the
// desktop document like the size and style rows do.
TestCase {
    id: testCase

    name: "BarTypographyEditor"
    when: windowShown
    visible: true
    width: 1000
    height: 800

    VitrailPalette {
        id: palette
    }

    readonly property var paletteObject: palette
    readonly property var strings: ({})
    readonly property var monitors: ({
        available: true,
        monitors: [{ name: "DP-1", width: 1920, height: 1080 },
                   { name: "HDMI-A-1", width: 2560, height: 1440 }]
    })
    readonly property var fonts: ({ fonts: ["Inter", "DejaVu Sans"], monospace: [] })

    Component {
        id: prefsStub

        QtObject {
            property string barLayout: ""
            property string panelLayout: ""
            property string desktopLayout: "{}"
            property string barEdge: "top"
            property string barStyle: ""
            property string barScreens: "primary"
            property bool barOpacityFollow: true
            property real barOpacity: 0.9
            property int barSize: 36
            property string frameStyle: "full"
            property int frameSize: 8
            property int panelSize: 360
            property bool panelPush: false
            property string notificationPosition: "top-right"
            property int notificationMax: 3
            property bool notificationMuted: false
            property int notificationSnooze: 5
            property var notificationUrgentApps: []
            property bool notificationUrgentBypass: false
            property int clipboardMax: 20
            property string mediaStyle: "disc"
            property string trayStyle: "dots"
            property bool barBatteryChip: true
            property bool barBluetoothChip: true
            property bool barKeyboard: true
            property bool osdKeys: true
            property int osdKeyTime: 2000
            property bool osdHotZone: true
            property int osdSize: 200
            property int osdStep: 5
            property int osdBrightnessStep: 5
            property int pomodoroWork: 25
            property int pomodoroRest: 5
            property int pomodoroCycles: 4
            property int timerMinutes: 10
            property bool captureAnnotate: false
            property bool captureCopy: false
            property string captureDir: ""
            property bool captureRecordAudio: false
            property string captureRecordDir: ""
            property string captureRecordRegion: ""
            property bool visualiserEnabled: false
            property int visualiserHeight: 64
            property string visualiserVariant: "bars"
        }
    }

    Component {
        id: pageStub

        BarPage {
            width: 960
            height: 760
            palette: testCase.paletteObject
            strings: testCase.strings
            monitors: testCase.monitors
            fonts: testCase.fonts
            tab: "editor"
            editorSurface: "desktop"
            desktopMonitor: "DP-1"
        }
    }

    function initTestCase() {
        VitrailTokens.configure({
            surface: palette.surface,
            surfaceHigh: palette.surfaceHigh,
            foreground: palette.foreground,
            muted: palette.muted,
            primary: palette.primary,
            accentForeground: palette.accentForeground,
            info: palette.info,
            infoForeground: palette.infoForeground,
            error: palette.error,
            errorForeground: palette.errorForeground
        }, true, "glass", ({}))
    }

    function makePage() {
        var prefs = createTemporaryObject(prefsStub, testCase)
        var page = createTemporaryObject(pageStub, testCase, { prefs: prefs })
        verify(page !== null)
        page.desktopAddWidget("clock")
        return page
    }

    function documentOf(page) {
        return Layouts.effective(page.prefs.desktopLayout, "DP-1", null, "desktop").widgets
    }

    function test_adding_a_widget_selects_it_and_shows_the_typography_section() {
        var page = makePage()
        wait(50)
        compare(page.desktopSelection, "clock")
        var section = findChild(page, "desktopTypography")
        verify(section !== null)
        verify(section.visible)
    }

    function test_the_font_picker_lists_the_shell_fonts_and_inheriting() {
        var page = makePage()
        wait(50)
        var picker = findChild(page, "desktopFontPicker")
        verify(picker !== null)
        var keys = picker.options.map(function (option) { return option.key })
        compare(keys, ["", "Inter", "DejaVu Sans"])
        compare(picker.current, "")
    }

    function test_the_controls_write_the_desktop_document() {
        var page = makePage()
        wait(50)
        findChild(page, "desktopFontPicker").selected("Inter")
        compare(documentOf(page)[0].font, "Inter")
        findChild(page, "desktopWeightPicker").selected("bold")
        compare(documentOf(page)[0].font, "Inter")
        compare(documentOf(page)[0].weight, "bold")
        findChild(page, "desktopItalicSwitch").toggled(true)
        compare(documentOf(page)[0].font, "Inter")
        compare(documentOf(page)[0].weight, "bold")
        compare(documentOf(page)[0].italic, true)
        compare(documentOf(page)[0].size, "md")
        compare(documentOf(page)[0].style, "")
        wait(120)
    }

    function test_inheriting_again_clears_the_override() {
        var page = makePage()
        wait(50)
        findChild(page, "desktopFontPicker").selected("Inter")
        findChild(page, "desktopWeightPicker").selected("bold")
        findChild(page, "desktopItalicSwitch").toggled(true)
        findChild(page, "desktopFontPicker").selected("")
        findChild(page, "desktopWeightPicker").selected("")
        findChild(page, "desktopItalicSwitch").toggled(false)
        compare(documentOf(page)[0].font, "")
        compare(documentOf(page)[0].weight, "")
        compare(documentOf(page)[0].italic, false)
        wait(120)
    }

    function test_the_typography_section_follows_the_selection() {
        var page = makePage()
        wait(50)
        var section = findChild(page, "desktopTypography")
        verify(section.visible)
        page.desktopSelection = ""
        wait(20)
        verify(!section.visible)
    }

    function test_each_widget_keeps_its_own_typography() {
        var page = makePage()
        wait(50)
        page.desktopAddWidget("weather")
        wait(20)
        findChild(page, "desktopFontPicker").selected("DejaVu Sans")
        compare(documentOf(page)[1].font, "DejaVu Sans")
        page.desktopSelection = "clock"
        wait(20)
        findChild(page, "desktopFontPicker").selected("Inter")
        wait(20)
        compare(documentOf(page)[0].font, "Inter")
        compare(documentOf(page)[1].font, "DejaVu Sans")
        wait(120)
    }

    function test_removing_the_selected_widget_clears_the_selection() {
        var page = makePage()
        wait(50)
        page.desktopRemoveWidget("clock")
        wait(20)
        compare(page.desktopSelection, "")
    }
}
