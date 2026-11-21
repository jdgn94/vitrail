import QtQuick
import QtQuick.Layouts
import QtTest
import "../../bar"
import "../../bar/sample"
import "../../bar/elements.js" as Elements

// BarElementBase and the pieces every bar element shares: the "only while
// active" switch, the four inputs, the custom face, the sample element built
// on them, and bar/elements.js.
TestCase {
    id: testCase

    name: "BarElements"
    when: windowShown
    visible: true
    width: 400
    height: 200

    Component {
        id: baseComponent

        BarElementBase {
            width: 40
            height: 40
            icon: "widgets"
            tooltip: "Test element"
            tooltipDetail: "Opens something"
            strings: ({ "known": "Known" })
        }
    }

    Component {
        id: activeOnlyComponent

        BarElementBase {
            icon: "tune"
            showMode: "active"
            active: false
        }
    }

    Component {
        id: faceComponent

        BarElementBase {
            width: 40
            height: 40
            content: Component {
                Item {
                    implicitWidth: 18
                    implicitHeight: 12
                }
            }
        }
    }

    Component {
        id: sampleButton

        SampleButton {
            strings: ({ "bar.widget.sample.run": "Run #%1", "bar.widget.sample.unavailable": "No data" })
        }
    }

    Component {
        id: samplePanel

        SamplePanel {
            width: 320
            height: 80
            strings: ({ "bar.widget.sample.run": "Run #%1", "bar.widget.sample.updated": "At %1" })
            snapshot: ({ counter: 3, updated: 1763750000 })
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }
    SignalSpy { id: middles; signalName: "middleClicked" }
    SignalSpy { id: rights; signalName: "rightClicked" }
    SignalSpy { id: wheels; signalName: "wheeled" }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    function test_always_is_shown_whatever_active_says() {
        var item = make(baseComponent)
        item.active = false
        compare(item.shown, true)
    }

    function test_active_only_follows_active() {
        var item = make(activeOnlyComponent)
        compare(item.shown, false)
        item.active = true
        compare(item.shown, true)
        item.showMode = "always"
        item.active = false
        compare(item.shown, true)
    }

    function test_tooltip_and_translation_are_exposed() {
        var item = make(baseComponent)
        compare(item.tooltip, "Test element")
        compare(item.tooltipDetail, "Opens something")
        compare(item.t("known"), "Known")
        compare(item.t("missing"), "missing")
    }

    function test_the_button_sizes_the_element() {
        var item = make(activeOnlyComponent)
        verify(item.implicitWidth > 0)
        verify(item.implicitHeight > 0)
    }

    function test_left_click_emits_clicked() {
        var item = make(baseComponent)
        clicks.target = item
        clicks.clear()
        mouseClick(item, 20, 20, Qt.LeftButton)
        compare(clicks.count, 1)
    }

    function test_middle_and_right_click_are_their_own_signals() {
        var item = make(baseComponent)
        clicks.target = item
        middles.target = item
        rights.target = item
        clicks.clear(); middles.clear(); rights.clear()
        mouseClick(item, 20, 20, Qt.MiddleButton)
        compare(middles.count, 1)
        mouseClick(item, 20, 20, Qt.RightButton)
        compare(rights.count, 1)
        compare(clicks.count, 0)
    }

    function test_the_wheel_reports_its_delta() {
        var item = make(baseComponent)
        wheels.target = item
        wheels.clear()
        mouseWheel(item, 20, 20, 0, 120)
        compare(wheels.count, 1)
        compare(wheels.signalArguments[0][0], 120)
    }

    function test_a_custom_face_replaces_the_button_and_keeps_the_click() {
        var item = make(faceComponent)
        compare(item.implicitWidth, 18)
        compare(item.implicitHeight, 12)
        clicks.target = item
        clicks.clear()
        mouseClick(item, 5, 5, Qt.LeftButton)
        compare(clicks.count, 1)
    }

    function test_the_sample_is_only_active_with_a_good_snapshot() {
        var item = make(sampleButton)
        compare(item.active, false)
        compare(item.tooltip, "No data")
        item.snapshot = { counter: 4, updated: 1 }
        compare(item.active, true)
        compare(item.tooltip, "Run #4")
        item.snapshot = { counter: 4, updated: 1, error: "cache" }
        compare(item.active, false)
        item.snapshot = { error: "unreadable" }
        compare(item.active, false)
    }

    function test_the_sample_hides_itself_when_the_user_asks_for_active_only() {
        var item = make(sampleButton)
        item.showMode = Elements.showMode(Elements.parseActiveOnly('["sample"]'), "sample")
        compare(item.shown, false)
        item.snapshot = { counter: 1, updated: 1 }
        compare(item.shown, true)
    }

    function test_the_sample_popup_gear_asks_for_settings() {
        var panel = make(samplePanel)
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }

    function test_show_mode_round_trips_through_the_preference() {
        compare(Elements.parseActiveOnly(""), [])
        compare(Elements.parseActiveOnly("not json"), [])
        compare(Elements.parseActiveOnly('{"a":1}'), [])
        compare(Elements.parseActiveOnly('["a","a",3,""]'), ["a"])
        compare(Elements.showMode(["a"], "a"), "active")
        compare(Elements.showMode(["a"], "b"), "always")
        compare(Elements.withShowMode([], "a", "active"), '["a"]')
        compare(Elements.withShowMode(["a", "b"], "a", "always"), '["b"]')
        compare(Elements.withShowMode(["a"], "a", "active"), '["a"]')
    }

    function test_a_snapshot_that_is_not_an_object_is_an_error_not_stale_data() {
        compare(Elements.snapshot('{"counter":2}').counter, 2)
        compare(Elements.snapshot("").error, "unreadable")
        compare(Elements.snapshot("Traceback (most recent call last)").error, "unreadable")
        compare(Elements.snapshot("[1]").error, "unreadable")
        compare(Elements.snapshot("null").error, "unreadable")
    }
}
