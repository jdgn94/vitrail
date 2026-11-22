import QtQuick
import ".."

// A thin horizontal meter: a quiet track and a fill up to `value` (0 to 1).
// A negative value is "no reading": the track stays and nothing fills it, so a
// missing sensor never looks like zero.
Item {
    id: root

    property real value: -1
    // A family from VitrailVariants.tone; the fill takes its role.
    property string tone: "primary"
    readonly property var family: VitrailVariants.tone[root.tone] || VitrailVariants.tone.primary
    readonly property real share: root.value < 0 ? 0 : Math.min(root.value, 1)

    implicitWidth: VitrailTokens.size("display")
    implicitHeight: VitrailTokens.gap("sm")

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(VitrailTokens.color("foreground", "transparent"), VitrailTokens.graph.track)
    }

    Rectangle {
        objectName: "fill"

        visible: root.value >= 0
        width: parent.width * root.share
        height: parent.height
        radius: height / 2
        color: VitrailTokens.color(root.family.role, "transparent")

        Behavior on width {
            NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
        }
    }
}
