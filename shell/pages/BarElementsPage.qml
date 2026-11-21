import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Bar elements category: one block per new-style bar element, each with the
// options every element shares (when it shows) and its own. A bar popup's gear
// lands on its element's block through `tab` (the element's id). A new
// element adds its BarElementSection here (docs/bar-elements.md).
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The element whose block to bring into view (a gear or a search result).
    property string tab: ""

    function reveal() {
        for (var i = 0; i < column.children.length; i++) {
            var block = column.children[i]
            if (block.elementId !== undefined && block.elementId === page.tab) {
                scroller.contentY = Math.min(block.y, Math.max(0, scroller.contentHeight - scroller.height))
                return
            }
        }
    }

    onTabChanged: Qt.callLater(page.reveal)

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            BarElementSection {
                Layout.fillWidth: true
                elementId: "sample"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings
            }

            Item { Layout.preferredHeight: VitrailTokens.gap("xl") }
        }
    }
}
