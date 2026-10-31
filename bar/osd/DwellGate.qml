import QtQuick

// Becomes `ready` once `hovered` has stayed true for `interval` ms without a
// break. Leaving cancels the count and resets `ready`; entering again starts
// it over.
QtObject {
    id: root

    property bool hovered: false
    property int interval: 0
    property bool ready: false

    onHoveredChanged: root.ready = false

    property Timer timer: Timer {
        interval: root.interval
        running: root.hovered
        onTriggered: root.ready = true
    }
}
