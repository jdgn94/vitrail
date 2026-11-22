import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "dnd.js" as Dnd

// The Do Not Disturb popup: the switch, the three durations and the
// applications allowed through. It writes the notifications layer's own keys
// (`notificationDnd`, `notificationMuteUntil`, `notificationUrgentApps`,
// `notificationUrgentBypass`), so the bell, the panel and this card never
// disagree. The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property bool dndOn: false
    property double muteUntil: 0
    property int defaultMinutes: Dnd.DEFAULT_MINUTES
    property string apps: ""
    property bool bypass: true
    property double now: Date.now()

    signal settingsRequested()
    signal toggleRequested()
    signal durationRequested(int minutes)
    signal appsEdited(string text)
    signal bypassToggled(bool value)

    readonly property var state: Dnd.state(root.dndOn, root.muteUntil, root.now)
    readonly property var allowed: Dnd.appList(root.apps)

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
                text: root.t("bar.widget.dnd")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                objectName: "dndState"

                Layout.fillWidth: true
                variant: "body"
                wrapMode: Text.WordWrap
                text: Dnd.summary(root.dndOn, root.muteUntil, root.now, root.t)
            }

            VitrailSwitch {
                objectName: "dndSwitch"

                checked: root.state.on
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                onToggled: root.toggleRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            text: root.t("bar.dnd.duration")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: Dnd.DURATIONS

                delegate: VitrailButton {
                    required property int modelData

                    objectName: "duration-" + modelData

                    Layout.fillWidth: true
                    variant: root.defaultMinutes === modelData ? "tonal" : "plain"
                    tone: "secondary"
                    size: "sm"
                    text: Dnd.durationLabel(modelData, root.t)
                    onClicked: root.durationRequested(modelData)
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            text: root.t("bar.dnd.apps")
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: root.t("bar.dnd.apps.help")
        }

        Repeater {
            model: root.allowed

            delegate: VitrailSettingRow {
                id: allowedApp

                required property string modelData

                objectName: "dndApp"

                Layout.fillWidth: true
                icon: "notifications_active"
                label: allowedApp.modelData
                foreground: VitrailTokens.color("foreground")
                muted: VitrailTokens.color("muted")

                VitrailButton {
                    objectName: "dndAppRemove"

                    variant: "text"
                    tone: "error"
                    icon: "delete"
                    onClicked: root.appsEdited(Dnd.withoutApp(root.apps, allowedApp.modelData))
                }
            }
        }

        VitrailText {
            objectName: "dndAppsEmpty"

            Layout.fillWidth: true
            visible: root.allowed.length === 0
            variant: "label"
            text: root.t("bar.dnd.apps.empty")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailField {
                id: appField

                objectName: "dndAppField"

                Layout.fillWidth: true
                label: root.t("bar.dnd.app.add")
                onAccepted: root.addApp()
            }

            VitrailButton {
                objectName: "dndAppAdd"

                Layout.alignment: Qt.AlignBottom
                variant: "tonal"
                tone: "secondary"
                icon: "add"
                text: root.t("action.add")
                enabled: appField.text.trim() !== ""
                onClicked: root.addApp()
            }
        }

        VitrailSettingRow {
            Layout.fillWidth: true
            icon: "priority_high"
            label: root.t("bar.dnd.bypass")
            description: root.t("bar.dnd.bypass.help")
            foreground: VitrailTokens.color("foreground")
            muted: VitrailTokens.color("muted")

            VitrailSwitch {
                objectName: "dndBypass"

                checked: root.bypass
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                onToggled: function (value) { root.bypassToggled(value) }
            }
        }
    }

    function addApp() {
        var name = appField.text.trim()
        if (name === "")
            return
        root.appsEdited(Dnd.withApp(root.apps, name))
        appField.text = ""
    }
}
