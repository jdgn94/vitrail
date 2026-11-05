import QtQuick
import QtTest
import "../../kit"
import "../../kit/composed"
import "../../kit/composed/keyboard.js" as Keyboard

// VitrailKeyboard: the shared on-screen keyboard. It draws the language rows
// and turns a key into `typed` / `key`, leaving the writing to its host.
TestCase {
    id: testCase

    name: "VitrailKeyboard"
    when: windowShown
    visible: true
    width: 420
    height: 400

    VitrailPalette {
        id: palette
    }

    Component {
        id: control

        VitrailKeyboard {
            width: 380
        }
    }

    SignalSpy {
        id: typedSpy

        signalName: "typed"
    }

    SignalSpy {
        id: keySpy

        signalName: "key"
    }

    SignalSpy {
        id: layoutSpy

        signalName: "layoutRequested"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make() {
        var keyboard = createTemporaryObject(control, testCase)
        verify(keyboard)
        typedSpy.target = keyboard
        keySpy.target = keyboard
        layoutSpy.target = keyboard
        typedSpy.clear()
        keySpy.clear()
        layoutSpy.clear()
        return keyboard
    }

    function test_rows_follow_the_language_and_fall_back_to_en() {
        var keyboard = make()
        compare(keyboard.letterRows.length, 3)
        compare(keyboard.digitRow.length, 10)

        keyboard.layout = "es"
        verify(keyboard.letterRows[1].indexOf("ñ") >= 0)

        keyboard.layout = "de"
        verify(keyboard.letterRows[2].indexOf("y") >= 0)

        keyboard.layout = "xx"
        compare(keyboard.letterRows.join("|"), Keyboard.rows("en").join("|"))
        compare(keyboard.shownLayout, "en")
        verify(keyboard.letterRows[1].indexOf("ñ") < 0)
    }

    function test_a_letter_is_typed_and_shift_uppercases_it() {
        var keyboard = make()

        keyboard.press("a")
        compare(typedSpy.count, 1)
        compare(typedSpy.signalArguments[0][0], "a")

        keyboard.press("shift")
        compare(keyboard.shifted, true)
        keyboard.press("a")
        compare(typedSpy.count, 2)
        compare(typedSpy.signalArguments[1][0], "A")

        keyboard.press(" ")
        compare(typedSpy.count, 3)
        compare(typedSpy.signalArguments[2][0], " ")
    }

    function test_special_keys_use_their_xkb_names() {
        var keyboard = make()

        keyboard.press("backspace")
        compare(keySpy.count, 1)
        compare(keySpy.signalArguments[0][0], "BackSpace")

        keyboard.press("enter")
        compare(keySpy.signalArguments[1][0], "Return")

        keyboard.press("tab")
        compare(keySpy.signalArguments[2][0], "Tab")
    }

    function test_the_language_button_asks_for_the_next_layout() {
        var keyboard = make()

        keyboard.layout = "es"
        keyboard.cycle()
        compare(keyboard.shownLayout, "en")
        compare(layoutSpy.count, 1)
        compare(layoutSpy.signalArguments[0][0], "en")
        verify(keyboard.letterRows[1].indexOf("ñ") < 0)

        keyboard.cycle()
        compare(keyboard.shownLayout, "de")
        compare(layoutSpy.signalArguments[1][0], "de")
    }
}
