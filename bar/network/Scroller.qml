import QtQuick
import QtQuick.Layouts
import "../kit"

// A list that scrolls past a handful of rows, so the popup stays small.
Flickable {
    id: root

    default property alias rows: column.data

    // How many rows stay visible before the list scrolls.
    property int visibleRows: 8

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(column.implicitHeight, VitrailTokens.size("display") * root.visibleRows)
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Column {
        id: column

        width: parent.width
        spacing: VitrailTokens.gap("xs")
    }
}
