import QtQuick
import QtQuick.Layouts

// One bar element, loaded once and sized by what it shows. An element that
// hides itself (it exposes `shown`), has nothing to draw or is switched off
// leaves the bar's grid: no size and no spacing around it.
Loader {
    id: root

    // The bar's direction: the size that matters is the one along the flow.
    property bool vertical: false
    // The shell's own switch for an element whose visibility is not in the
    // element (the media player, the recording, the keyboard).
    property bool contentVisible: true

    readonly property var content: root.item

    readonly property bool shown: root.content !== null && root.contentVisible
                                  && (root.content.shown === undefined || root.content.shown)
                                  && (root.vertical ? root.content.implicitHeight > 0
                                                    : root.content.implicitWidth > 0)
    visible: root.shown
    Layout.preferredWidth: root.shown ? root.content.implicitWidth : 0
    Layout.preferredHeight: root.shown ? root.content.implicitHeight : 0
}
