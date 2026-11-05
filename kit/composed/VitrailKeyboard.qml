import QtQuick
import QtQuick.Layouts
import ".."
import "../base"
import "keyboard.js" as Keyboard

// The on-screen keyboard, shared by the bar, the login and the lock. It knows
// the layouts and the keys, never how text is written: `typed` carries a
// character, `key` a special key name (BackSpace, Return, Tab), and
// `layoutRequested` asks the host for the next language. The host owns the
// focus and the destination field.
Item {
    id: root

    // es / en / de / fr / it / pt; anything else falls back to en.
    property string layout: "en"
    // The layout currently drawn: `layout`, or the one the language button
    // cycled to while the host keeps `layout` for its own state.
    property string shownLayout: "en"
    // Shift is a local toggle: it uppercases the next letters only.
    property bool shifted: false

    signal typed(string text)
    signal key(string name)
    signal layoutRequested(string layout)

    readonly property var letterRows: Keyboard.rows(root.shownLayout)
    readonly property var digitRow: Keyboard.digits()

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    onLayoutChanged: root.shownLayout = Keyboard.normalise(root.layout)
    Component.onCompleted: root.shownLayout = Keyboard.normalise(root.layout)

    // A key from the visible rows, or one of the special names.
    function press(value) {
        var key = String(value)
        if (key === "shift") {
            root.shifted = !root.shifted
            return
        }
        if (key === "backspace") {
            root.key("BackSpace")
            return
        }
        if (key === "enter") {
            root.key("Return")
            return
        }
        if (key === "tab") {
            root.key("Tab")
            return
        }
        var text = key
        if (root.shifted && /^[a-zñüöäçòàù]$/.test(text))
            text = text.toUpperCase()
        root.typed(text)
    }

    // The language button: the next supported layout, announced to the host.
    function cycle() {
        var at = Keyboard.LANGUAGES.indexOf(root.shownLayout)
        var next = Keyboard.LANGUAGES[(at + 1) % Keyboard.LANGUAGES.length]
        root.shownLayout = next
        root.layoutRequested(next)
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("xs")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Item {
                Layout.fillWidth: true
            }

            VitrailButton {
                size: "sm"
                variant: "outlined"
                tone: "primary"
                icon: "swap_horiz"
                text: root.shownLayout.toUpperCase()
                onClicked: root.cycle()
            }
        }

        Repeater {
            model: root.letterRows

            delegate: RowLayout {
                id: letterRow

                required property var modelData

                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                Repeater {
                    model: letterRow.modelData

                    delegate: VitrailButton {
                        required property string modelData

                        Layout.fillWidth: true
                        size: "sm"
                        variant: "plain"
                        tone: "secondary"
                        text: root.shifted ? modelData.toUpperCase() : modelData
                        onClicked: root.press(modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: root.digitRow

                delegate: VitrailButton {
                    required property string modelData

                    Layout.fillWidth: true
                    size: "sm"
                    variant: "plain"
                    tone: "secondary"
                    text: modelData
                    onClicked: root.press(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            VitrailButton {
                size: "sm"
                variant: root.shifted ? "tonal" : "plain"
                tone: root.shifted ? "primary" : "secondary"
                icon: "shift"
                onClicked: root.press("shift")
            }

            VitrailButton {
                Layout.fillWidth: true
                size: "sm"
                variant: "plain"
                tone: "secondary"
                icon: "space_bar"
                onClicked: root.press(" ")
            }

            VitrailButton {
                size: "sm"
                variant: "plain"
                tone: "secondary"
                icon: "keyboard_tab"
                onClicked: root.press("tab")
            }

            VitrailButton {
                size: "sm"
                variant: "plain"
                tone: "secondary"
                icon: "backspace"
                onClicked: root.press("backspace")
            }

            VitrailButton {
                size: "sm"
                variant: "tonal"
                tone: "primary"
                icon: "keyboard_return"
                onClicked: root.press("enter")
            }
        }
    }
}
