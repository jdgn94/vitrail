import QtQuick
import ".."
import "../kit"
import "../kit/base"
import "downloads.js" as Downloads

// The downloads bar element: a download glyph over a thin progress bar, from
// vitrail.downloads' one-shot snapshot (BarSnapshot). The bar is determinate
// only when every running download knows its total; one unknown download
// leaves it indeterminate, because a sum over a guess would be a guess. The
// text is the aggregate percentage when there is one, "" otherwise.
//
// "Only while active" is the element's default mode (bar/elements.js): with
// nothing downloading the element has nothing to report, so it leaves the bar
// instead of holding an empty slot; "always" keeps the glyph in place with an
// empty track for anyone who wants the slot steady.
BarElementBase {
    id: root

    // The element's data: vitrail.downloads' snapshot.
    property var snapshot: ({})

    readonly property bool ready: Downloads.ready(root.snapshot)
    readonly property var running: Downloads.active(root.snapshot)
    readonly property int percent: Downloads.aggregate(root.snapshot)
    readonly property real speed: Downloads.totalSpeed(root.running)
    readonly property bool indeterminate: root.running.length > 0 && root.percent < 0

    showMode: "active"
    active: root.ready && root.running.length > 0
    text: root.percent >= 0 ? root.percent + "%" : ""
    tooltip: Downloads.title(root.snapshot, root.t)
    tooltipDetail: Downloads.detail(root.snapshot)

    content: Component {
        Item {
            implicitWidth: VitrailTokens.size("title")
            implicitHeight: VitrailTokens.size("title")

            VitrailIcon {
                objectName: "glyph"

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                icon: "download"
                size: "sm"
                container: false
                tone: root.active ? "primary" : "secondary"
            }

            Rectangle {
                id: track

                objectName: "track"

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: VitrailTokens.slider.thin
                radius: height / 2
                color: VitrailTokens.solid("foreground", 0.15)
            }

            Rectangle {
                id: fill

                objectName: "fill"

                y: track.y
                height: track.height
                radius: height / 2
                color: VitrailTokens.color("primary")
                visible: root.running.length > 0
                width: !root.active ? 0
                       : root.percent >= 0 ? track.width * root.percent / 100
                                           : track.width * 0.25
            }

            // Known total: the fill stands still at its width. Unknown: a short
            // bar slides back and forth, the honest "don't know how long".
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
                    duration: VitrailTokens.duration("slow")
                    easing.type: Easing.InOutCubic
                }

                NumberAnimation {
                    target: fill
                    property: "x"
                    from: Math.max(0, track.width - fill.width)
                    to: 0
                    duration: VitrailTokens.duration("slow")
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
}
