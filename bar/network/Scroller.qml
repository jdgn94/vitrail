import QtQuick
import QtQuick.Layouts
import "../kit"

// A list that scrolls past a handful of rows, so the popup stays small.
Flickable {
    default property alias rows: column.data

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(column.implicitHeight, VitrailTokens.size("display") * 8)
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Column {
        id: column

        width: parent.width
        spacing: VitrailTokens.gap("xs")
    }
}
