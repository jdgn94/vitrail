import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/network/network.js" as Network
import "../../bar/network/vpn.js" as Vpn

// Connection category: Internet (Ethernet and Wi-Fi), VPN and Bluetooth.
//
// The window cannot run commands, so it reads and asks through files. What it
// shows is the JSON `vitrail.network state` printed at launch (`network`),
// replaced by network-state.json when a newer copy is there. A click writes a
// request and raises its counter in connection.ini; apply-settings.sh runs the
// request (vitrail.network apply) and rewrites network-state.json, which this
// page polls while it waits. `tab` is also the --tab deep link.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The state injected at launch, and the folder with network-state.json.
    property var network: ({})
    property string configDir: ""
    property string tab: "internet"

    // The newest copy of the state: the injected one, or what the file says.
    property var polled: null
    readonly property var live: page.polled !== null && (page.polled.updated || 0) > (page.network.updated || 0)
                                ? page.polled : page.network
    readonly property var wired: (page.live.ethernet || ({})).devices || []
    readonly property var wifi: page.live.wifi || ({})
    readonly property var vpn: page.live.vpn || ({})
    readonly property var bluetooth: page.live.bluetooth || ({})
    readonly property var paired: (page.bluetooth.devices || []).filter(function (device) { return device.paired })
    readonly property var nearby: (page.bluetooth.devices || []).filter(function (device) { return !device.paired })
    // The request waiting for its answer ("" when idle) and when it was sent.
    property string busy: ""
    property real sent: 0
    readonly property bool idle: page.busy === ""

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    // One request at a time: written first, counted second.
    function ask(request) {
        page.busy = request
        page.sent = Date.now()
        page.prefs.connectionRequest = request
        page.prefs.connectionSeq = page.prefs.connectionSeq + 1
        poller.restart()
        patience.restart()
    }

    function toggle(on, request) {
        page.ask(request + (on ? "-on" : "-off"))
    }

    function read(text) {
        var data
        try {
            data = JSON.parse(text)
        } catch (error) {
            return
        }
        if (!data || !data.updated)
            return
        page.polled = data
        if (data.updated >= page.sent)
            page.busy = ""
    }

    function poll() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE)
                page.read(request.responseText)
        }
        request.open("GET", "file://" + page.configDir + "/network-state.json")
        request.send()
    }

    function linkState(state) {
        return ({
            connected: page.t("network.connected"),
            disconnected: page.t("network.offline"),
            unavailable: page.t("network.linkDown")
        })[state] || state
    }

    function parts(list) {
        return list.filter(function (part) { return part !== "" }).join(" · ")
    }

    Timer {
        id: poller

        interval: VitrailTokens.duration("poll")
        running: page.visible && !page.idle
        repeat: true
        onTriggered: page.poll()
    }

    // A request that never answers (the apply service is not running) frees
    // the page instead of leaving it waiting.
    Timer {
        id: patience

        interval: VitrailTokens.duration("patience")
        onTriggered: page.busy = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailSegmented {
                options: [
                    { key: "internet", icon: "public", label: page.t("connection.tab.internet") },
                    { key: "vpn", icon: "vpn_key", label: page.t("network.vpn") },
                    { key: "bluetooth", icon: "bluetooth", label: page.t("connection.bluetooth") }
                ]
                current: page.tab
                foreground: page.palette.foreground
                accent: page.palette.primary
                onSelected: page.tab = key
            }

            Item { Layout.fillWidth: true }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: "refresh"
                busy: page.busy === "refresh"
                enabled: page.idle
                onClicked: page.ask("refresh")
            }
        }

        Flickable {
            id: scroller

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: column

                width: parent.width
                spacing: VitrailTokens.gap("xl")

                // --- Internet ----------------------------------------------
                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "internet"
                    icon: "lan"
                    title: page.t("network.ethernet")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.wired.length === 0
                        variant: "content"
                        text: page.t("network.noDevices")
                    }

                    Repeater {
                        model: page.wired

                        delegate: VitrailSettingRow {
                            id: wiredRow

                            required property var modelData

                            icon: "lan"
                            label: wiredRow.modelData.name
                            description: page.parts([
                                page.linkState(wiredRow.modelData.state),
                                wiredRow.modelData.address,
                                wiredRow.modelData.gateway !== ""
                                    ? page.t("connection.gateway") + " " + wiredRow.modelData.gateway : ""
                            ])
                            foreground: page.palette.foreground
                            muted: page.palette.muted
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "internet"
                    icon: "wifi"
                    title: page.t("network.wifi")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: !page.wifi.available
                        variant: "content"
                        text: page.t("network.wifiMissing")
                    }

                    VitrailSettingRow {
                        visible: page.wifi.available === true
                        icon: page.wifi.enabled ? "wifi" : "wifi_off"
                        label: page.t("network.wifiEnabled")
                        description: page.t("connection.wifi.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.wifi.enabled === true
                            enabled: page.idle
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.toggle(value, "wifi") }
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.wifi.enabled === true
                        variant: "subtitle"
                        text: page.t("connection.wifi.networks")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.wifi.enabled === true && (page.wifi.networks || []).length === 0
                        variant: "content"
                        text: page.t("connection.wifi.none")
                    }

                    Repeater {
                        model: page.wifi.enabled ? (page.wifi.networks || []) : []

                        delegate: VitrailSettingRow {
                            id: wifiRow

                            required property var modelData

                            readonly property string request: wifiRow.modelData.active
                                                              ? "wifi-disconnect" : "wifi-connect:" + wifiRow.modelData.ssid

                            icon: Network.wifiGlyph(wifiRow.modelData.signal / 100)
                            label: wifiRow.modelData.ssid
                            description: page.parts([
                                wifiRow.modelData.active ? page.t("network.connected") : "",
                                wifiRow.modelData.signal + "%",
                                wifiRow.modelData.security !== "" ? wifiRow.modelData.security : page.t("connection.security.open")
                            ])
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailButton {
                                variant: "tonal"
                                tone: wifiRow.modelData.active ? "secondary" : "primary"
                                text: wifiRow.modelData.active ? page.t("network.disconnect") : page.t("network.connect")
                                busy: page.busy === wifiRow.request
                                enabled: page.idle
                                onClicked: page.ask(wifiRow.request)
                            }
                        }
                    }
                }

                // --- VPN ---------------------------------------------------
                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn"
                    icon: "vpn_key"
                    title: page.t("network.vpn")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: !page.vpn.available
                        variant: "content"
                        text: page.t("connection.vpn.missing")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.vpn.available === true && (page.vpn.tunnels || []).length === 0
                        variant: "content"
                        text: page.t("network.vpnEmpty")
                    }

                    Repeater {
                        model: page.vpn.tunnels || []

                        delegate: VitrailSettingRow {
                            id: tunnelRow

                            required property var modelData

                            readonly property string request: (tunnelRow.modelData.active ? "vpn-down:" : "vpn-up:") + tunnelRow.modelData.id

                            icon: tunnelRow.modelData.active ? "shield_lock" : "shield"
                            label: Vpn.title(tunnelRow.modelData.name)
                            description: page.parts([
                                tunnelRow.modelData.active ? page.t("network.connected") : page.t("network.offline"),
                                Vpn.provider(tunnelRow.modelData),
                                tunnelRow.modelData.region
                            ])
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailButton {
                                variant: "tonal"
                                tone: tunnelRow.modelData.active ? "secondary" : "primary"
                                text: tunnelRow.modelData.active ? page.t("network.disconnect") : page.t("network.connect")
                                busy: page.busy === tunnelRow.request
                                enabled: page.idle
                                onClicked: page.ask(tunnelRow.request)
                            }
                        }
                    }
                }

                // --- Bluetooth ---------------------------------------------
                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "bluetooth"
                    icon: "bluetooth"
                    title: page.t("connection.bluetooth")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: !page.bluetooth.available
                        variant: "content"
                        text: page.t("connection.bluetooth.missing")
                    }

                    VitrailSettingRow {
                        visible: page.bluetooth.available === true
                        icon: page.bluetooth.powered ? "bluetooth" : "bluetooth_disabled"
                        label: page.t("connection.bluetooth.enabled")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.bluetooth.powered === true
                            enabled: page.idle
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.toggle(value, "bt") }
                        }
                    }

                    VitrailSettingRow {
                        visible: page.bluetooth.powered === true
                        icon: "bluetooth_searching"
                        label: page.t("connection.bluetooth.scan")
                        description: page.t("connection.bluetooth.scan.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: "tonal"
                            icon: "search"
                            text: page.t("connection.bluetooth.scan")
                            busy: page.busy === "bt-scan"
                            enabled: page.idle
                            onClicked: page.ask("bt-scan")
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "bluetooth" && page.bluetooth.powered === true
                    icon: "devices"
                    title: page.t("connection.bluetooth.paired")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.paired.length === 0
                        variant: "content"
                        text: page.t("connection.bluetooth.none")
                    }

                    Repeater {
                        model: page.paired

                        delegate: DeviceRow {}
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "bluetooth" && page.bluetooth.powered === true && page.nearby.length > 0
                    icon: "bluetooth_searching"
                    title: page.t("connection.bluetooth.nearby")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Repeater {
                        model: page.nearby

                        delegate: DeviceRow {}
                    }
                }
            }
        }
    }

    // A Bluetooth device: its state and battery, and the button that joins or
    // leaves it.
    component DeviceRow: VitrailSettingRow {
        id: deviceRow

        required property var modelData

        readonly property string request: (deviceRow.modelData.connected ? "bt-disconnect:" : "bt-connect:") + deviceRow.modelData.mac

        icon: deviceRow.modelData.connected ? "bluetooth_connected" : "bluetooth"
        label: deviceRow.modelData.name
        description: page.parts([
            deviceRow.modelData.connected ? page.t("network.connected") : page.t("network.offline"),
            deviceRow.modelData.battery === null ? "" : page.t("connection.battery").replace("%1", deviceRow.modelData.battery)
        ])
        foreground: page.palette.foreground
        muted: page.palette.muted

        VitrailButton {
            variant: "tonal"
            tone: deviceRow.modelData.connected ? "secondary" : "primary"
            text: deviceRow.modelData.connected ? page.t("network.disconnect") : page.t("network.connect")
            busy: page.busy === deviceRow.request
            enabled: page.idle
            onClicked: page.ask(deviceRow.request)
        }
    }
}
