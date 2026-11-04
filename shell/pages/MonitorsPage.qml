import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../monitorsview.js" as View

// Monitors category: one card per Hyprland output, with the mode, scale,
// rotation, position, mirror and enabled state the user wants it to keep.
//
// The window cannot run commands: `bin/vitrail-settings` injects the live
// state as `--monitors`, and `vitrail-monitors apply` rewrites
// monitor-state.json after every change (the path unit runs it through
// apply-settings.sh). The page polls that file while it waits, then adopts it.
// The overrides are one JSON document in monitors.ini; an output without an
// entry follows Hyprland's defaults.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string configDir: ""
    // { available, monitors: [...], overrides } as injected at launch.
    property var monitors: ({ available: false, monitors: [] })

    property var live: page.monitors && page.monitors.monitors ? page.monitors.monitors : []
    property bool available: page.monitors && page.monitors.available === true
    // A change is on its way to the compositor; poll until the state answers.
    property bool pending: false
    property double sent: 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function document() {
        return View.parse(page.prefs.monitorOverrides || "")
    }

    // What the card shows: the saved override, or the live state.
    function spec(monitor) {
        return View.override(page.document(), monitor.name) || View.seed(monitor)
    }

    function set(name, patch, monitor) {
        var text = View.update(page.prefs.monitorOverrides || "", name, patch, monitor)
        if (text === null)
            return
        page.prefs.monitorOverrides = text
        page.wait()
    }

    function reset(name) {
        var text = View.remove(page.prefs.monitorOverrides || "", name)
        if (text === null)
            return
        page.prefs.monitorOverrides = text
        page.wait()
    }

    // A typed position, committed when the field is accepted or loses focus.
    function setPosition(monitor, x, y) {
        var left = Number(x)
        var top = Number(y)
        if (isNaN(left) || isNaN(top))
            return
        page.set(monitor.name, { position: Math.round(left) + "x" + Math.round(top) }, monitor)
    }

    function wait() {
        page.sent = Date.now()
        page.pending = true
        poller.start()
        patience.restart()
    }

    function poll() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE)
                page.read(request.responseText)
        }
        request.open("GET", "file://" + page.configDir + "/monitor-state.json")
        request.send()
    }

    function read(text) {
        var data
        try {
            data = JSON.parse(text)
        } catch (error) {
            return
        }
        if (!data || (data.updated || 0) < page.sent)
            return
        page.live = data.monitors || []
        page.available = data.available === true
        page.pending = false
        poller.stop()
    }

    Timer {
        id: poller

        interval: VitrailTokens.duration("poll")
        running: false
        repeat: true
        onTriggered: page.poll()
    }

    // A request that never answers (the apply service is not running) frees
    // the page instead of leaving it waiting.
    Timer {
        id: patience

        interval: VitrailTokens.duration("patience")
        onTriggered: page.pending = false
    }

    Component.onCompleted: page.poll()

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        Text {
            Layout.fillWidth: true
            text: page.t("monitors.help")
            color: page.palette.muted
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: !page.available
            text: page.t("monitors.unavailable")
            color: page.palette.muted
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
            wrapMode: Text.WordWrap
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

                Repeater {
                    model: page.live

                    delegate: Section {
                        id: card

                        required property var modelData

                        readonly property var shown: page.spec(card.modelData)
                        readonly property var place: View.position(card.shown)
                        readonly property var others: View.others(page.live, card.modelData.name)

                        Layout.fillWidth: true
                        title: card.modelData.name
                        icon: "monitor"
                        badge: page.t("badge.live")
                        foreground: page.palette.foreground
                        accent: page.palette.primary

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.description
                            color: page.palette.muted
                            font.pixelSize: 12
                            font.family: VitrailTokens.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.t("monitors.current") + " " + View.label(card.modelData)
                            color: page.palette.muted
                            font.pixelSize: 12
                            font.family: VitrailTokens.fontFamily
                        }

                        VitrailSettingRow {
                            icon: "power_settings_new"
                            label: page.t("monitors.enabled")
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSwitch {
                                checked: !card.shown.disabled
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onToggled: function (value) {
                                    page.set(card.modelData.name, { disabled: !value }, card.modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("md")
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1

                            VitrailSelect {
                                Layout.fillWidth: true
                                label: page.t("monitors.mode")
                                current: card.shown.mode
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                options: View.modes(card.modelData).map(function (mode) {
                                    return {
                                        key: mode,
                                        label: mode === "preferred" ? page.t("monitors.mode.preferred")
                                                                    : View.modeLabel(mode)
                                    }
                                })
                                onSelected: function (key) {
                                    page.set(card.modelData.name, { mode: key }, card.modelData)
                                }
                            }

                            VitrailSelect {
                                Layout.preferredWidth: 150
                                label: page.t("monitors.rotation")
                                current: String(View.degreesOf(card.shown.transform))
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                options: [
                                    { key: "0", label: "0°" },
                                    { key: "90", label: "90°" },
                                    { key: "180", label: "180°" },
                                    { key: "270", label: "270°" }
                                ]
                                onSelected: function (key) {
                                    page.set(card.modelData.name, { transform: View.transformOf(key) },
                                             card.modelData)
                                }
                            }
                        }

                        VitrailSlider {
                            Layout.fillWidth: true
                            label: page.t("monitors.scale")
                            suffix: "×"
                            from: 0.5
                            to: 3.0
                            stepSize: 0.25
                            value: card.shown.scale
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onMoved: page.set(card.modelData.name, { scale: value }, card.modelData)
                        }

                        VitrailSettingRow {
                            icon: "open_with"
                            label: page.t("monitors.position.auto")
                            description: page.t("monitors.position.help")
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSwitch {
                                checked: card.place.auto
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onToggled: function (value) {
                                    page.set(card.modelData.name, {
                                        position: value ? "auto" : card.place.x + "x" + card.place.y
                                    }, card.modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("md")
                            enabled: !card.shown.disabled && !card.place.auto
                            opacity: card.shown.disabled || card.place.auto ? 0.35 : 1

                            VitrailField {
                                id: posX

                                Layout.fillWidth: true
                                label: page.t("monitors.position.x")
                                text: String(card.place.x)
                                onAccepted: page.setPosition(card.modelData, text, posY.text)
                                onActiveFocusChanged: {
                                    if (!activeFocus)
                                        page.setPosition(card.modelData, text, posY.text)
                                }
                            }

                            VitrailField {
                                id: posY

                                Layout.fillWidth: true
                                label: page.t("monitors.position.y")
                                text: String(card.place.y)
                                onAccepted: page.setPosition(card.modelData, posX.text, text)
                                onActiveFocusChanged: {
                                    if (!activeFocus)
                                        page.setPosition(card.modelData, posX.text, text)
                                }
                            }
                        }

                        VitrailSelect {
                            Layout.fillWidth: true
                            label: page.t("monitors.mirror")
                            current: card.shown.mirror
                            enabled: !card.shown.disabled
                            opacity: card.shown.disabled ? 0.35 : 1
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            options: [{ key: "", label: page.t("monitors.mirror.none") }].concat(
                                card.others.map(function (name) { return { key: name, label: name } }))
                            onSelected: function (key) {
                                page.set(card.modelData.name, { mirror: key }, card.modelData)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            Text {
                                Layout.fillWidth: true
                                text: page.t("monitors.reset.help")
                                color: page.palette.muted
                                font.pixelSize: 12
                                font.family: VitrailTokens.fontFamily
                                wrapMode: Text.WordWrap
                            }

                            VitrailButton {
                                text: page.t("monitors.reset")
                                variant: "outlined"
                                tone: "secondary"
                                onClicked: page.reset(card.modelData.name)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.live.length === 0
                    text: page.t("monitors.none")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
