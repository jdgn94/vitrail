import QtQuick
import QtQuick.Layouts
import Qt.labs.settings 1.1
import "../../kit"
import "../../kit/base"
import "../../bar/network/network.js" as Network
import "../vpnqueue.js" as Queue
import "../vpnsettings.js" as VpnDoc
import "../vpnview.js" as VpnView

// Connection category: Internet (Ethernet and Wi-Fi), VPN and Bluetooth.
//
// The window cannot run commands, so it reads and asks through files. What it
// shows is the JSON `vitrail.network state` printed at launch (`network`),
// replaced by network-state.json when a newer copy is there. A click writes a
// request and raises its counter in connection.ini; apply-settings.sh runs the
// request (vitrail.network apply) and rewrites network-state.json, which this
// page polls while it waits. `tab` is also the --tab deep link.
//
// The VPN tab shows hypraether-vpn's own model: its connections, credentials,
// traffic mode, domain list and `enabled` marker (the state's `vpn`). It has
// three views: the connections (`VpnList`), the global settings (`VpnGlobal`)
// and one connection's settings (`VpnConnection`); `--view global|<id>` opens
// one. Vitrail keeps one thing of its own, in its private folder
// (`~/.config/vitrail-vpn`, edited by shell/vpnsettings.js): which connections
// the automatic choice may use. The folder belongs to the system user, so no
// rule, credential or file is shared with another one.
// Passwords never travel in a request: `sendSecret` writes them to a private
// file under the runtime folder and the request names only its nonce.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The state injected at launch, and the folder with network-state.json.
    property var network: ({})
    property string configDir: ""
    // $XDG_RUNTIME_DIR (a private folder, "" when there is none): where a
    // password may be left for the helper.
    property string runtime: ""
    // The VPN's private folder (~/.config/vitrail-vpn): the document lives there.
    property string vpnDirectory: ""
    property string tab: "internet"
    // The VPN view to open at first: "global", or a connection's id.
    property string view: ""

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
    // The VPN lists, replaced only when their content changes: a view that is
    // being typed into must not be rebuilt by a state that says the same.
    property var tunnels: []
    property var credentials: []
    property var domains: []
    readonly property var quality: page.vpn.quality || ({})
    readonly property bool enabled: page.vpn.enabled === true
    readonly property string mode: page.vpn.mode || "split"
    // The real request (a click) pending or waiting for its answer ("" when
    // none), when the last one went out, and whether the background probe is
    // in flight. The probe never busies the page (shell/vpnqueue.js); a
    // request made during it waits for its answer. `writing` covers the
    // moment a password takes to reach its file.
    property string busy: ""
    property bool probing: false
    property bool queued: false
    property bool writing: false
    property real sent: 0
    readonly property bool idle: page.busy === "" && !page.writing
    // What the last request did, when it was a VPN one that failed.
    readonly property string failed: page.live.result && page.live.result.code !== 0
                                     && String(page.live.result.verb).indexOf("vpn") === 0 ? page.live.result.verb : ""

    // The VPN document (Vitrail's own part), and the view that is open:
    // "list", "global" or "connection" (of `vpnId`).
    readonly property var doc: VpnDoc.parse(vpnFile.vpnSettings)
    property string vpnView: "list"
    property string vpnId: ""

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function queueState() {
        return { probing: page.probing, busy: page.busy, queued: page.queued }
    }

    function adoptQueue(state) {
        page.probing = state.probing
        page.busy = state.busy
        page.queued = state.queued
    }

    // One request at a time on the channel: written first, counted second.
    // Goes out now, or when the probe in flight has answered.
    function ask(request) {
        var step = Queue.submit(page.queueState(), request)
        page.adoptQueue(step.state)
        if (step.send !== "")
            page.dispatch(step.send)
    }

    function dispatch(request) {
        page.sent = Date.now()
        page.prefs.connectionRequest = request
        page.prefs.connectionSeq = page.prefs.connectionSeq + 1
        poller.restart()
        patience.interval = VitrailTokens.duration(request === Queue.PROBE ? "probeWait" : "patience")
        patience.restart()
    }

    // What was in flight has answered (or timed out): frees the page, or sends
    // the request that waited for the probe.
    function settle() {
        // A request that carried a user name does not stay in connection.ini.
        if (Queue.inFlight(page.queueState()) && page.busy.indexOf("{") >= 0)
            page.prefs.connectionRequest = ""
        var step = Queue.answered(page.queueState())
        page.adoptQueue(step.state)
        if (step.send !== "")
            page.dispatch(step.send)
    }

    // Stores a changed document (null: nothing changed).
    function save(next) {
        if (next !== null)
            vpnFile.vpnSettings = VpnDoc.stringify(next)
    }

    // The document: one QSettings value in the private VPN folder, outside the
    // preference files (vitrail/vpndoc.py migrates the old misc.ini key).
    Settings {
        id: vpnFile

        fileName: page.vpnDirectory + "/settings.ini"
        category: "vpn"

        property string vpnSettings: ""
    }

    function toggle(on, request) {
        page.ask(request + (on ? "-on" : "-off"))
    }

    // A request that carries a password: the password goes to its own file,
    // the request carries the nonce of that file.
    function sendSecret(verb, payload, password) {
        if (page.runtime === "")
            return
        var nonce = VpnView.nonce()
        payload.nonce = nonce
        var text = VpnView.request(verb, payload)
        page.writing = true
        secret.write(page.runtime, nonce, password, function () {
            page.writing = false
            page.ask(text)
        })
    }

    function openGlobal() {
        page.vpnView = "global"
        scroller.contentY = 0
    }

    function openConnection(id) {
        page.vpnId = id
        page.vpnView = "connection"
        scroller.contentY = 0
    }

    function back() {
        page.vpnView = "list"
        scroller.contentY = 0
    }

    function same(one, other) {
        return JSON.stringify(one) === JSON.stringify(other)
    }

    // Takes the VPN lists of the newest state, those that changed only.
    function adopt() {
        var found = page.vpn
        if (!page.same(page.tunnels, found.tunnels || []))
            page.tunnels = found.tunnels || []
        if (!page.same(page.credentials, found.credentials || []))
            page.credentials = found.credentials || []
        if (!page.same(page.domains, found.domains || []))
            page.domains = found.domains || []
        // A connection that is gone takes its settings view with it, and its
        // entry in the document.
        if (page.vpnView === "connection" && !page.tunnels.some(function (one) { return one.id === page.vpnId }))
            page.vpnView = "list"
        if (page.tunnels.length > 0)
            page.save(VpnDoc.prune(page.doc, page.tunnels.map(function (one) { return one.id })))
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
        // The same copy again (a poll found nothing new) must not rebuild the lists.
        if (page.polled === null || page.polled.updated !== data.updated)
            page.polled = data
        if (data.updated >= page.sent && (page.probing || page.busy !== ""))
            page.settle()
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
        running: page.visible && (page.probing || !page.idle)
        repeat: true
        onTriggered: page.poll()
    }

    // A request that never answers (the apply service is not running) frees
    // the page instead of leaving it waiting.
    Timer {
        id: patience

        interval: VitrailTokens.duration("patience")
        onTriggered: page.settle()
    }

    // The VPN tab measures its connections when it opens and every minute
    // while it stays open and nothing else is going on.
    Timer {
        interval: VitrailTokens.duration("probe")
        running: page.visible && page.tab === "vpn" && page.vpn.available === true
        repeat: true
        triggeredOnStart: true
        onTriggered: page.ask(Queue.PROBE)
    }

    SecretFile {
        id: secret
    }

    onLiveChanged: page.adopt()
    Component.onCompleted: {
        page.adopt()
        if (page.view === "global") {
            page.vpnView = "global"
        } else if (page.view !== "") {
            page.vpnId = page.view
            page.vpnView = "connection"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailTabs {
                Layout.fillWidth: true
                tabs: [
                    { key: "internet", icon: "public", label: page.t("connection.tab.internet") },
                    { key: "vpn", icon: "vpn_key", label: page.t("network.vpn") },
                    { key: "bluetooth", icon: "bluetooth", label: page.t("connection.bluetooth") }
                ]
                current: page.tab
                foreground: page.palette.foreground
                accent: page.palette.primary
                onSelected: page.tab = key
            }

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
                VitrailText {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn" && page.failed !== ""
                    variant: "content"
                    color: page.palette.error
                    wrapMode: Text.WordWrap
                    text: page.t("connection.vpn.failed").replace("%1", page.failed)
                }

                VpnList {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn" && page.vpnView === "list"
                    page: page
                }

                VpnGlobal {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn" && page.vpnView === "global"
                    page: page
                }

                VpnConnection {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn" && page.vpnView === "connection"
                    page: page
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
