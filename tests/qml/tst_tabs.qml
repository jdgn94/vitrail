import QtQuick
import QtTest
import "../../kit"

// VitrailTabs: a tab may carry an icon before its label; Left / Right move
// the current tab.
TestCase {
    id: testCase

    name: "VitrailTabs"
    when: windowShown
    visible: true
    width: 500
    height: 200

    VitrailPalette {
        id: palette
    }

    Component {
        id: control

        VitrailTabs {
            width: 500
            current: "a"
            tabs: [
                { key: "a", label: "Alpha", icon: "palette" },
                { key: "b", label: "Beta" },
                { key: "c", label: "Gamma", icon: "layers" }
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
        var icon = textOf(box.currentItem, true)
        var label = textOf(box.currentItem, false)
        verify(icon && icon.visible)
        compare(icon.text, "palette")
        verify(icon.x < label.x)
        verify(box.currentItem.width >= icon.width + label.width)
    }

    function test_tab_without_icon_shows_only_the_label() {
        var box = make()
        var second = box.currentItem.parent.children[1]
        verify(!textOf(second, true).visible)
        compare(second.implicitWidth, textOf(second, false).implicitWidth)
    }

    function sameColor(a, b) {
        return a.r === b.r && a.g === b.g && a.b === b.b && a.a === b.a
    }

    function test_current_icon_uses_the_accent_colour_only() {
        var box = make()
        var icon = textOf(box.currentItem, true)
        tryVerify(function () { return sameColor(icon.color, box.accent) })
        // No FILL axis anywhere: the active state is the colour.
        verify(icon.font.variableAxes["FILL"] === undefined)
        box.current = "c"
        tryVerify(function () {
            var next = textOf(box.currentItem, true)
            return next !== null && sameColor(next.color, box.accent)
        })
        // The old icon fades back to the normal ink.
        tryVerify(function () { return sameColor(icon.color, box.foreground) })
        verify(icon.font.variableAxes["FILL"] === undefined)
    }

    function test_the_icon_family_follows_the_token() {
        var box = make()
        VitrailTokens.iconVariant = "sharp"
        compare(textOf(box.currentItem, true).font.family, "Material Symbols Sharp")
        VitrailTokens.iconVariant = "rounded"
        compare(textOf(box.currentItem, true).font.family, VitrailTokens.iconFamily)
    }

    function test_keys_move_the_current_tab() {
        var box = make()
        box.forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(spy.signalArguments[0][0], "b")
        keyClick(Qt.Key_Left)
        compare(spy.signalArguments[1][0], "c")
    }

    function test_is_one_keyboard_stop() {
        verify(make().activeFocusOnTab)
    }

    function test_click_selects() {
        var box = make()
        // The empty space after the tabs selects nothing.
        mouseClick(box, box.width - 2, box.height / 2)
        compare(spy.count, 0)
        var first = findChild(box, "tab0")
        verify(first !== null)
        mouseClick(first, first.width / 2, first.height / 2)
        compare(spy.signalArguments[0][0], "a")
    }
}
