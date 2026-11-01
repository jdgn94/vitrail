import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "clipboard.js" as Clipboard
import "colors.js" as Colors

// The history tab: the kind filters, the search, the entries and the hint.
Item {
    id: root

    property var strings: ({})
    property var entries: []
    property var thumbs: ({})
    property bool active: false
    property int max: 100
    property string kindFilter: "all"
    property int selected: 0
    property string query: ""
    // Emptying the history takes two clicks: the first one only arms it.
    property bool confirmingClear: false

    signal picked(string id, string mode)
    signal removeRequested(string id)
    signal clearRequested()
    signal thumbRequested(string id)
    signal closeRequested()

    readonly property var unique: Clipboard.unique(root.entries)
    readonly property var shown: Clipboard.filter(root.unique, root.query, root.kindFilter)
    readonly property int thumbSize: VitrailTokens.size("display") + VitrailTokens.gap("md")

    implicitHeight: content.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    onShownChanged: if (root.selected >= root.shown.length)
        root.selected = Math.max(0, root.shown.length - 1)

    onActiveChanged: {
        if (!root.active)
            return
        root.query = ""
        root.kindFilter = "all"
        root.selected = 0
        root.confirmingClear = false
        search.text = ""
        search.forceActiveFocus()
    }

    function move(delta) {
        if (root.shown.length === 0)
            return
        root.selected = (root.selected + delta + root.shown.length) % root.shown.length
    }

    function pick(mode) {
        if (root.shown.length === 0)
            return
        var entry = root.shown[Math.min(root.selected, root.shown.length - 1)]
        if (entry)
            root.picked(entry.id, mode)
    }

    Timer {
        id: confirmTimer

        interval: 3000
        onTriggered: root.confirmingClear = false
    }

    ColumnLayout {
        id: content

        width: parent.width
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailSegmented {
                Layout.fillWidth: true
                current: root.kindFilter
                options: [
                    { key: "all", label: root.t("clipboard.filter.all") },
                    { key: "text", label: root.t("clipboard.filter.text") },
                    { key: "image", label: root.t("clipboard.filter.image") },
                    { key: "link", label: root.t("clipboard.filter.link") }
                ]
                onSelected: function (key) { root.kindFilter = key }
            }

            VitrailText {
                variant: "label"
                opacity: 0.7
                text: root.unique.length + " / " + root.max
            }

            VitrailButton {
                variant: "plain"
                tone: root.confirmingClear ? "error" : "secondary"
                size: "sm"
                icon: root.confirmingClear ? "warning" : "delete_sweep"
                enabled: root.unique.length > 0
                onClicked: {
                    if (!root.confirmingClear) {
                        root.confirmingClear = true
                        confirmTimer.restart()
                        return
                    }
                    root.confirmingClear = false
                    root.clearRequested()
                }
            }
        }

        VitrailField {
            id: search

            Layout.fillWidth: true
            size: "sm"
            leadingIcon: "search"
            placeholder: root.t("clipboard.search")
            onTextChanged: root.query = text
            onAccepted: root.pick("default")
            onEscaped: root.closeRequested()
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Down) {
                    root.move(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.move(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    var mode = "default"
                    if (event.modifiers & Qt.ShiftModifier)
                        mode = "copy"
                    else if (event.modifiers & Qt.ControlModifier)
                        mode = "terminal"
                    root.pick(mode)
                    event.accepted = true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.shown.length === 0
            implicitHeight: emptyColumn.implicitHeight + 2 * VitrailTokens.gap("lg")
            radius: VitrailTokens.radius * 0.85
            color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                           VitrailTokens.color("foreground").b, 0.06)

            ColumnLayout {
                id: emptyColumn

                anchors.centerIn: parent
                width: parent.width - 2 * VitrailTokens.gap("lg")
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "content_paste_off"
                    size: "xl"
                    tone: "secondary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.query === "" && root.kindFilter === "all"
                          ? root.t("clipboard.empty") : root.t("clipboard.noMatch")
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: root.shown.length > 0
            clip: true
            interactive: contentHeight > 380
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            model: root.shown

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                readonly property var image: Clipboard.imageOf(row.modelData.preview)
                readonly property string thumb: root.thumbs[row.modelData.id] || ""

                width: ListView.view.width
                height: line.implicitHeight + 2 * VitrailTokens.gap("xs")
                radius: VitrailTokens.radius * 0.5
                color: row.index === root.selected
                       ? Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                                 VitrailTokens.color("primary").b, 0.16)
                       : (rowHover.hovered ? Qt.rgba(VitrailTokens.color("foreground").r,
                                                     VitrailTokens.color("foreground").g,
                                                     VitrailTokens.color("foreground").b, 0.06)
                                           : "transparent")

                HoverHandler {
                    id: rowHover
                }

                RowLayout {
                    id: line

                    x: VitrailTokens.gap("xs")
                    y: VitrailTokens.gap("xs")
                    width: parent.width - 2 * VitrailTokens.gap("xs")
                    spacing: VitrailTokens.gap("sm")

                    Rectangle {
                        implicitWidth: root.thumbSize
                        implicitHeight: root.thumbSize
                        radius: VitrailTokens.radius * 0.4
                        color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                       VitrailTokens.color("foreground").b, 0.08)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: row.thumb !== ""
                            source: row.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // A colour entry shows its own swatch.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: parent.radius
                            visible: row.thumb === "" && Colors.isColor(row.modelData.preview)
                            color: Colors.isColor(row.modelData.preview)
                                   ? Colors.format(Colors.parse(row.modelData.preview), "hex") : "transparent"
                        }

                        VitrailIcon {
                            anchors.centerIn: parent
                            visible: row.thumb === "" && !Colors.isColor(row.modelData.preview)
                            icon: row.image ? "image" : "content_paste"
                            size: "sm"
                            tone: "secondary"
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "content"
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        text: Clipboard.label(row.modelData)
                    }

                    VitrailButton {
                        variant: "plain"
                        tone: "secondary"
                        size: "sm"
                        icon: "close"
                        onClicked: root.removeRequested(row.modelData.id)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selected = row.index
                        root.pick("default")
                    }
                }

                Component.onCompleted: if (row.image && row.thumb === "")
                    root.thumbRequested(row.modelData.id)
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.shown.length > 0
            variant: "label"
            opacity: 0.7
            elide: Text.ElideRight
            text: root.t("clipboard.hint")
        }
    }
}
