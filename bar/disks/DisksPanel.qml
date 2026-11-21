import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "disks.js" as Disks

// The disks element's popup: one card per connected removable drive, with its
// name, its space, how much of it is used, where it is mounted, and the four
// actions its state allows (Mount or Unmount, Eject only while unmounted, Open
// only while mounted). A forbidden action stays visible and disabled, with the
// reason underneath; a failed udisksctl action is a calm line with the text it
// returned, never a crash. The gear opens the element's block in Settings →
// Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `disksIgnore` preference: an ignored drive draws no card.
    property string ignore: ""
    // An action is running: every button waits for it.
    property bool busy: false
    // udisksctl's error text from the last failed action.
    property string error: ""

    signal settingsRequested()
    // One action of `python3 -m vitrail.disks`: mount/unmount/eject take the
    // device node, open takes its mount point.
    signal actionRequested(string action, string target)

    readonly property bool ready: Disks.ready(root.snapshot)
    readonly property var devices: Disks.visibleDevices(root.snapshot, root.ignore)
    // About four cards fit before the list starts to scroll.
    readonly property real listMax: VitrailTokens.size("display") * 8

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 400
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
                text: root.t("bar.widget.disks")
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
            text: root.t("bar.disks.unreadable")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(cards.implicitHeight, root.listMax)
            visible: root.ready && root.devices.length > 0
            contentWidth: width
            contentHeight: cards.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: cards

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.devices

                    delegate: ColumnLayout {
                        id: card

                        required property var modelData

                        readonly property var device: card.modelData

                        objectName: "drive"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: "storage"
                                color: VitrailTokens.color("muted")
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: Disks.nameOf(card.device)
                            }

                            VitrailText {
                                objectName: "usageText"

                                variant: "label"
                                text: Disks.space(card.device)
                            }
                        }

                        VitrailSlider {
                            objectName: "usage"

                            Layout.fillWidth: true
                            size: "thin"
                            continuous: true
                            readOnly: true
                            from: 0
                            to: Math.max(1, Number(card.device.size) || 0)
                            value: card.device.mounted && card.device.used !== null
                                   && card.device.used !== undefined ? Number(card.device.used) : 0
                        }

                        VitrailText {
                            objectName: "mountPoint"

                            Layout.fillWidth: true
                            variant: "label"
                            elide: Text.ElideMiddle
                            text: card.device.mounted && card.device.mountpoint
                                  ? root.t("bar.disks.mountPoint").replace("%1", card.device.mountpoint)
                                  : root.t("bar.disks.notMounted")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailButton {
                                objectName: "mount"

                                Layout.fillWidth: true
                                variant: "tonal"
                                tone: "primary"
                                size: "sm"
                                icon: "download"
                                text: root.t("bar.disks.mount")
                                enabled: !root.busy && Disks.allowed(card.device, "mount")
                                onClicked: root.actionRequested("mount", card.device.name)
                            }

                            VitrailButton {
                                objectName: "unmount"

                                Layout.fillWidth: true
                                variant: "tonal"
                                tone: "secondary"
                                size: "sm"
                                icon: "close"
                                text: root.t("bar.disks.unmount")
                                enabled: !root.busy && Disks.allowed(card.device, "unmount")
                                onClicked: root.actionRequested("unmount", card.device.name)
                            }

                            VitrailButton {
                                objectName: "eject"

                                Layout.fillWidth: true
                                variant: "plain"
                                tone: "secondary"
                                size: "sm"
                                icon: "eject"
                                text: root.t("bar.disks.eject")
                                enabled: !root.busy && Disks.allowed(card.device, "eject")
                                onClicked: root.actionRequested("eject", card.device.name)
                            }

                            VitrailButton {
                                objectName: "open"

                                Layout.fillWidth: true
                                variant: "plain"
                                tone: "secondary"
                                size: "sm"
                                icon: "folder_open"
                                text: root.t("bar.disks.open")
                                enabled: !root.busy && Disks.allowed(card.device, "open")
                                onClicked: root.actionRequested("open", card.device.mountpoint)
                            }
                        }

                        Repeater {
                            model: Disks.reasons(card.device, root.busy)

                            delegate: VitrailText {
                                required property string modelData

                                objectName: "reason"

                                Layout.fillWidth: true
                                variant: "label"
                                wrapMode: Text.WordWrap
                                text: root.t(modelData)
                            }
                        }
                    }
                }
            }
        }

        VitrailText {
            objectName: "empty"

            Layout.fillWidth: true
            visible: root.ready && root.devices.length === 0
            variant: "body"
            text: root.t("bar.disks.empty")
        }

        VitrailText {
            objectName: "actionError"

            Layout.fillWidth: true
            visible: root.error !== ""
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.error
        }
    }
}
