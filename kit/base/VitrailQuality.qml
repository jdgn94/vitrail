import QtQuick
import QtQuick.Layouts
import ".."

// Quality of a connection: a signal icon coloured by its level and the
// measurement beside it ("74 ms"). `level` is good, fair, poor or unknown
// (the thresholds live in bar/network/vpn.js, so every surface agrees).
RowLayout {
    id: root

    property string level: "unknown"
    property string text: ""

    readonly property var icons: ({
        good: "signal_cellular_4_bar",
        fair: "signal_cellular_2_bar",
        poor: "signal_cellular_1_bar",
        unknown: "signal_cellular_off"
    })
    readonly property var roles: ({ good: "primary", fair: "info", poor: "error", unknown: "muted" })
    readonly property color tint: VitrailTokens.color(root.roles[root.level] || "muted")

    spacing: VitrailTokens.gap("xs")

    VitrailText {
        variant: "icon"
        text: root.icons[root.level] || root.icons.unknown
        color: root.tint
        font.pixelSize: VitrailTokens.size("subtitle")
    }

    VitrailText {
        variant: "label"
        text: root.text
        color: root.tint
        opacity: 1
    }
}
