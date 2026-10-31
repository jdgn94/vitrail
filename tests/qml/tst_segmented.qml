import QtQuick
import QtTest
import "../../kit"

// VitrailSegmented: options may carry an icon, before the label or alone.
TestCase {
    id: testCase

    name: "VitrailSegmented"
    when: windowShown
    visible: true
    width: 400
    height: 200

    VitrailPalette {
        id: palette
    }

    Component {
        id: control

        VitrailSegmented {
            current: "a"
            options: [
                { key: "a", label: "Top", icon: "vertical_align_top" },
                { key: "b", label: "Bottom" },
                { key: "c", label: "", icon: "contrast" }
            ]
        }
    }

    SignalSpy {
        id: spy

        signalName: "selected"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make() {
        var box = createTemporaryObject(control, testCase)
        verify(box)
        spy.target = box
        spy.clear()
        return box
    }

    function textOf(item, glyph) {
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.children && child.children.length > 0) {
                var found = textOf(child, glyph)
                if (found)
                    return found
            }
            if (child.text !== undefined && (child.font.family === VitrailTokens.iconFamily) === glyph)
                return child
        }
        return null
    }

    function test_icon_is_drawn_before_the_label() {
        var box = make()
        var first = box.currentItem
        var icon = textOf(first, true)
        var label = textOf(first, false)
        verify(icon && icon.visible)
        compare(icon.text, "vertical_align_top")
        verify(label.visible)
        verify(icon.x < label.x)
    }

    function test_option_without_icon_shows_only_the_label() {
        var box = make()
        var second = box.options.length > 1 ? textOf(box.currentItem.parent.children[1], true) : null
        verify(second)
        verify(!second.visible)
    }

    function test_icon_only_segment_is_narrower_than_a_labelled_one() {
        var box = make()
        var rowItems = box.currentItem.parent.children
        var labelled = rowItems[0]
        var iconOnly = rowItems[2]
        verify(iconOnly.implicitWidth < labelled.implicitWidth)
        verify(!textOf(iconOnly, false).visible)
    }

    function test_chosen_icon_is_filled() {
        var box = make()
        var icon = textOf(box.currentItem, true)
        compare(icon.font.variableAxes["FILL"], 1)
        box.current = "c"
        compare(textOf(box.currentItem, true).font.variableAxes["FILL"], 1)
        compare(icon.font.variableAxes["FILL"], 0)
    }

    function test_click_selects() {
        var box = make()
        mouseClick(box, box.width - 10, box.height / 2)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "c")
    }
}
