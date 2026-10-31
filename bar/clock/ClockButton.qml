import QtQuick
import Quickshell
import "../kit"
import "../kit/base"

// The time in the centre of the bar: hours over minutes on a vertical bar,
// one line on a horizontal one. A click opens the clock popup.
Item {
    id: root

    property bool vertical: false
    property bool opened: false
    property string language: "en"

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    // What the pointer reads: today's full date.
    property string tooltip: {
        var day = clock.date.toLocaleDateString(Qt.locale(root.language), "dddd d MMMM yyyy")
        return day.charAt(0).toUpperCase() + day.slice(1)
    }

    implicitWidth: label.implicitWidth + 2 * VitrailTokens.gap("sm")
    implicitHeight: label.implicitHeight + 2 * VitrailTokens.gap("xs")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: VitrailTokens.color("primary")
        opacity: root.opened ? 0.16 : (root.hovered ? 0.08 : 0)

        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    VitrailText {
        id: label

        anchors.centerIn: parent
        variant: "body"
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.9
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        color: root.opened ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
        text: {
            var hours = String(clock.hours).padStart(2, "0")
            var minutes = String(clock.minutes).padStart(2, "0")
            return root.vertical ? hours + "\n" + minutes : hours + ":" + minutes
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
