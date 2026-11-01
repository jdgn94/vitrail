import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "emoji.js" as Emoji

// The emoji tab: a search, the nine Unicode groups as icons, and a grid of
// what matches. A click copies the emoji and leaves the tab open, so several
// can be picked in a row.
Item {
    id: root

    property var strings: ({})
    property var emojis: []
    property bool active: false
    property string query: ""
    property string group: "all"

    signal picked(string emoji)
    signal closeRequested()

    readonly property var shown: Emoji.filter(root.emojis, root.query, root.group)

    implicitHeight: content.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    onActiveChanged: {
        if (!root.active)
            return
        root.query = ""
        root.group = "all"
        search.text = ""
        search.forceActiveFocus()
    }

    ColumnLayout {
        id: content

        width: parent.width
        spacing: VitrailTokens.gap("sm")

        VitrailSegmented {
            Layout.fillWidth: true
            current: root.group
            options: [
                { key: "all", label: "", icon: "apps" },
                { key: "Smileys & Emotion", label: "", icon: "sentiment_satisfied" },
                { key: "People & Body", label: "", icon: "person" },
                { key: "Animals & Nature", label: "", icon: "pets" },
                { key: "Food & Drink", label: "", icon: "restaurant" },
                { key: "Travel & Places", label: "", icon: "flight" },
                { key: "Activities", label: "", icon: "sports_soccer" },
                { key: "Objects", label: "", icon: "lightbulb" },
                { key: "Symbols", label: "", icon: "emoji_symbols" },
                { key: "Flags", label: "", icon: "flag" }
            ]
            onSelected: function (key) { root.group = key }
        }

        VitrailField {
            id: search

            Layout.fillWidth: true
            size: "sm"
            leadingIcon: "search"
            placeholder: root.t("clipboard.emoji.search")
            onTextChanged: root.query = text
            onEscaped: root.closeRequested()
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.shown.length === 0
            variant: "content"
            horizontalAlignment: Text.AlignHCenter
            text: root.t("clipboard.emoji.none")
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 300)
            visible: root.shown.length > 0
            clip: true
            cellWidth: 44
            cellHeight: 44
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown

            delegate: Item {
                id: cell

                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: VitrailTokens.radius * 0.4
                    color: Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                                   VitrailTokens.color("primary").b, cellHover.hovered ? 0.18 : 0)
                }

                HoverHandler {
                    id: cellHover
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.e
                    font.pixelSize: VitrailTokens.size("title")
                    font.family: "Noto Color Emoji"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(cell.modelData.e)
                }
            }
        }
    }
}
