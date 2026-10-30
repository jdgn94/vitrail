import QtQuick
import QtTest
import "../../kit"
import "../../kit/base"
import "../../kit/shapes.js" as Shapes

// VitrailField: one shape per password character, the eye, the floating label.
TestCase {
    id: testCase

    name: "VitrailField"
    when: windowShown
    visible: true
    width: 400
    height: 300

    VitrailPalette {
        id: palette
    }

    TextInput {
        id: clip

        visible: false
    }

    Component {
        id: secret

        VitrailField {
            width: 300
            label: "Password"
            type: "password"
        }
    }

    Component {
        id: plain

        VitrailField {
            width: 300
            label: "Name"
            variant: "filled"
        }
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var field = createTemporaryObject(component, testCase)
        verify(field)
        field.forceActiveFocus()
        tryVerify(function () { return field.focused })
        return field
    }

    function test_one_shape_per_typed_character() {
        var field = make(secret)
        compare(field.shapeCount, 0)
        keyClick("a")
        keyClick("b")
        keyClick("c")
        compare(field.text, "abc")
        compare(field.shapeCount, 3)
    }

    function test_backspace_and_delete_remove_shapes() {
        var field = make(secret)
        keyClick("a"); keyClick("b"); keyClick("c")
        keyClick(Qt.Key_Backspace)
        compare(field.shapeCount, 2)
        keyClick(Qt.Key_Left)
        keyClick(Qt.Key_Delete)
        compare(field.text, "a")
        compare(field.shapeCount, 1)
    }

    function test_insertion_in_the_middle_keeps_the_neighbours() {
        var field = make(secret)
        keyClick("a"); keyClick("b"); keyClick("c")
        var before = field.shapeKinds()
        keyClick(Qt.Key_Home)
        keyClick(Qt.Key_Right)
        keyClick("x")
        compare(field.text, "axbc")
        var after = field.shapeKinds()
        compare(after.length, 4)
        compare(after[0], before[0])
        compare(after[2], before[1])
        compare(after[3], before[2])
        verify(after[1] !== before[0])
    }

    function test_paste_adds_one_shape_per_character() {
        var field = make(secret)
        keyClick("a")
        clip.text = "hunter2"
        clip.selectAll()
        clip.copy()
        field.forceActiveFocus()
        keySequence(StandardKey.Paste)
        compare(field.text, "ahunter2")
        compare(field.shapeCount, 8)
    }

    function test_select_all_and_delete_clears_the_shapes() {
        var field = make(secret)
        keyClick("a"); keyClick("b"); keyClick("c")
        keySequence(StandardKey.SelectAll)
        keyClick(Qt.Key_Backspace)
        compare(field.text, "")
        compare(field.shapeCount, 0)
    }

    function test_no_two_neighbouring_shapes_repeat() {
        var field = make(secret)
        for (var i = 0; i < 40; i++)
            keyClick("a")
        var kinds = field.shapeKinds()
        for (var j = 1; j < kinds.length; j++)
            verify(kinds[j] !== kinds[j - 1])
    }

    function test_password_shapes_are_only_the_distinct_ones() {
        var field = make(secret)
        for (var i = 0; i < 60; i++)
            keyClick("a")
        var kinds = field.shapeKinds()
        compare(kinds.length, 60)
        for (var j = 0; j < kinds.length; j++)
            verify(Shapes.distinct.indexOf(kinds[j]) >= 0, kinds[j])
    }

    function test_clearing_the_text_from_code_clears_the_shapes() {
        var field = make(secret)
        field.text = "hello"
        compare(field.shapeCount, 5)
        field.text = ""
        compare(field.shapeCount, 0)
    }

    function test_eye_toggles_revealed_and_keeps_focus() {
        var field = make(secret)
        var eye = findChild(field, "eye")
        verify(eye)
        compare(field.revealed, false)
        mouseClick(eye)
        compare(field.revealed, true)
        verify(field.focused)
        mouseClick(eye)
        compare(field.revealed, false)
    }

    function test_text_fields_have_no_eye_and_no_shapes() {
        var field = make(plain)
        verify(!findChild(field, "eye").visible)
        keyClick("a")
        compare(field.shapeCount, 0)
    }

    function test_label_floats_on_focus_and_with_text() {
        var field = createTemporaryObject(plain, testCase)
        compare(field.floated, false)
        tryCompare(field, "labelLift", 0)
        field.forceActiveFocus()
        tryCompare(field, "labelLift", 1)
        keyClick("a")
        field.focus = false
        testCase.forceActiveFocus()
        tryCompare(field, "focused", false)
        compare(field.floated, true)
        tryCompare(field, "labelLift", 1)
    }

    function test_enter_and_escape_are_signalled() {
        var field = make(plain)
        var accepted = 0, escaped = 0
        field.accepted.connect(function () { accepted++ })
        field.escaped.connect(function () { escaped++ })
        keyClick(Qt.Key_Return)
        keyClick(Qt.Key_Escape)
        compare(accepted, 1)
        compare(escaped, 1)
    }
}
