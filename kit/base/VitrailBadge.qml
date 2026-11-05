import QtQuick
import ".."

// A small count over an icon: the biggest number the pill may show, then
// "9+". `text` comes from the caller (bar/notifications/tooltip.js decides the
// cap); empty hides it, so a zero-count element needs no extra condition.
Item {
    id: root

    property string text: ""
    // A family from VitrailVariants.tone; the fill carries the ink.
    property string tone: "error"
    readonly property var family: VitrailVariants.tone[root.tone] || VitrailVariants.tone.error
    readonly property color fill: VitrailTokens.color(root.family.role, "#ba1a1a")
    readonly property color ink: VitrailTokens.color(root.family.on, "#ffffff")

    visible: root.text !== ""
    implicitHeight: label.implicitHeight + 2 * VitrailTokens.gap("xs")
    implicitWidth: Math.max(root.implicitHeight,
                            label.implicitWidth + 2 * VitrailTokens.gap("sm"))

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.fill
    }

    VitrailText {
        id: label

        anchors.centerIn: parent
        variant: "label"
        font.weight: Font.DemiBold
        color: root.ink
        opacity: 1
        text: root.text
    }
}
