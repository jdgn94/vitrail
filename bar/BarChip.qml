import QtQuick
import QtQuick.Layouts
import "kit"

// A chip: several bar elements sharing one pill. The layout document places
// the chip (`@connections`, or one the user made) and lists its members; the
// bar hands each member's own component in, so every button keeps its popup,
// its tooltip and its visibility rule. The pill takes no input of its own.
Item {
    id: root

    // The members to draw, in the document's order.
    property var ids: []
    property bool vertical: false
    // The component of one member id; the bar answers with its own widget
    // components (bar/shell.qml).
    property var componentFor: function (id) { return null }

    signal loaded(string id, var item)
    signal unloaded(string id)

    implicitWidth: row.implicitWidth
    // The 2 px halo the old connection chip had, so the pill's radius clears
    // the glyphs instead of clipping them.
    implicitHeight: row.implicitHeight + 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        // A soft primary: opaque, so it does not smear over the glass.
        color: VitrailTokens.solid("primary", 0.14)
    }

    GridLayout {
        id: row

        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: root.ids

            delegate: BarEntry {
                required property string modelData

                vertical: root.vertical
                sourceComponent: root.componentFor(modelData)
                onLoaded: root.loaded(modelData, item)
                Component.onDestruction: root.unloaded(modelData)
            }
        }
    }
}
