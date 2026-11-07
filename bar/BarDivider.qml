import QtQuick
import "kit"

// A divider: a 1 px hairline between two bar elements, drawn with the muted
// token. It takes no input, carries no tooltip and has no content of its own.
Item {
    id: root

    property bool vertical: false

    implicitWidth: root.vertical ? VitrailTokens.gap("lg") : root.line
    implicitHeight: root.vertical ? root.line : VitrailTokens.gap("lg")

    readonly property int line: 1
    // The colour sits on a palette role, never on a literal.
    readonly property color tone: VitrailTokens.color("muted", "#c4c6d0")

    Rectangle {
        objectName: "barDividerLine"

        anchors.centerIn: parent
        width: root.vertical ? parent.width : root.line
        height: root.vertical ? root.line : parent.height
        color: root.tone
    }
}
