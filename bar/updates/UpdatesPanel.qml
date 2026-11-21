import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "updates.js" as Updates

// The updates element's popup: one block per enabled source with its count and
// its rows (`name  from → to`), the failures as a calm line each, a refresh,
// and a per-source Update button that runs the snapshot's own argv in a kitty
// terminal. The rows a source cannot fit become "and N more". The gear opens
// the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})

    signal settingsRequested()
    // The argv of one source's "Update" action (`snapshot.commands`); the
    // shell quotes it and opens it in the terminal.
    signal updateRequested(var argv)
    signal refreshRequested()

    readonly property bool ready: Updates.ready(root.snapshot)
    readonly property var sourceList: Updates.sourcesOf(root.snapshot)
    // The blocks fit about eight text lines before the list starts to scroll.
    readonly property real listMax: VitrailTokens.size("display") * 8

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function commandOf(source) {
        var commands = (root.snapshot || ({})).commands || ({})
        return Array.isArray(commands[source]) ? commands[source] : []
    }

    implicitWidth: 380
    implicitHeight: body.implicitHeight

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
                text: root.t("bar.widget.updates")
            }

            VitrailButton {
                objectName: "refresh"

                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "refresh"
                onClicked: root.refreshRequested()
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.updates.unreadable")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(blocks.implicitHeight, root.listMax)
            visible: root.ready && root.sourceList.length > 0
            contentWidth: width
            contentHeight: blocks.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: blocks

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.sourceList

                    delegate: ColumnLayout {
                        id: block

                        required property string modelData

                        readonly property var rows: Updates.entries(root.snapshot, block.modelData)
                        readonly property string failure: Updates.errorOf(root.snapshot, block.modelData)
                        readonly property int hiddenRows: Updates.hidden(block.rows)

                        objectName: "sourceBlock"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "label"
                                elide: Text.ElideRight
                                text: root.t("bar.updates.source." + block.modelData)
                            }

                            VitrailText {
                                variant: "label"
                                text: block.rows.length
                            }
                        }

                        Repeater {
                            model: Updates.shown(block.rows)

                            delegate: RowLayout {
                                required property var modelData

                                objectName: "updateRow"

                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("sm")

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "body"
                                    elide: Text.ElideRight
                                    text: modelData.name || ""
                                }

                                VitrailText {
                                    variant: "label"
                                    text: Updates.versions(modelData)
                                }
                            }
                        }

                        VitrailText {
                            objectName: "more"

                            Layout.fillWidth: true
                            visible: block.hiddenRows > 0
                            variant: "label"
                            text: root.t("bar.updates.more").replace("%1", block.hiddenRows)
                        }

                        VitrailText {
                            objectName: "sourceError"

                            Layout.fillWidth: true
                            visible: block.failure !== ""
                            variant: "label"
                            wrapMode: Text.WordWrap
                            text: block.failure
                        }

                        VitrailButton {
                            objectName: "update"

                            Layout.alignment: Qt.AlignRight
                            visible: block.rows.length > 0 && root.commandOf(block.modelData).length > 0
                            variant: "tonal"
                            tone: "secondary"
                            size: "sm"
                            icon: "update"
                            text: root.t("bar.updates.update")
                            onClicked: root.updateRequested(root.commandOf(block.modelData))
                        }
                    }
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.ready && root.snapshot.checkedAt !== undefined
            variant: "label"
            text: root.t("bar.updates.checked").replace("%1",
                Qt.formatTime(new Date(root.snapshot.checkedAt), "HH:mm"))
        }
    }
}
