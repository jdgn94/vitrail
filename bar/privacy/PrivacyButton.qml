import QtQuick
import ".."
import "../kit"
import "../kit/base"
import "privacy.js" as Privacy

// The privacy bar element: one small dot while a watched microphone, camera or
// screen capture is in use, from vitrail.privacy's snapshot (BarSnapshot). It is
// an indicator, so "only while active" is its default mode: the bar grows a dot
// only while something is capturing and has nothing there otherwise. "Always"
// keeps a shield glyph in place for anyone who wants the slot steady. A use is
// never hidden because its app has no name or icon.
BarElementBase {
    id: root

    // The element's data: vitrail.privacy's snapshot.
    property var snapshot: ({})
    // The `privacyWatch` preference (one JSON array of kinds).
    property string watch: ""
    // The `privacyDotColor` preference: a palette role.
    property string dotColor: ""

    readonly property var uses: Privacy.uses(root.snapshot, root.watch)
    readonly property bool inUse: Privacy.active(root.uses)
    readonly property string dotToken: Privacy.dotToken(root.dotColor)

    showMode: "active"
    active: root.inUse
    tooltip: root.inUse || Privacy.ready(root.snapshot) ? Privacy.title(root.uses, root.t) : root.t("bar.widget.privacy")
    tooltipDetail: root.inUse || Privacy.ready(root.snapshot) ? Privacy.detail(root.uses, root.t)
                                                              : root.t("bar.privacy.unavailable")

    content: Component {
        Item {
            implicitWidth: VitrailTokens.size("title")
            implicitHeight: VitrailTokens.size("title")

            Rectangle {
                objectName: "dot"

                anchors.centerIn: parent
                visible: root.inUse
                width: VitrailTokens.gap("md")
                height: width
                radius: width / 2
                color: VitrailTokens.color(root.dotToken, VitrailTokens.color("foreground"))
            }

            VitrailIcon {
                objectName: "idleIcon"

                anchors.centerIn: parent
                visible: !root.inUse
                icon: "shield_lock"
                size: "sm"
                container: false
                tone: "muted"
            }
        }
    }
}
