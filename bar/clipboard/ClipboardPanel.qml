import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The clipboard card: three tabs over the same surface.
//   History  the entries, with their filters and search;
//   Emojis   the Unicode set, by group, with its own search;
//   Colours  a picker, the last ten colours and the output format.
//
// Presentational: the shell runs cliphist and hyprpicker, holds the entries,
// the emoji data and the colours, and performs every copy.
FocusScope {
    id: root

    property var strings: ({})
    property var entries: []
    property var thumbs: ({})
    property var emojis: []
    property var recent: []
    property bool active: false
    property real opacityLevel: VitrailTokens.opacity
    property int max: 100
    property string color: ""
    property string colorFormat: "hex"
    property string mode: "history"
    // The tab the panel opens on: the IPC decides.
    property string startMode: "history"

    signal picked(string id, string mode)
    signal closeRequested()
    signal thumbRequested(string id)
    signal removeRequested(string id)
    signal clearRequested()
    signal emojiPicked(string emoji)
    signal colorCopied(string text)
    signal colorPickRequested()
    signal colorFormatPicked(string format)
    // The tab the user picked, so the shell can load that tab's data.
    signal modeSelected(string mode)

    readonly property int margin: VitrailTokens.gap("md")

    // Keeps the keyboard when no field has it (the colours tab).
    focus: true
    implicitWidth: 420
    implicitHeight: content.implicitHeight + 2 * root.margin

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    onActiveChanged: {
        if (!root.active)
            return
        root.mode = root.startMode
    }

    // The IPC can ask for another tab while the panel is open.
    onStartModeChanged: if (root.active)
        root.mode = root.startMode

    // Escape closes from any tab, even when no field has the keyboard: the key
    // climbs from the focused item to here. (Not a `Shortcut`: it crashes
    // Quickshell when the bar stops.)
    Keys.enabled: root.active
    Keys.onEscapePressed: root.closeRequested()

    // The same container the bar draws: glass or solid, its radius and edge.
    VitrailSurface {
        anchors.fill: parent
        style: VitrailTokens.surfaceMode
        radius: VitrailTokens.radius
        tint: VitrailTokens.color("surface")
        opacityLevel: root.opacityLevel
    }

    // A click on the card's own padding belongs to the card, not to the
    // full-screen layer behind it (which closes the panel).
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content

        x: root.margin
        y: root.margin
        width: parent.width - 2 * root.margin
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailTabs {
                Layout.fillWidth: true
                current: root.mode
                tabs: [
                    { key: "history", label: root.t("clipboard.mode.history") },
                    { key: "emoji", label: root.t("clipboard.mode.emoji") },
                    { key: "color", label: root.t("clipboard.mode.color") }
                ]
                onSelected: function (key) {
                    root.mode = key
                    root.modeSelected(key)
                }
            }
        }

        ClipboardHistory {
            Layout.fillWidth: true
            visible: root.mode === "history"
            active: root.active && root.mode === "history"
            strings: root.strings
            entries: root.entries
            thumbs: root.thumbs
            max: root.max
            onPicked: function (id, mode) { root.picked(id, mode) }
            onRemoveRequested: function (id) { root.removeRequested(id) }
            onClearRequested: root.clearRequested()
            onThumbRequested: function (id) { root.thumbRequested(id) }
            onCloseRequested: root.closeRequested()
        }

        ClipboardEmoji {
            Layout.fillWidth: true
            visible: root.mode === "emoji"
            active: root.active && root.mode === "emoji"
            strings: root.strings
            emojis: root.emojis
            onPicked: function (emoji) { root.emojiPicked(emoji) }
            onCloseRequested: root.closeRequested()
        }

        ClipboardColors {
            Layout.fillWidth: true
            visible: root.mode === "color"
            active: root.active && root.mode === "color"
            strings: root.strings
            recent: root.recent
            hex: root.color
            format: root.colorFormat
            onCopied: function (text) { root.colorCopied(text) }
            onPickRequested: root.colorPickRequested()
            onFormatPicked: function (format) { root.colorFormatPicked(format) }
        }
    }
}
