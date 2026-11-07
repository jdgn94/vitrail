import QtQuick
import "../kit"
import "../kit/base"

// The active window's title in the centre of the bar: one line, elided when it
// does not fit, with the full title and the app class in the tooltip. It leaves
// the bar when there is no title, a fullscreen window owns the screen, or the
// layout hides it.
Item {
    id: root

    property string title: ""
    property string appClass: ""
    property var strings: ({})
    property bool fullscreen: false
    // The layout's visibility switch (`entryVisible`).
    property bool layoutVisible: true
    // A vertical bar turns the line to read along its edge.
    property bool vertical: false
    property real maxWidth: 320

    // What the pointer reads: the whole title, then the app it belongs to.
    property string tooltip: root.title !== "" ? root.title : root.t("bar.widget.title.tooltip")
    property string tooltipDetail: root.appClass !== "" ? root.appClass : root.t("bar.widget.title.help")

    readonly property bool shown: root.layoutVisible && !root.fullscreen && root.title !== ""
    readonly property alias hovered: hover.hovered
    readonly property alias truncated: label.truncated
    readonly property alias naturalWidth: label.implicitWidth
    readonly property alias textWidth: label.width

    visible: root.shown
    implicitWidth: root.shown ? (root.vertical ? label.implicitHeight : root.textWidth) : 0
    implicitHeight: root.shown ? (root.vertical ? root.textWidth : label.implicitHeight) : 0

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The line keeps its own horizontal box; a vertical bar rotates that box
    // about its centre, so the elision and the text metrics stay the same.
    Item {
        id: art

        anchors.centerIn: parent
        width: root.textWidth
        height: label.implicitHeight
        rotation: root.vertical ? -90 : 0

        VitrailText {
            id: label

            objectName: "titleLabel"
            anchors.centerIn: parent
            width: Math.min(label.implicitWidth, root.maxWidth)
            elide: Text.ElideRight
            maximumLineCount: 1
            text: root.title
            variant: "body"
            font.weight: Font.Medium
            color: VitrailTokens.color("foreground", "#e3e3e3")
        }
    }

    HoverHandler {
        id: hover
    }
}
