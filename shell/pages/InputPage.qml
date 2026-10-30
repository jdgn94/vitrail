import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Input category: keyboard layouts and pointer behaviour.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string newLayout: "us"
    property string newVariant: ""

    readonly property var layoutOptions: [
        { key: "us", label: "English (US)" },
        { key: "gb", label: "English (UK)" },
        { key: "es", label: "Español" },
        { key: "latam", label: "Latinoamérica" },
        { key: "br", label: "Português (BR)" },
        { key: "pt", label: "Português (PT)" },
        { key: "de", label: "Deutsch" },
        { key: "fr", label: "Français" },
        { key: "it", label: "Italiano" },
        { key: "ru", label: "Русский" }
    ]

    readonly property var variantOptions: [
        { key: "", label: "Default" },
        { key: "intl", label: "Intl (dead keys)" },
        { key: "nodeadkeys", label: "No dead keys" },
        { key: "dvorak", label: "Dvorak" },
        { key: "colemak", label: "Colemak" },
        { key: "winkeys", label: "Win keys" }
    ]

    readonly property var switchOptions: [
        { key: "grp:alt_shift_toggle", label: "Alt + Shift" },
        { key: "grp:ctrl_shift_toggle", label: "Ctrl + Shift" },
        { key: "grp:super_space_toggle", label: "Super + Space" },
        { key: "grp:caps_toggle", label: "Caps Lock" }
    ]

    // Stored as "layout:variant|layout:variant" so the INI needs no escaping.
    readonly property var layouts: {
        var raw = page.prefs.keyboardLayouts
        if (!raw)
            return []
        var entries = []
        var parts = raw.split("|")
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "")
                continue
            var fields = parts[i].split(":")
            entries.push({ layout: fields[0], variant: fields[1] || "" })
        }
        return entries
    }

    function labelFor(options, key) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].key === key)
                return options[i].label
        }
        return key
    }

    function persist(list) {
        var entries = []
        for (var i = 0; i < list.length; i++)
            entries.push(list[i].layout + ":" + list[i].variant)
        page.prefs.keyboardLayouts = entries.join("|")
    }

    function addLayout() {
        var list = page.layouts.slice()
        list.push({ layout: page.newLayout, variant: page.newVariant })
        page.persist(list)
    }

    function removeLayout(index) {
        var list = page.layouts.slice()
        list.splice(index, 1)
        page.persist(list)
    }

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            Section {
                Layout.fillWidth: true
                icon: "keyboard"
                title: page.t("input.keyboard")
                foreground: page.palette.foreground
                accent: page.palette.primary

                Text {
                    Layout.fillWidth: true
                    text: page.t("keyboard.help")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.layouts.length === 0
                    text: page.t("keyboard.empty")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    opacity: 0.8
                }

                Repeater {
                    model: page.layouts

                    delegate: VitrailSettingRow {
                        id: row

                        required property var modelData
                        required property int index

                        icon: "language"
                        label: page.labelFor(page.layoutOptions, row.modelData.layout)
                        description: row.modelData.variant !== "" ? page.labelFor(page.variantOptions, row.modelData.variant) : ""
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            size: "sm"
                            icon: "close"
                            onClicked: page.removeLayout(row.index)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailSelect {
                        Layout.fillWidth: true
                        label: page.t("keyboard.layout")
                        options: page.layoutOptions
                        current: page.newLayout
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        panel: page.palette.surfaceHigh
                        onSelected: page.newLayout = key
                    }

                    VitrailSelect {
                        Layout.fillWidth: true
                        label: page.t("keyboard.variant")
                        options: page.variantOptions
                        current: page.newVariant
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        panel: page.palette.surfaceHigh
                        onSelected: page.newVariant = key
                    }

                    VitrailButton {
                        Layout.alignment: Qt.AlignBottom
                        variant: "tonal"
                        icon: "add"
                        text: page.t("action.add")
                        onClicked: page.addLayout()
                    }
                }

                VitrailSelect {
                    Layout.fillWidth: true
                    Layout.topMargin: VitrailTokens.gap("xs")
                    label: page.t("keyboard.switch")
                    options: page.switchOptions
                    current: page.prefs.keyboardSwitch
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: page.prefs.keyboardSwitch = key
                }
            }

            Section {
                Layout.fillWidth: true
                icon: "mouse"
                title: page.t("input.mouse")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "ads_click"
                    label: page.t("windows.focusFollows")
                    description: page.t("input.mouseHelp")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        checked: page.prefs.focusFollowsMouse
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.focusFollowsMouse = value }
                    }
                }
            }
        }
    }
}
