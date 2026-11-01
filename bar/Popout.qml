import QtQuick
import "kit"

// One bar popout. It loads while it is the current one; leaving, it fades
// out before unloading. Arriving, it loads at once (the card needs its size)
// but stays invisible for `handover`, then fades in: the previous popout is
// gone before the next shows, so two never overlap on the gliding card.
Loader {
    id: popout

    required property string name
    property string current: ""
    // How long an arriving popout waits before it fades in (the time the
    // previous one needs to fade out).
    property int handover: 0

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
                PauseAnimation { duration: popout.handover }
                NumberAnimation { property: "opacity"; duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic }
            }
        }
    ]
}
