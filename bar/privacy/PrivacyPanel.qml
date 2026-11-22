import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "privacy.js" as Privacy

// The privacy element's popup: one block per kind in use (microphone, camera,
// screen) with a row for each application that has a matching stream open, and
// a Cut off button on the row. A kind with nothing in use draws no block. The
// popup says "in use" for a matched stream and nothing stronger: the snapshot
// does not know whether anything is recorded. Cut off asks the shell to destroy
// that one stream (the application keeps running and may reconnect). No
// PipeWire is a calm line. The gear opens the element's block in Settings →
// Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `privacyWatch` preference (one JSON array of kinds).
    property string watch: ""
    // A cut-off is running: every Cut off button waits for it.
    property bool busy: false

    signal settingsRequested()
    // One stream to cut off: its kind and PipeWire node id.
    signal cutRequested(string kind, int node)

    readonly property bool ready: Privacy.ready(root.snapshot)
    readonly property var uses: Privacy.uses(root.snapshot, root.watch)
    readonly property var kinds: Privacy.kindsIn(root.uses)
    // About four rows fit before the list scrolls.
    readonly property real listMax: VitrailTokens.size("display") * 8

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
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
                text: root.t("bar.widget.privacy")
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
            text: root.t("bar.privacy.unavailable")
        }

        VitrailText {
            objectName: "empty"

            Layout.fillWidth: true
            visible: root.ready && root.uses.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.privacy.idle.detail")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(blocks.implicitHeight, root.listMax)
            visible: root.uses.length > 0
            contentWidth: width
            contentHeight: blocks.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: blocks

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.kinds

                    delegate: ColumnLayout {
                        id: block

                        required property string modelData

                        readonly property var rows: Privacy.ofKind(root.uses, block.modelData)

                        objectName: "kind-" + block.modelData

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: Privacy.icon(block.modelData)
                                container: false
                                tone: "muted"
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: root.t("bar.privacy.kind." + block.modelData)
                            }

                            VitrailText {
                                variant: "label"
                                opacity: 0.7
                                text: root.t("bar.privacy.inUse")
                            }
                        }

                        Repeater {
                            model: block.rows

                            delegate: RowLayout {
                                id: row

                                required property var modelData

                                objectName: "use"

                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("sm")

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    VitrailText {
                                        objectName: "app"

                                        Layout.fillWidth: true
                                        variant: "label"
                                        elide: Text.ElideRight
                                        text: Privacy.appName(row.modelData)
                                    }

                                    VitrailText {
                                        objectName: "streamLabel"

                                        Layout.fillWidth: true
                                        visible: text !== "" && text !== Privacy.appName(row.modelData)
                                        variant: "label"
                                        opacity: 0.7
                                        elide: Text.ElideMiddle
                                        text: String(row.modelData.label || "")
                                    }
                                }

                                VitrailButton {
                                    objectName: "cut"

                                    variant: "tonal"
                                    tone: "error"
                                    size: "sm"
                                    icon: "close"
                                    text: root.t("bar.privacy.cut")
                                    enabled: !root.busy && Privacy.cuttable(row.modelData)
                                    onClicked: root.cutRequested(row.modelData.kind, row.modelData.node)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
