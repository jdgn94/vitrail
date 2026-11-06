import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "icons.js" as Icons

// One app of the device card: its icon (clicking focuses its window), its
// mute button, and its own volume. The percentage is the stream's volume, not
// the effective one: PipeWire multiplies it by the general volume.
Item {
    id: root

    // { key, name, icon, binary, nodes } from OsdController.
    property var group: ({})
    // Percent one wheel notch moves.
    property real step: VitrailTokens.osd.step
    // The icon the controller resolved for this app ("" leaves a glyph).
    property string iconSource: ""
    property string tooltip: ""
    property string tooltipDetail: ""

    signal focusRequested()
    signal muteRequested()
    signal moved(real value)

    readonly property var nodes: root.group && root.group.nodes ? root.group.nodes : []
    // The mean of the app's streams, 0..100.
    readonly property real level: {
        var total = 0
        var count = 0
        for (var i = 0; i < root.nodes.length; i++) {
            var audio = root.nodes[i] ? root.nodes[i].audio : null
            if (audio) {
                total += audio.volume
                count += 1
            }
        }
        return count > 0 ? total / count * 100 : 0
    }
    // Only when every stream of the app is silent.
    readonly property bool muted: {
        var count = 0
        for (var i = 0; i < root.nodes.length; i++) {
            var audio = root.nodes[i] ? root.nodes[i].audio : null
            if (!audio)
                continue
            if (!audio.muted)
                return false
            count += 1
        }
        return count > 0
    }

    implicitWidth: line.implicitWidth
    implicitHeight: VitrailTokens.size("display")
    activeFocusOnTab: true

    Keys.onReturnPressed: root.focusRequested()
    Keys.onSpacePressed: root.focusRequested()

    RowLayout {
        id: line

        anchors.fill: parent
        spacing: VitrailTokens.gap("xs")

        // The app: click focuses its window.
        Item {
            Layout.preferredWidth: VitrailTokens.size("display")
            Layout.preferredHeight: VitrailTokens.size("display")

            Image {
                id: art

                anchors.fill: parent
                anchors.margins: VitrailTokens.gap("xs")
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(width, height)
                source: root.iconSource
                visible: status === Image.Ready
            }

            VitrailIcon {
                anchors.centerIn: parent
                visible: !art.visible
                icon: "apps"
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.focusRequested()
            }
        }

        // The app's mute: the same glyph the panel uses.
        VitrailButton {
            Layout.preferredWidth: VitrailTokens.size("display")
            Layout.preferredHeight: VitrailTokens.size("display")
            icon: Icons.volume(root.level / 100, root.muted)
            variant: "plain"
            tone: root.muted ? "error" : "secondary"
            size: "sm"
            onClicked: root.muteRequested()
        }

        VitrailSlider {
            objectName: "slider"

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            size: "sm"
            from: 0
            to: 100
            stepSize: 1
            wheelStep: root.step
            value: root.level
            accent: root.muted ? VitrailTokens.color("muted") : VitrailTokens.color("primary")
            onMoved: function (value) { root.moved(value) }
        }

        VitrailText {
            objectName: "percent"

            Layout.preferredWidth: Math.round(VitrailTokens.size("label") * 3.2)
            horizontalAlignment: Text.AlignRight
            variant: "label"
            text: Math.round(root.level) + "%"
        }
    }

    // Where the keyboard is.
    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: VitrailTokens.color("primary")
        visible: root.activeFocus
    }
}
