import QtQuick
import kit 1.0
import QtQuick.Layouts

// Example plugin: everything visual comes from the kit singletons.
Item {
    id: root
    implicitHeight: 64

    property var palette: VitrailTokens.palette

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        Text {
            text: Qt.formatTime(new Date(), "HH:mm:ss")
            color: VitrailTokens.color("foreground", "#e2e2e9")
            font.pixelSize: VitrailTokens.size("title")
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: parent.parent.parent.update()
            }
        }

        Text {
            text: "hello from a plugin"
            color: VitrailTokens.color("muted", "#c4c6d0")
            font.pixelSize: VitrailTokens.size("content")
        }
    }
}
