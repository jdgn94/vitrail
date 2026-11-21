import QtQuick
import QtQuick.Layouts
import QtTest
import "../../bar"

// BarElementBase: shown/active/showMode, tooltip, hovered/opened interface.
TestCase {
    id: testCase

    name: "BarElementBase"
    when: windowShown
    visible: true
    width: 400
    height: 100

    Component {
        id: baseComponent

        BarElementBase {
            icon: "widgets"
            tooltip: "Test element"
            tooltipDetail: "Opens something"
        }
    }

    Component {
        id: activeOnlyComponent

        BarElementBase {
            icon: "tune"
            tooltip: "Active-only"
            showMode: "active"
            active: false
        }
    }

    function test_shown_always() {
        var item = createTemporaryObject(baseComponent, testCase)
        verify(item !== null)
        compare(item.shown, true)
        item.destroy()
    }

    function test_shown_active_false() {
        var item = createTemporaryObject(activeOnlyComponent, testCase)
        verify(item !== null)
        compare(item.shown, false)
        item.destroy()
    }

    function test_shown_active_becomes_true() {
        var item = createTemporaryObject(activeOnlyComponent, testCase)
        verify(item !== null)
        compare(item.shown, false)
        item.active = true
        compare(item.shown, true)
        item.destroy()
    }

    function test_tooltip_exposed() {
        var item = createTemporaryObject(baseComponent, testCase)
        verify(item !== null)
        compare(item.tooltip, "Test element")
        compare(item.tooltipDetail, "Opens something")
        item.destroy()
    }

    function test_opened_property() {
        var item = createTemporaryObject(baseComponent, testCase)
        verify(item !== null)
        compare(item.opened, false)
        item.opened = true
        compare(item.opened, true)
        item.destroy()
    }

    function test_has_implicit_size() {
        var item = createTemporaryObject(baseComponent, testCase)
        verify(item !== null)
        verify(item.implicitWidth > 0)
        verify(item.implicitHeight > 0)
        item.destroy()
    }
}
