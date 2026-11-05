import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "keyboard.js" as Keyboard

// The on-screen keyboard for the active language. It never takes the focus:
// each key runs `wtype`, which types into the window underneath.
Item {
    id: root

    property var strings: ({})
    // The language code of the active layout (an unsupported one falls to en).
    property string language: "en"

    signal keyPressed(var argv)
    signal dismissed()

    property string shown: "en"
    property bool shifted: false

    readonly property var letterRows: Keyboard.rows(root.shown)
    readonly property var digitRow: Keyboard.digits()

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    onLanguageChanged: root.shown = root.language
    Component.onCompleted: root.shown = root.language

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function press(key) {
        var keys = Keyboard.argv(key, root.shifted)
        if (keys)
            root.keyPressed(keys)
    }

    function cycle() {
        var at = Keyboard.LANGUAGES.indexOf(root.shown)
        root.shown = Keyboard.LANGUAGES[(at + 1) % Keyboard.LANGUAGES.length]
    }

    Keys.onEscapePressed: root.dismissed()

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("xs")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.t("keyboard.osk")
            }

            VitrailButton {
                size: "sm"
                variant: "outlined"
                tone: "primary"
                icon: "swap_horiz"
                text: Keyboard.code(root.shown)
                onClicked: root.cycle()
            }

            VitrailButton {
                size: "sm"
                variant: "plain"
                tone: "secondary"
                icon: "close"
                onClicked: root.dismissed()
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
                onClicked: root.shifted = !root.shifted
            }

            VitrailButton {
                Layout.fillWidth: true
                size: "sm"
                variant: "plain"
                tone: "secondary"
                text: root.t("keyboard.osk.space")
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

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            opacity: 0.6
            elide: Text.ElideRight
            text: root.t("keyboard.osk.hint")
        }
    }
}
