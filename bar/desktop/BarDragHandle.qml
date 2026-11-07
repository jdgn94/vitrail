import QtQuick
import "../kit"
import "../kit/base"

// The grip that starts an editing drag in the Bar tab. Every row uses the same
// one: the tab receives the scene point while the pointer moves and decides
// where the row may land, so the grip itself knows nothing about layouts.
Item {
    id: root

    signal started()
    signal moved(real sceneX, real sceneY)
    signal finished()

    implicitWidth: VitrailTokens.gap("lg")
    implicitHeight: VitrailTokens.gap("lg")

    HoverHandler {
        cursorShape: grab.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    VitrailIcon {
        anchors.centerIn: parent
        icon: "drag_indicator"
        size: "sm"
        tone: "muted"
    }

    DragHandler {
        id: grab

        target: null
        enabled: root.enabled
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        onActiveChanged: {
            if (grab.active) {
                root.started()
                var point = grab.centroid.scenePosition
                root.moved(point.x, point.y)
            } else {
                root.finished()
            }
        }

        onTranslationChanged: {
            if (!grab.active)
                return
            var point = grab.centroid.scenePosition
            root.moved(point.x, point.y)
        }
    }
}
