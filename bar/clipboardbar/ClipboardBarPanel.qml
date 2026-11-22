import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../clipboard"
import "../clipboard/clipboard.js" as Clipboard
import "clipboardbar.js" as ClipboardBar

// The clipboard element's popup: the newest copies, each with the same rich
// preview the history shows on hover (an image, a path or the source's styled
// text), and one button that opens the full history. The data is the shell's
// own history list; the gear opens the element's block in Settings.
Item {
    id: root

    property var strings: ({})
    // The history, newest first, as the clipboard panel reads it.
    property var entries: []
    // The rich previews and image files the shell has already loaded, by id.
    property var previews: ({})
    property var thumbs: ({})
    // How many copies to show (`clipboardbarRecent`, 1–10).
    property int limit: ClipboardBar.DEFAULT

    signal settingsRequested()
    // A copy was clicked: the shell copies it exactly as the history does.
    signal copyRequested(string id)
    signal historyRequested()
    // The popup asks the shell to re-read the history and to load one entry's
    // rich preview (a text) or image.
    signal refreshRequested()
    signal previewRequested(string id)
    signal thumbRequested(string id)

    readonly property var rows: ClipboardBar.recent(root.entries, root.limit)
    readonly property int count: ClipboardBar.count(root.entries)

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // Load what the rows need, once each: an image's PNG or a text's HTML.
    function loadPreviews() {
        for (var i = 0; i < root.rows.length; i++) {
            var entry = root.rows[i]
            if (Clipboard.imageOf(entry.preview))
                root.thumbRequested(entry.id)
            else if (!root.previews[entry.id])
                root.previewRequested(entry.id)
        }
    }

    function refresh() {
        root.refreshRequested()
    }

    onRowsChanged: root.loadPreviews()
    Component.onCompleted: {
        root.loadPreviews()
        root.refresh()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.clipboardbar")
            }

            VitrailText {
                variant: "label"
                opacity: 0.7
                text: String(root.count)
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "empty"

            Layout.fillWidth: true
            visible: root.rows.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.clipboardbar.empty")
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: rowsColumn.implicitHeight

            Column {
                id: rowsColumn

                width: parent.width
                spacing: VitrailTokens.gap("xs")

                Repeater {
                    model: root.rows

                    delegate: Item {
                        id: row

                        required property var modelData

                        readonly property var image: Clipboard.imageOf(row.modelData.preview)
                        readonly property var previewData: row.image
                            ? ({ kind: "image" })
                            : (root.previews[row.modelData.id]
                               || ({ kind: "text", text: row.modelData.preview }))

                        objectName: "clipboardRow"

                        width: parent.width
                        height: Math.max(preview.implicitHeight, VitrailTokens.size("body"))

                        Rectangle {
                            anchors.fill: parent
                            radius: VitrailTokens.radius * 0.75
                            color: hover.hovered
                                   ? Qt.rgba(VitrailTokens.color("foreground").r,
                                             VitrailTokens.color("foreground").g,
                                             VitrailTokens.color("foreground").b, 0.06)
                                   : "transparent"
                        }

                        ClipboardPreview {
                            id: preview

                            objectName: "clipboardPreview"

                            width: row.width
                            compact: true
                            shown: true
                            preview: row.previewData
                            image: row.image ? (root.thumbs[row.modelData.id] || "") : ""
                        }

                        HoverHandler {
                            id: hover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.copyRequested(row.modelData.id)
                        }
                    }
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.rows.length > 0
            variant: "label"
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: root.t("bar.clipboardbar.hint")
        }

        VitrailButton {
            objectName: "openHistory"

            Layout.fillWidth: true
            variant: "tonal"
            tone: "primary"
            icon: "history"
            text: root.t("bar.clipboardbar.open")
            onClicked: root.historyRequested()
        }
    }
}
