import QtQuick
import "kit"

// One bar popout. It loads while it is the current one; leaving, it fades
// out before unloading, arriving it loads and fades in, so the shared card
// can glide to the next button and cross-fade between contents.
Loader {
    id: popout

    required property string name
    property string current: ""

    readonly property bool shouldBeActive: popout.current === popout.name

    anchors.centerIn: parent
    active: false
    opacity: 0

    states: State {
        name: "active"
        when: popout.shouldBeActive

        PropertyChanges {
            popout.active: true
            popout.opacity: 1
        }
    }

    transitions: [
        Transition {
            from: "active"
            to: ""

            SequentialAnimation {
                NumberAnimation { property: "opacity"; duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic }
                PropertyAction { property: "active" }
            }
        },
        Transition {
            from: ""
            to: "active"

            SequentialAnimation {
                PropertyAction { property: "active" }
                NumberAnimation { property: "opacity"; duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic }
            }
        }
    ]
}
