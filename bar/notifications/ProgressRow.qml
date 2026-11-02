import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "progress.js" as Progress

// The bar of a live task inside a notification card (vitrail/downloads.py and,
// later, any job): determinate when the daemon knows the total, a sliding bar
// when it does not — never a made-up percentage — and the X at the end that
// cancels it. A finished task shows its buttons in the card's action row, so
// this row disappears.
Item {
    id: root

    property var notification: null
    readonly property string state: Progress.state(root.notification)
    readonly property int percent: Progress.percent(root.notification)
    readonly property bool running: Progress.live(root.notification)
    readonly property bool indeterminate: root.running && root.percent < 0
    readonly property var cancel: Progress.actionOf(root.notification ? root.notification.actions : [], "cancel")

    visible: root.running
    implicitHeight: visible ? row.implicitHeight : 0

    RowLayout {
        id: row

        width: parent.width
        spacing: VitrailTokens.gap("xs")

        VitrailText {
            visible: root.percent >= 0
            variant: "label"
            text: root.percent + "%"
        }

        Item {
            id: track

            Layout.fillWidth: true
            implicitHeight: VitrailTokens.gap("xs") + 2

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                               VitrailTokens.color("foreground").b, 0.15)
            }

            Rectangle {
                id: fill

                height: parent.height
                radius: height / 2
                width: root.percent >= 0 ? parent.width * root.percent / 100 : parent.width * 0.25
                color: VitrailTokens.color("primary")
            }

            // Known total: the fill grows from the left. Unknown: a short bar
            // slides back and forth, which is the honest "don't know how long".
            Binding {
                target: fill
                property: "x"
                value: 0
                when: !root.indeterminate
                restoreMode: Binding.RestoreNone
            }

            SequentialAnimation {
                running: root.indeterminate
                loops: Animation.Infinite

                NumberAnimation {
                    target: fill
                    property: "x"
                    from: 0
                    to: Math.max(0, track.width - fill.width)
                    duration: 900
                    easing.type: Easing.InOutCubic
                }

                NumberAnimation {
                    target: fill
                    property: "x"
                    from: Math.max(0, track.width - fill.width)
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutCubic
                }
            }
        }

        VitrailButton {
            visible: root.cancel !== null
            variant: "plain"
            tone: "secondary"
            size: "sm"
            icon: "close"
            onClicked: if (root.cancel) root.cancel.invoke()
        }
    }
}
