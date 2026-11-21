import QtQuick
import QtQuick.Layouts
import ".."
import "../base"
import "../color.js" as Color

// The colour picker: a wheel of every hue and saturation, a tone slider under
// it painted with the colour's own tones, and the hex code. All three are one
// colour and follow each other: typing a code (#RRGGBB or #RGB, with or without
// the #) moves the wheel and the slider, moving them writes the code. A code
// that is not a colour puts the field in its error state and leaves the rest.
//
//   color        the hex it shows; a different value moves the wheel and the
//                field (`adopt(text)` does the same by call, for a value that
//                did not change)
//   hex          (read-only) the colour made so far, "#rrggbb"
//   valid        (read-only) the field holds a colour
//   size         sm / md / lg
//   placeholder  what the empty field says
//   edited       emitted with the hex when the wheel, the slider or the field
//                changes it (not when the colour is set from outside)
//   escaped      Escape in the field (the field takes the key; Enter is not
//                taken, it reaches whatever holds the picker)
ColumnLayout {
    id: root

    property string color: ""
    property string size: "md"
    property string placeholder: ""
    // The colour is kept as hue, saturation and lightness, so a grey or a black
    // (that any hue makes) does not lose the hue the wheel is on.
    property real hue: 0
    property real saturation: 1
    property real lightness: 0.5

    signal edited(string hex)
    signal escaped()

    readonly property string hex: Color.hslToHex(root.hue, root.saturation, root.lightness)
    readonly property bool valid: Color.normalizeHex(code.text) !== ""

    // Sets the colour from a code, the field included.
    function adopt(text) {
        var next = Color.normalizeHex(text)
        if (next === "")
            return
        if (next !== root.hex)
            root.follow(next)
        code.text = next
    }

    function follow(next) {
        var from = Color.hexToHsl(next)
        root.hue = from.h
        root.saturation = from.s
        root.lightness = from.l
    }

    function change(hue, saturation, lightness) {
        root.hue = hue
        root.saturation = saturation
        root.lightness = lightness
        code.text = root.hex
        root.edited(root.hex)
    }

    function focusCode() {
        code.forceActiveFocus()
    }

    spacing: VitrailTokens.gap("md")
    onColorChanged: root.adopt(root.color)
    Component.onCompleted: {
        root.adopt(root.color)
        code.text = root.hex
    }

    VitrailColorWheel {
        Layout.alignment: Qt.AlignHCenter
        size: root.size
        hue: root.hue
        saturation: root.saturation
        marker: root.hex
        onPicked: function (hue, saturation) { root.change(hue, saturation, root.lightness) }
    }

    VitrailToneSlider {
        Layout.fillWidth: true
        size: root.size
        hue: root.hue
        saturation: root.saturation
        tone: root.lightness
        marker: root.hex
        onMoved: function (tone) { root.change(root.hue, root.saturation, tone) }
    }

    VitrailField {
        id: code

        Layout.fillWidth: true
        size: root.size
        leadingIcon: "tag"
        placeholder: root.placeholder
        error: !root.valid
        onTextChanged: {
            var typed = Color.normalizeHex(code.text)
            if (typed !== "" && typed !== root.hex) {
                root.follow(typed)
                root.edited(root.hex)
            }
        }
        onEscaped: root.escaped()
    }
}
