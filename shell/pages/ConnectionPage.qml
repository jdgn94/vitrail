import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/network/network.js" as Network
import "../../bar/network/vpn.js" as Vpn
import "../vpnsettings.js" as VpnDoc

// Connection category: Internet (Ethernet and Wi-Fi), VPN and Bluetooth.
//
// The window cannot run commands, so it reads and asks through files. What it
// shows is the JSON `vitrail.network state` printed at launch (`network`),
// replaced by network-state.json when a newer copy is there. A click writes a
// request and raises its counter in connection.ini; apply-settings.sh runs the
// request (vitrail.network apply) and rewrites network-state.json, which this
// page polls while it waits. `tab` is also the --tab deep link.
//
// The VPN tab also keeps a document (users, which connection each may use, the
// mode and host rule of each connection, extra connections) in misc.ini as
// `vpnSettings`: this page is its only writer (shell/vpnsettings.js edits it).
// A URL added to a rule is saved as waiting, `vpn-resolve:<url>` asks
// vitrail.network for its addresses and subdomains, and the answer
// (`resolved` in network-state.json) is filed into the waiting host.
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

    // The VPN document, and what is open in it: a connection's settings, and
    // the host (connection + URL) whose domains and addresses are listed.
    readonly property var doc: VpnDoc.parse(page.prefs.vpnSettings)
    readonly property bool waiting: VpnDoc.pending(page.doc)
    property string openTunnel: ""
    property string openHost: ""
    property string extraType: "openvpn"

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

    // Stores a changed document (null: nothing changed).
    function save(next) {
        if (next !== null)
            page.prefs.vpnSettings = VpnDoc.stringify(next)
    }

    function addUser() {
        var next = VpnDoc.addUser(page.doc, userField.text)
        if (next === null)
            return
        page.save(next)
        userField.text = ""
    }

    // A URL typed into a connection's host field: saved as waiting, then asked.
    function addHost(vpn, field) {
        var url = VpnDoc.normalizeUrl(field.text)
        var next = url === "" ? null : VpnDoc.addHost(page.doc, vpn, url)
        if (next === null) {
            field.errorText = page.t(url === "" ? "connection.vpn.host.invalid" : "connection.vpn.host.duplicate")
            field.error = true
            field.shake()
            return
        }
        page.save(next)
        field.text = ""
        page.ask("vpn-resolve:" + url)
    }

    function retryHost(vpn, url) {
        page.save(VpnDoc.markPending(page.doc, vpn, url))
        page.ask("vpn-resolve:" + url)
    }

    function addExtra() {
        var next = VpnDoc.addExtra(page.doc, extraName.text, page.extraType, extraPath.text)
        if (next === null)
            return
        page.save(next)
        extraName.text = ""
        extraPath.text = ""
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
        // The same copy again (a poll found nothing new) must not rebuild the lists.
        if (page.polled === null || page.polled.updated !== data.updated)
            page.polled = data
        if (data.resolved)
            page.save(VpnDoc.merge(page.doc, data.resolved))
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

    function userNames(ids) {
        return ids.map(function (id) {
            var user = page.doc.users.filter(function (one) { return one.id === id })[0]
            return user ? user.name : id
        }).join(", ")
    }

    function parts(list) {
        return list.filter(function (part) { return part !== "" }).join(" · ")
    }

    Timer {
        id: poller

        interval: VitrailTokens.duration("poll")
        running: page.visible && (!page.idle || (page.waiting && page.tab === "vpn"))
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
                    icon: "group"
                    title: page.t("connection.vpn.users")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "content"
                        wrapMode: Text.WordWrap
                        text: page.t("connection.vpn.users.help")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.doc.users.length === 0
                        variant: "content"
                        text: page.t("connection.vpn.users.empty")
                    }

                    Repeater {
                        model: page.doc.users

                        delegate: RowLayout {
                            id: userRow

                            required property var modelData

                            readonly property bool current: page.doc.active === userRow.modelData.id

                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                variant: "icon"
                                text: "person"
                                filled: userRow.current
                                color: userRow.current ? page.palette.primary : page.palette.muted
                            }

                            VitrailField {
                                Layout.fillWidth: true
                                size: "sm"
                                text: userRow.modelData.name
                                onAccepted: page.save(VpnDoc.renameUser(page.doc, userRow.modelData.id, text))
                            }

                            VitrailButton {
                                variant: userRow.current ? "tonal" : "outlined"
                                tone: userRow.current ? "primary" : "secondary"
                                text: userRow.current ? page.t("connection.vpn.user.active") : page.t("connection.vpn.user.use")
                                enabled: !userRow.current
                                onClicked: page.save(VpnDoc.setActive(page.doc, userRow.modelData.id))
                            }

                            VitrailButton {
                                variant: "text"
                                tone: "error"
                                icon: "delete"
                                onClicked: page.save(VpnDoc.removeUser(page.doc, userRow.modelData.id))
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        VitrailField {
                            id: userField

                            Layout.fillWidth: true
                            size: "sm"
                            label: page.t("connection.vpn.user.name")
                            onAccepted: page.addUser()
                        }

                        VitrailButton {
                            variant: "flat"
                            icon: "person_add"
                            text: page.t("connection.vpn.user.add")
                            enabled: userField.text.trim() !== ""
                            onClicked: page.addUser()
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn"
                    icon: "vpn_key"
                    title: page.t("connection.vpn.connections")
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

                        delegate: ColumnLayout {
                            id: tunnel

                            required property var modelData

                            readonly property string vpnId: tunnel.modelData.id
                            readonly property var assignment: VpnDoc.assignmentOf(page.doc, tunnel.vpnId)
                            readonly property bool open: page.openTunnel === tunnel.vpnId
                            readonly property string request: (tunnel.modelData.active ? "vpn-down:" : "vpn-up:") + tunnel.vpnId

                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailSettingRow {
                                icon: tunnel.modelData.active ? "shield_lock" : "shield"
                                label: Vpn.title(tunnel.modelData.name)
                                description: page.parts([
                                    tunnel.modelData.active ? page.t("network.connected") : page.t("network.offline"),
                                    Vpn.provider(tunnel.modelData),
                                    tunnel.modelData.region,
                                    page.userNames(tunnel.assignment.users)
                                ])
                                foreground: page.palette.foreground
                                muted: page.palette.muted

                                VitrailButton {
                                    variant: "plain"
                                    tone: "secondary"
                                    icon: tunnel.open ? "expand_less" : "tune"
                                    onClicked: page.openTunnel = tunnel.open ? "" : tunnel.vpnId
                                }

                                VitrailButton {
                                    variant: "tonal"
                                    tone: tunnel.modelData.active ? "secondary" : "primary"
                                    text: tunnel.modelData.active ? page.t("network.disconnect") : page.t("network.connect")
                                    busy: page.busy === tunnel.request
                                    enabled: page.idle
                                    onClicked: page.ask(tunnel.request)
                                }
                            }

                            // This connection's users, mode and hosts.
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: VitrailTokens.gap("xl")
                                visible: tunnel.open
                                spacing: VitrailTokens.gap("sm")

                                VitrailText {
                                    variant: "subtitle"
                                    text: page.t("connection.vpn.available")
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "content"
                                    wrapMode: Text.WordWrap
                                    text: page.doc.users.length === 0 ? page.t("connection.vpn.available.noUsers")
                                          : tunnel.assignment.users.length === 0 ? page.t("connection.vpn.available.everyone")
                                          : page.t("connection.vpn.available.some")
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: VitrailTokens.gap("sm")

                                    Repeater {
                                        model: page.doc.users

                                        delegate: VitrailButton {
                                            id: chip

                                            required property var modelData

                                            readonly property bool chosen: tunnel.assignment.users.indexOf(chip.modelData.id) >= 0

                                            size: "sm"
                                            variant: chip.chosen ? "tonal" : "outlined"
                                            tone: chip.chosen ? "primary" : "secondary"
                                            icon: chip.chosen ? "check" : ""
                                            text: chip.modelData.name
                                            onClicked: page.save(VpnDoc.toggleUser(page.doc, tunnel.vpnId, chip.modelData.id))
                                        }
                                    }
                                }

                                VitrailText {
                                    variant: "subtitle"
                                    text: page.t("connection.vpn.mode")
                                }

                                VitrailSegmented {
                                    options: [
                                        { key: "split", icon: "call_split", label: page.t("connection.vpn.mode.split") },
                                        { key: "full", icon: "public", label: page.t("connection.vpn.mode.full") }
                                    ]
                                    current: tunnel.assignment.mode
                                    foreground: page.palette.foreground
                                    accent: page.palette.primary
                                    onSelected: page.save(VpnDoc.setMode(page.doc, tunnel.vpnId, key))
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "content"
                                    wrapMode: Text.WordWrap
                                    text: page.t("connection.vpn.mode.help")
                                }

                                VitrailText {
                                    variant: "subtitle"
                                    text: page.t("connection.vpn.hosts")
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "content"
                                    wrapMode: Text.WordWrap
                                    text: page.t("connection.vpn.hosts.help")
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    visible: tunnel.assignment.hosts.length === 0
                                    variant: "content"
                                    text: page.t("connection.vpn.hosts.empty")
                                }

                                Repeater {
                                    model: tunnel.assignment.hosts

                                    delegate: HostRow {
                                        vpn: tunnel.vpnId
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: VitrailTokens.gap("sm")

                                    VitrailField {
                                        id: hostField

                                        Layout.fillWidth: true
                                        size: "sm"
                                        label: page.t("connection.vpn.host.url")
                                        placeholder: "https://example.com"
                                        onAccepted: if (page.idle) page.addHost(tunnel.vpnId, hostField)
                                        onTextChanged: hostField.error = false
                                    }

                                    VitrailButton {
                                        variant: "flat"
                                        icon: "add"
                                        text: page.t("connection.vpn.host.add")
                                        busy: page.busy.indexOf("vpn-resolve:") === 0
                                        enabled: page.idle && hostField.text.trim() !== ""
                                        onClicked: page.addHost(tunnel.vpnId, hostField)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "vpn"
                    icon: "lan"
                    title: page.t("connection.vpn.extra")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "content"
                        wrapMode: Text.WordWrap
                        text: page.t("connection.vpn.extra.help")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.doc.extra.length === 0
                        variant: "content"
                        text: page.t("connection.vpn.extra.empty")
                    }

                    Repeater {
                        model: page.doc.extra

                        delegate: VitrailSettingRow {
                            id: extraRow

                            required property var modelData
                            required property int index

                            icon: "vpn_lock"
                            label: extraRow.modelData.name
                            description: page.parts([page.t("connection.vpn.extra.type." + extraRow.modelData.type), extraRow.modelData.path])
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailButton {
                                variant: "text"
                                tone: "error"
                                icon: "delete"
                                onClicked: page.save(VpnDoc.removeExtra(page.doc, extraRow.index))
                            }
                        }
                    }

                    VitrailField {
                        id: extraName

                        Layout.fillWidth: true
                        size: "sm"
                        label: page.t("connection.vpn.extra.name")
                    }

                    VitrailSegmented {
                        options: [
                            { key: "openvpn", label: page.t("connection.vpn.extra.type.openvpn") },
                            { key: "wireguard", label: page.t("connection.vpn.extra.type.wireguard") },
                            { key: "other", label: page.t("connection.vpn.extra.type.other") }
                        ]
                        current: page.extraType
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.extraType = key
                    }

                    VitrailField {
                        id: extraPath

                        Layout.fillWidth: true
                        size: "sm"
                        label: page.t("connection.vpn.extra.path")
                        onAccepted: page.addExtra()
                    }

                    VitrailButton {
                        variant: "flat"
                        icon: "add"
                        text: page.t("connection.vpn.extra.add")
                        enabled: extraName.text.trim() !== "" && extraPath.text.trim() !== ""
                        onClicked: page.addExtra()
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

    // A host of a connection's rule: its URL and how much it resolved to, a
    // button to list (and prune) its domains and addresses, one to look it up
    // again, and one to drop it.
    component HostRow: ColumnLayout {
        id: hostRow

        required property var modelData
        property string vpn: ""

        readonly property string key: hostRow.vpn + "|" + hostRow.modelData.url
        readonly property bool open: page.openHost === hostRow.key
        readonly property bool again: hostRow.modelData.retry === true && hostRow.modelData.pending !== true

        Layout.fillWidth: true
        spacing: VitrailTokens.gap("xs")

        VitrailSettingRow {
            icon: hostRow.modelData.pending ? "hourglass_top" : hostRow.again ? "sync_problem" : "language"
            label: hostRow.modelData.url
            description: hostRow.modelData.pending ? page.t("connection.vpn.host.resolving")
                         : page.parts([
                               page.t("connection.vpn.host.counts").replace("%1", hostRow.modelData.ips.length)
                                   .replace("%2", hostRow.modelData.domains.length),
                               hostRow.again ? page.t("connection.vpn.host.incomplete") : ""
                           ])
            foreground: page.palette.foreground
            muted: page.palette.muted

            VitrailButton {
                visible: hostRow.again
                variant: "tonal"
                icon: "refresh"
                text: page.t("connection.vpn.host.retry")
                enabled: page.idle
                onClicked: page.retryHost(hostRow.vpn, hostRow.modelData.url)
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: hostRow.open ? "expand_less" : "expand_more"
                onClicked: page.openHost = hostRow.open ? "" : hostRow.key
            }

            VitrailButton {
                variant: "text"
                tone: "error"
                icon: "delete"
                onClicked: page.save(VpnDoc.removeHost(page.doc, hostRow.vpn, hostRow.modelData.url))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VitrailTokens.gap("xl")
            visible: hostRow.open
            spacing: VitrailTokens.gap("xs")

            VitrailText {
                variant: "label"
                text: page.t("connection.vpn.host.domains")
            }

            Flow {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                Repeater {
                    model: hostRow.modelData.domains

                    delegate: VitrailButton {
                        id: domainChip

                        required property string modelData

                        size: "sm"
                        variant: "tonal"
                        tone: "secondary"
                        icon: "close"
                        text: domainChip.modelData
                        onClicked: page.save(VpnDoc.removeDomain(page.doc, hostRow.vpn, hostRow.modelData.url, domainChip.modelData))
                    }
                }
            }

            VitrailText {
                variant: "label"
                text: page.t("connection.vpn.host.ips")
            }

            Flow {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                Repeater {
                    model: hostRow.modelData.ips

                    delegate: VitrailButton {
                        id: addressChip

                        required property string modelData

                        size: "sm"
                        variant: "tonal"
                        tone: "secondary"
                        icon: "close"
                        text: addressChip.modelData
                        onClicked: page.save(VpnDoc.removeIp(page.doc, hostRow.vpn, hostRow.modelData.url, addressChip.modelData))
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
