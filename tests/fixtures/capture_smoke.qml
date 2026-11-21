import Quickshell
import QtQuick
import "bar/capture"

// Loaded by tests/qml_smoke.sh inside a real (offscreen) Quickshell process.
// The toolbar, the question and result cards, the pinned area and the editor are the
// overlay's whole UI (Items, so they load without a Wayland output: the
// overlay's layer surfaces need a compositor); a QML error in them or in the
// kit they are made of makes createObject() return null.
ShellRoot {
    Item {
        id: host

        width: 1920
        height: 1080

        Component {
            id: toolbar

            CaptureToolbar {
                mode: "shot"
                timer: 3
                t: function (key) {
                    return key
                }
            }
        }

        Component {
            id: answer

            CaptureCard {
                phase: "done"
                text: "hello"
                url: "https://example.org"
                t: function (key) {
                    return key
                }
            }
        }

        Component {
            id: pinned

            PinCard {
                image: ""
                t: function (key) {
                    return key
                }
            }
        }

        Component {
            id: editing

            EditorCard {
                imageWidth: 400
                imageHeight: 300
                t: function (key) {
                    return key
                }
            }
        }

        Component {
            id: question

            CaptureAsk {
                t: function (key) {
                    return key
                }
            }
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            var item = toolbar.createObject(host, { x: 0, y: 0 })
            var card = question.createObject(host, { x: 0, y: 100 })
            var result = answer.createObject(host, { x: 0, y: 200 })
            var pin = pinned.createObject(host, { x: 0, y: 400 })
            var editor = editing.createObject(host, { x: 0, y: 500 })
            if (!item || !card || !result || !pin || !editor) {
                console.error("capture smoke: the toolbar did not load")
                Qt.exit(1)
            } else if (!(item.implicitWidth > 0 && item.implicitHeight > 0 && card.implicitWidth > 0 && result.implicitWidth > 0 && pin.implicitWidth > 0 && editor.implicitWidth > 0 && editor.implicitHeight > 0)) {
                console.error("capture smoke: the toolbar has no size")
                Qt.exit(1)
            } else {
                console.log("capture smoke: loaded")
                Qt.exit(0)
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            console.error("capture smoke: timed out")
            Qt.exit(1)
        }
    }
}
