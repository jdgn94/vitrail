import QtQuick
import QtTest
import "../../bar/dock"
import "../../bar/dock/dock.js" as DockJS
import "../../bar/desktop"
import "../../kit"

// The dock: its two states and two surfaces, hover magnification, pinned
// order, the open windows it appends, the reveal, the launcher's
// pin/unpin rows and the Dock tab of the in-place editor.
TestCase {
    id: testCase

    name: "Dock"
    when: windowShown
    visible: true
    width: 900
    height: 700

    VitrailPalette {
        id: palette
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

    function pin(id, name) {
        return { id: id, desktop: id, name: name || id, icon: id.replace(/\.desktop$/, "") }
    }

    function pinnedList() {
        return [pin("firefox.desktop", "Firefox"), pin("kitty.desktop", "Kitty"),
                pin("code.desktop", "Code")]
    }

    function windowOf(address, klass, title, active) {
        return { address: address, class: klass, title: title || klass, active: active === true }
    }

    Component {
        id: dockComponent

        Dock {
            width: 320
            height: 64
            strings: ({ "dock.tooltip.open": "Open window", "dock.tooltip.launch": "Open app" })
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
        }
    }

    function watch(target, signalName) {
        return createTemporaryObject(spyComponent, testCase, { target: target, signalName: signalName })
    }

    // --- states and surfaces ------------------------------------------------

    function test_open_and_closed_states() {
        verify(DockJS.shown(false, false, false))
        verify(!DockJS.shown(true, false, false))
        verify(DockJS.shown(true, true, false))
        verify(DockJS.shown(true, false, true))
        verify(DockJS.shown(false, false, false))
    }

    function test_attached_is_flush_and_floating_keeps_its_margin() {
        compare(DockJS.radius(true, 14), 0)
        compare(DockJS.radius(false, 14), 14)
        compare(DockJS.margin(true, 8), 0)
        compare(DockJS.margin(false, 8), 8)

        var bottom = DockJS.place("bottom", 200, 70, 60, 50, 8, 1)
        compare(bottom.x, 70)
        compare(bottom.y, 12)
        var hidden = DockJS.place("bottom", 200, 70, 60, 50, 8, 0)
        compare(hidden.y, 70)
        var top = DockJS.place("top", 200, 70, 60, 50, 8, 1)
        compare(top.y, 8)
        var left = DockJS.place("left", 70, 200, 50, 60, 8, 1)
        compare(left.x, 8)
        compare(left.y, 70)
        var right = DockJS.place("right", 70, 200, 50, 60, 8, 0)
        compare(right.x, 70)
    }

    // --- magnification ------------------------------------------------------

    function test_magnification_styles() {
        var spec = { scale: 1.3, lift: 8, reach: 2 }
        compare(DockJS.magnify("none", 0, spec).scale, 1)
        compare(DockJS.magnify("none", 0, spec).lift, 0)
        compare(DockJS.magnify("scale", 0, spec).lift, 0)
        compare(DockJS.magnify("scale", 0, spec).scale, 1.3)
        compare(DockJS.magnify("lift", 0, spec).lift, 8)
        compare(DockJS.magnify("lift", 0, spec).scale, 1.3)
        var neighbor = DockJS.magnify("scale", 1, spec)
        verify(neighbor.scale > 1 && neighbor.scale < 1.3)
        compare(DockJS.magnify("lift", 3, spec).scale, 1)
    }

    // --- pinned order -------------------------------------------------------

    function test_a_drag_writes_the_pinned_order() {
        compare(DockJS.move(pinnedList(), 0, 2).map(function (p) { return p.name }).join(","),
                "Kitty,Code,Firefox")
        compare(DockJS.dropIndex(0, 50, 48, 3), 1)
        compare(DockJS.dropIndex(0, 100, 48, 3), 2)
        compare(DockJS.dropIndex(2, -300, 48, 3), 0)

        var dock = createTemporaryObject(dockComponent, testCase, { pinned: pinnedList() })
        var spy = watch(dock, "reordered")
        dock.movePinned(0, 2)
        compare(spy.count, 1)
        var order = JSON.parse(spy.signalArguments[0][0]).map(function (p) { return p.name })
        compare(order.join(","), "Kitty,Code,Firefox")
    }

    // --- open windows -------------------------------------------------------

    function test_open_windows_are_appended_and_pinned_ones_are_marked() {
        var model = DockJS.model(pinnedList(), [
            windowOf("0x1", "firefox", "Docs", true),
            windowOf("0x2", "nautilus", "Files", false)
        ])
        compare(model.length, 4)
        compare(model[0].kind, "pinned")
        compare(model[0].open, true)
        compare(model[0].active, true)
        compare(model[0].address, "0x1")
        compare(model[3].kind, "open")
        compare(model[3].name, "nautilus")
        compare(model[3].open, true)
    }

    function test_click_launches_a_closed_app_and_focuses_an_open_one() {
        var dock = createTemporaryObject(dockComponent, testCase, { pinned: [pin("firefox.desktop", "Firefox")] })
        var launch = watch(dock, "launchRequested")
        var focus = watch(dock, "focusRequested")
        var item = findChild(dock, "dockItem.pinned:firefox")
        verify(item !== null)
        mouseClick(item, item.width / 2, item.height / 2)
        compare(launch.count, 1)
        compare(focus.count, 0)
        compare(launch.signalArguments[0][0].name, "Firefox")

        var openDock = createTemporaryObject(dockComponent, testCase, {
            pinned: [pin("firefox.desktop", "Firefox")],
            windows: [windowOf("0xabc", "firefox", "Docs", true)]
        })
        var openFocus = watch(openDock, "focusRequested")
        var openItem = findChild(openDock, "dockItem.pinned:firefox")
        mouseClick(openItem, openItem.width / 2, openItem.height / 2)
        compare(openFocus.count, 1)
        compare(openFocus.signalArguments[0][0].address, "0xabc")
    }

    // --- auto-hide ----------------------------------------------------------

    function test_an_auto_hidden_dock_can_reveal_itself() {
        var dock = createTemporaryObject(dockComponent, testCase, {
            autohide: true, revealed: false, pinned: pinnedList()
        })
        verify(!dock.shown)
        compare(dock.progress, 0)
        dock.revealed = true
        verify(dock.shown)
        tryCompare(dock, "progress", 1, 1000)
        dock.revealed = false
        verify(!dock.shown)
        tryCompare(dock, "progress", 0, 1000)
    }

    // --- the launcher's pin/unpin row --------------------------------------

    function test_the_launcher_menu_pins_and_unpins_the_dock() {
        var labels = { pin: "Pin to dock", unpin: "Remove from dock" }
        var item = { id: "firefox.desktop", name: "Firefox", icon: "firefox", exec: "firefox" }
        var row = DockJS.menuRow("[]", item, labels)
        compare(row.title, "Pin to dock")
        compare(row.glyph, "dock")
        compare(row.run.kind, "dockPin")
        compare(row.dock, false)

        var pinned = DockJS.serializePinned([pin("firefox.desktop", "Firefox")])
        row = DockJS.menuRow(pinned, item, labels)
        compare(row.title, "Remove from dock")
        compare(row.glyph, "remove")
        compare(row.dock, true)
    }

    // --- the editor's Dock tab ---------------------------------------------

    Component {
        id: editorComponent

        DesktopEditMode {
            width: 900
            height: 700
            monitor: "DP-1"
            strings: ({ "dock.enabled": "Show the dock", "dock.edge": "Edge",
                        "dock.autohide": "Hide until the pointer reaches the edge",
                        "dock.attach": "Position", "dock.attached": "Attached",
                        "dock.floating": "Floating", "dock.magnify": "Magnification",
                        "dock.pinned": "Pinned apps",
                        "dock.pinned.empty": "Pin apps from the launcher's menu.",
                        "dock.widgets": "Dock widgets",
                        "dock.widgetsNotice": "Widgets arrive in the next phase.",
                        "dock.edge.bottom": "Bottom", "dock.edge.top": "Top",
                        "dock.edge.left": "Left", "dock.edge.right": "Right",
                        "dock.magnify.none": "None", "dock.magnify.scale": "Scale",
                        "dock.magnify.lift": "Lift" })
            dock: ({ enabled: false, edge: "bottom", autohide: false, attached: true,
                     magnify: "scale", pinned: "[]" })
        }
    }

    function test_the_editor_has_a_dock_tab_with_every_option() {
        var editor = createTemporaryObject(editorComponent, testCase, { active: true })
        wait(20)
        compare(editor.tabs.map(function (tab) { return tab.key }), ["bar", "desktop", "dock", "panel"])
        editor.tab = "dock"
        wait(20)
        verify(findChild(editor, "desktopEditDock").visible)
        for (var i = 0; i < ["dockEnabled", "dockEdge", "dockAutohide", "dockAttached",
                             "dockMagnify", "dockWidgetArea"].length; i++) {
            var name = ["dockEnabled", "dockEdge", "dockAutohide", "dockAttached",
                        "dockMagnify", "dockWidgetArea"][i]
            verify(findChild(editor, name) !== null, name)
        }
    }

    function test_the_editor_writes_each_dock_preference() {
        var editor = createTemporaryObject(editorComponent, testCase, { active: true })
        var spy = watch(editor, "prefChanged")
        wait(20)
        editor.setDock("dockEnabled", true)
        compare(spy.signalArguments[0][0], "dockEnabled")
        compare(spy.signalArguments[0][1], true)
        editor.setDock("dockEdge", "left")
        compare(spy.signalArguments[1][0], "dockEdge")
        compare(spy.signalArguments[1][1], "left")
        editor.setDock("dockAttached", false)
        compare(spy.signalArguments[2][1], false)
        editor.setDock("dockMagnify", "lift")
        compare(spy.signalArguments[3][1], "lift")
    }

    function test_the_editor_reorders_and_removes_pinned_apps() {
        var editor = createTemporaryObject(editorComponent, testCase, {
            active: true,
            dock: ({ enabled: true, edge: "bottom", autohide: false, attached: true,
                     magnify: "scale", pinned: DockJS.serializePinned(pinnedList()) })
        })
        var spy = watch(editor, "prefChanged")
        wait(20)
        compare(editor.dockPinnedList.length, 3)
        editor.moveDockPin(0, 1)
        var order = JSON.parse(spy.signalArguments[0][1]).map(function (p) { return p.name })
        compare(order.join(","), "Kitty,Firefox,Code")
        editor.removeDockPin(editor.dockPinnedList[0])
        var left = JSON.parse(spy.signalArguments[1][1]).map(function (p) { return p.name })
        compare(left.join(","), "Kitty,Code")
    }
}
