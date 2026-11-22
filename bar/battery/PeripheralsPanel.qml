import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "battery.js" as Battery

// The peripherals battery element's popup: one row per watched device with its
// kind glyph, its name, a bar and its percentage, and the state ("charging",
// "discharging", "full") with the time left when UPower knows it. A kind the
// user hides has no row. No device at all is one calm line, not an empty card.
// The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `peripheralsHide` preference: a hidden kind draws no row.
    property string hide: ""

    signal settingsRequested()

    readonly property bool ready: Battery.ready(root.snapshot)
    readonly property var devices: Battery.watchedDevices(root.snapshot, root.hide)
    // About six rows fit before the list starts to scroll.
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
                text: root.t("bar.widget.peripherals")
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
            text: root.t("bar.peripherals.unreadable")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, root.listMax)
            visible: root.ready && root.devices.length > 0
            contentWidth: width
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rows

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.devices

                    delegate: ColumnLayout {
                        id: peripheral

                        required property var modelData

                        readonly property var device: peripheral.modelData

                        objectName: "peripheral"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: Battery.kindGlyph(peripheral.device.kind)
                                color: VitrailTokens.color("muted")
                            }

                            VitrailText {
                                objectName: "peripheralName"

                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: peripheral.device.name || ""
                            }

                            VitrailText {
                                objectName: "peripheralPercent"

                                variant: "label"
                                text: Battery.percentText(peripheral.device)
                            }
                        }

                        VitrailSlider {
                            objectName: "peripheralBar"

                            Layout.fillWidth: true
                            size: "thin"
                            continuous: true
                            readOnly: true
                            from: 0
                            to: 100
                            value: Battery.percentage(peripheral.device) || 0
                        }

                        VitrailText {
                            objectName: "peripheralState"

                            Layout.fillWidth: true
                            variant: "label"
                            text: Battery.detailText(peripheral.device, root.strings)
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
            text: root.t("bar.peripherals.empty")
        }
    }
}
