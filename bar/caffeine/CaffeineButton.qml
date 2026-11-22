import QtQuick
import ".."
import "../kit"
import "../kit/base"
import "caffeine.js" as Caffeine

// The caffeine element: a cup that fills while the screen is kept awake. A
// left or middle click turns it on (for the remembered duration) or off; a
// right click opens the popup. Quickshell's IdleInhibitor does the work, in
// bar/shell.qml, so this button only reports the state.
BarElementBase {
    id: root

    property bool caffeineOn: false
    property double until: 0
    property bool inhibiting: false
    property double now: Date.now()

    readonly property var state: Caffeine.state(root.caffeineOn, root.until, root.now)

    signal toggleRequested()
    signal menuRequested()

    showMode: "always"
    active: root.state.on && root.inhibiting
    tooltip: Caffeine.summary(root.caffeineOn, root.until, root.now, root.t)
    tooltipDetail: Caffeine.detail(root.inhibiting, root.t)

    content: Component {
        Item {
            implicitWidth: VitrailTokens.size("title")
            implicitHeight: VitrailTokens.size("title")

            VitrailIcon {
                objectName: "cup"

                anchors.centerIn: parent
                icon: "coffee"
                size: "sm"
                container: root.state.on
                tone: root.state.on ? "primary" : "secondary"
            }
        }
    }

    onClicked: root.toggleRequested()
    onMiddleClicked: root.toggleRequested()
    onRightClicked: root.menuRequested()
}
