import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The power profile popout: the mode in use, a line about what it does, and
// the three modes as a selector, each with its own icon.
Item {
    id: root

    property var strings: ({})
    // power-saver / balanced / performance.
    property string profile: "balanced"

    signal profileRequested(string profile)

    readonly property var modes: [
        { key: "power-saver", icon: "energy_savings_leaf", tone: "primary",
          name: "connection.power.saver", detail: "powerprofile.saver.detail" },
        { key: "balanced", icon: "balance", tone: "muted",
          name: "connection.power.balanced", detail: "powerprofile.balanced.detail" },
        { key: "performance", icon: "speed", tone: "info",
          name: "connection.power.performance", detail: "powerprofile.performance.detail" }
    ]
    readonly property var mode: root.modes.find(function (entry) {
        return entry.key === root.profile
    }) || root.modes[1]

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 320
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: root.mode.icon
                color: VitrailTokens.color(root.mode.tone)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    variant: "subtitle"
                    text: root.t(root.mode.name)
                    elide: Text.ElideRight
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    text: root.t(root.mode.detail)
                }
            }
        }

        VitrailSegmented {
            Layout.fillWidth: true
            options: root.modes.map(function (entry) {
                return { key: entry.key, label: root.t(entry.name), icon: entry.icon }
            })
            current: root.profile
            onSelected: function (key) { root.profileRequested(key) }
        }
    }
}
