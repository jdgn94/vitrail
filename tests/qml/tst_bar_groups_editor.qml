import QtQuick
import QtTest
import "../../shell/pages"
import "../../bar/layouts.js" as Layouts
import "../../kit"

// The bar's Editor tab with free placement, chips and dividers: an element
// moves to any group (a chip by its token), the fixed elements keep theirs,
// chips are created, filled and removed, and a divider is added and removed —
// all while visibility, density and per-monitor overrides survive.
TestCase {
    id: testCase

    name: "BarGroupsEditor"
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

    Component {
        id: prefsStub

        QtObject {
            property string barLayout: ""
            property string panelLayout: ""
            property string desktopLayout: "{}"
            property bool desktopMenu: true
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
            tab: "editor"
            editorSurface: "bar"
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
        wait(50)
        return page
    }

    function documentOf(page, monitor) {
        return Layouts.sanitize(page.prefs.barLayout)
    }

    function test_the_group_selector_moves_an_element() {
        var page = makePage()
        var picker = findChild(page, "barEditorGroup-clock")
        verify(picker !== null)
        picker.selected("start")
        wait(50)
        var doc = documentOf(page)
        verify(doc.order.start.indexOf("clock") >= 0)
        compare(doc.order.center.indexOf("clock"), -1)
        verify(findChild(page, "barEditorEntry-clock") !== null)
    }

    function test_a_fixed_element_keeps_its_group() {
        var page = makePage()
        verify(findChild(page, "barEditorEntry-launcher") !== null)
        var picker = findChild(page, "barEditorGroup-launcher")
        verify(picker !== null)
        verify(!picker.visible)
        compare(page.entryDescription("launcher"), "bar.editor.fixed")
        page.moveEntry("launcher", "end")
        wait(20)
        compare(documentOf(page).order.start.indexOf("launcher"), 0)
        verify(documentOf(page).order.end.indexOf("launcher") < 0)
    }

    function test_a_divider_is_added_and_removed_from_the_group_card() {
        var page = makePage()
        var add = findChild(page, "barAddDivider-center")
        verify(add !== null)
        add.clicked()
        wait(50)
        var doc = documentOf(page)
        compare(doc.order.center[doc.order.center.length - 1], "divider")
        verify(findChild(page, "barEditorEntry-divider") !== null)
        var remove = findChild(page, "barEditorRemove-divider")
        verify(remove !== null)
        remove.clicked()
        wait(50)
        compare(documentOf(page).order.center.indexOf("divider"), -1)
    }

    function test_a_divider_moves_to_another_group() {
        var page = makePage()
        findChild(page, "barAddDivider-center").clicked()
        wait(50)
        findChild(page, "barEditorGroup-divider").selected("start")
        wait(50)
        var doc = documentOf(page)
        verify(doc.order.start.indexOf("divider") >= 0)
        compare(doc.order.center.indexOf("divider"), -1)
    }

    function test_a_chip_is_created_filled_and_removed() {
        var page = makePage()
        findChild(page, "barAddChip-end").clicked()
        wait(50)
        var doc = documentOf(page)
        verify(doc.chips["chip-1"] !== undefined)
        compare(doc.chips["chip-1"].members, [])
        verify(doc.order.end.indexOf("@chip-1") >= 0)

        findChild(page, "barChipAdd-chip-1-clock").clicked()
        wait(50)
        doc = documentOf(page)
        compare(doc.chips["chip-1"].members, ["clock"])
        compare(doc.order.center.indexOf("clock"), -1)

        findChild(page, "barChipRemove-chip-1-clock").clicked()
        wait(50)
        doc = documentOf(page)
        compare(doc.chips["chip-1"].members, [])
        var at = doc.order.end.indexOf("@chip-1")
        compare(doc.order.end[at + 1], "clock")

        findChild(page, "barEditorRemove-@chip-1").clicked()
        wait(50)
        doc = documentOf(page)
        compare(doc.chips["chip-1"], undefined)
        compare(doc.order.end.indexOf("@chip-1"), -1)
    }

    function test_a_chip_member_keeps_its_visibility_switch() {
        var page = makePage()
        var toggle = findChild(page, "barChipVisible-connections-bluetooth")
        verify(toggle !== null)
        toggle.toggled(false)
        wait(50)
        verify(documentOf(page).hidden.indexOf("bluetooth") >= 0)
        var entry = Layouts.entries(documentOf(page).order.end, documentOf(page).hidden,
                                    "bar", documentOf(page).chips)
        compare(entry[2].ids, ["network", "vpn", "profile"])
        toggle.toggled(true)
        wait(50)
        compare(documentOf(page).hidden.indexOf("bluetooth"), -1)
    }

    function test_the_connection_chip_can_lose_a_member() {
        var page = makePage()
        findChild(page, "barChipRemove-connections-bluetooth").clicked()
        wait(50)
        var doc = documentOf(page)
        compare(doc.chips.connections.members, ["network", "vpn", "profile"])
        var at = doc.order.end.indexOf("@connections")
        compare(doc.order.end[at + 1], "bluetooth")
    }

    function test_a_monitor_override_keeps_the_global_bar() {
        var page = makePage()
        page.commitGlobal({ density: "compact" })
        page.monitor = "DP-1"
        wait(20)
        page.moveEntry("clock", "start")
        wait(50)
        var doc = documentOf(page)
        compare(doc.monitors["DP-1"].order.start.indexOf("clock") >= 0, true)
        compare(doc.order.center.indexOf("clock") >= 0, true)
        compare(doc.density, "compact")
        compare(Layouts.effective(page.prefs.barLayout, "HDMI-A-1").order.center,
                ["title", "media", "clock"])
    }

    function test_moving_an_element_keeps_its_visibility() {
        var page = makePage()
        page.setVisible("clock", false)
        wait(20)
        page.moveEntry("clock", "start")
        wait(50)
        var doc = documentOf(page)
        verify(doc.hidden.indexOf("clock") >= 0)
        verify(doc.order.start.indexOf("clock") >= 0)
    }
}
