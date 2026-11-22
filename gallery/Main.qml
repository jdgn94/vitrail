import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../kit/composed"
import "../bar"
import "../bar/volume"
import "../bar/updates"
import "../bar/disks"
import "../bar/containers"
import "../bar/brightness"
import "../bar/battery"
import "../bar/health"
import "../bar/privacy"
import "../bar/weather"
import "../bar/downloads"
import "../bar/kit" as BarKit
import "../kit/args.js" as Args
import "../kit/frame.js" as Frame

// Visual contract: every component × every variant for one theme.
// bin/vitrail-gallery picks the theme with --theme and --surface.
Window {
    id: app

    readonly property bool dark: Args.value("--theme", "dark") === "dark"
    readonly property var palettes: Args.json("--palette", ({}))
    readonly property var frames: Object.keys(VitrailVariants.frame)
    readonly property var bars: Object.keys(VitrailVariants.bar)
    readonly property var fits: Object.keys(VitrailVariants.wallpaper)
    readonly property var buttons: Object.keys(VitrailVariants.button)
    readonly property var fields: Object.keys(VitrailVariants.field)
    readonly property var edges: ["left", "top", "right", "bottom"]
    // Optional image or video to preview the wallpaper fits with.
    readonly property string wallpaperFile: Args.value("--wallpaper", "")
    // Each preview is a full screen scaled down, so tokens keep real sizes.
    readonly property size screenSize: Qt.size(1280, 720)
    readonly property real scale: Number(Args.value("--scale", "0.24"))
    // A fixed spectrum for the visualiser previews: no audio in the gallery.
    readonly property var sampleLevels: {
        var out = []
        for (var i = 0; i < VitrailTokens.visualiser.bars; i++)
            out.push(Math.max(0, Math.round(30 + 32 * Math.sin(i / 4.5) + 18 * Math.sin(i / 1.7))))
        return out
    }

    width: content.implicitWidth + 2 * VitrailTokens.gap("xl")
    height: content.implicitHeight + 2 * VitrailTokens.gap("xl")
    visible: true
    color: wallpaper.surfaceHigh
    title: "Vitrail gallery"

    VitrailPalette {
        id: wallpaper

        dark: app.dark
        data: (app.dark ? app.palettes.dark : app.palettes.light) || ({})
    }

    Component.onCompleted: {
        VitrailTokens.configure(wallpaper, app.dark, Args.value("--surface", "glass"), ({}))
        // bar/ reaches the kit through its own `kit` link: a second singleton.
        BarKit.VitrailTokens.configure(wallpaper, app.dark, Args.value("--surface", "glass"), ({}))
        var target = Args.value("--grab", "")
        if (target !== "")
            grabTimer.start()
    }

    Timer {
        id: grabTimer

        // Longer than the slowest motion profile, so nothing is mid-animation.
        interval: VitrailTokens.duration("slow") * 3
        onTriggered: content.grabToImage(function (result) {
            result.saveToFile(Args.value("--grab", ""))
            Qt.quit()
        })
    }

    ColumnLayout {
        id: content

        x: VitrailTokens.gap("xl")
        y: VitrailTokens.gap("xl")
        spacing: VitrailTokens.gap("lg")

        VitrailText {
            variant: "title"
            text: "VitrailButton · variant × tone"
        }

        GridLayout {
            columns: 7
            columnSpacing: VitrailTokens.gap("lg")
            rowSpacing: VitrailTokens.gap("md")

            Repeater {
                model: app.buttons

                delegate: Repeater {
                    id: buttonRow

                    required property string modelData

                    model: [
                        { tone: "primary", text: buttonRow.modelData, icon: "" },
                        { tone: "secondary", text: "Secondary", icon: "" },
                        { tone: "info", text: "Info", icon: "" },
                        { tone: "error", text: "Error", icon: "" },
                        { tone: "primary", text: "Download", icon: "download" },
                        { tone: "primary", text: "", icon: "favorite" },
                        { tone: "primary", text: "Disabled", icon: "", disabled: true }
                    ]

                    delegate: VitrailButton {
                        required property var modelData

                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        variant: buttonRow.modelData
                        tone: modelData.tone
                        text: modelData.text
                        icon: modelData.icon
                        enabled: !modelData.disabled
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailBadge · count × tone"
        }

        GridLayout {
            columns: 6
            columnSpacing: VitrailTokens.gap("lg")
            rowSpacing: VitrailTokens.gap("md")

            Repeater {
                model: ["1", "9", "9+"]

                delegate: Repeater {
                    id: badgeRow

                    required property string modelData

                    model: ["error", "primary", "info"]

                    delegate: VitrailBadge {
                        required property string modelData

                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        text: badgeRow.modelData
                        tone: modelData
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailSlider · size × segments × icons × read-only"
        }

        GridLayout {
            columns: 3
            columnSpacing: VitrailTokens.gap("xl")
            rowSpacing: VitrailTokens.gap("md")

            Repeater {
                model: ["sm", "md", "lg"]

                delegate: VitrailSlider {
                    required property string modelData

                    Layout.preferredWidth: 320
                    label: "size " + modelData
                    suffix: "%"
                    from: 0
                    to: 100
                    value: 45
                    size: modelData
                }
            }

            VitrailSlider {
                Layout.preferredWidth: 320
                label: "brightness · 0–80% primary, then error"
                suffix: "%"
                from: 0
                to: 100
                value: 90
                size: "lg"
                icon: "light_mode"
                segments: [
                    { to: 0.8, color: VitrailTokens.color("primary") },
                    { to: 1, color: VitrailTokens.color("error") }
                ]
            }

            VitrailSlider {
                Layout.preferredWidth: 320
                label: "volume · icons, filled stop"
                suffix: "%"
                from: 0
                to: 100
                value: 8
                size: "lg"
                icon: "volume_up"
                stopFilled: true
            }

            VitrailSlider {
                id: wheelSlider

                Layout.preferredWidth: 320
                label: "mouse wheel · 5% a notch, the handle pulses"
                suffix: "%"
                from: 0
                to: 100
                value: 35
                size: "md"
                icon: "volume_up"
                wheelStep: 5
                onMoved: function (value) { wheelSlider.value = value }
            }

            VitrailSlider {
                id: focusSlider

                Layout.preferredWidth: 320
                label: "keyboard focus · thicker accent handle"
                suffix: "%"
                from: 0
                to: 100
                value: 45
                size: "md"
                // The field below focuses itself on load; ask once more after.
                Component.onCompleted: Qt.callLater(focusSlider.requestFocus)
            }

            VitrailSlider {
                Layout.preferredWidth: 320
                label: "read-only"
                suffix: "%"
                from: 0
                to: 100
                value: 62
                readOnly: true
                segments: [
                    { to: 0.8, color: VitrailTokens.color("primary") },
                    { to: 1, color: VitrailTokens.color("error") }
                ]
            }

            VitrailSlider {
                Layout.preferredWidth: 320
                label: "read-only · continuous, thin"
                suffix: "%"
                from: 0
                to: 100
                value: 62
                readOnly: true
                continuous: true
                size: "thin"
            }

            VitrailSlider {
                Layout.preferredWidth: 320
                label: "fillOpacity 0.35 · only the filled part is dimmed"
                suffix: "%"
                from: 0
                to: 100
                value: 62
                size: "sm"
                fillOpacity: 0.35
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailSlider · vertical, size × icon × segments"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: ["sm", "md", "lg"]

                delegate: VitrailSlider {
                    required property string modelData

                    orientation: Qt.Vertical
                    length: 140
                    from: 0
                    to: 100
                    value: 45
                    size: modelData
                    icon: "volume_up"
                }
            }

            VitrailSlider {
                orientation: Qt.Vertical
                length: 140
                from: 0
                to: 100
                value: 90
                size: "md"
                icon: "light_mode"
                segments: [
                    { to: 0.8, color: VitrailTokens.color("primary") },
                    { to: 1, color: VitrailTokens.color("error") }
                ]
            }

            VitrailSlider {
                orientation: Qt.Vertical
                length: 140
                from: 0
                to: 100
                value: 62
                size: "md"
                readOnly: true
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailMarquee · the text that does not fit slides with a gap"
        }

        VitrailMarquee {
            width: 220
            variant: "body"
            text: "A line too long to fit in its box slides like a carousel"
        }

        VitrailText {
            variant: "title"
            text: "VitrailTabs · the underline follows the choice"
        }

        VitrailTabs {
            current: "history"
            tabs: [
                { key: "history", label: "History" },
                { key: "emoji", label: "Emojis" },
                { key: "color", label: "Colours" }
            ]
        }

        VitrailText {
            variant: "title"
            text: "VitrailSegmented · label, icon + label, icon only"
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            VitrailSegmented {
                current: "dark"
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                options: [
                    { key: "light", label: "Light" },
                    { key: "dark", label: "Dark" },
                    { key: "auto", label: "Auto" }
                ]
            }

            VitrailSegmented {
                current: "dark"
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                options: [
                    { key: "light", icon: "light_mode", label: "Light" },
                    { key: "dark", icon: "dark_mode", label: "Dark" },
                    { key: "auto", icon: "contrast", label: "Auto" }
                ]
            }

            VitrailSegmented {
                current: "center"
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                options: [
                    { key: "left", icon: "align_horizontal_left" },
                    { key: "center", icon: "align_horizontal_center" },
                    { key: "right", icon: "align_horizontal_right" }
                ]
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailField · variant × text, password, icon, error, disabled"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: app.fields

                delegate: ColumnLayout {
                    id: fieldColumn

                    required property string modelData

                    Layout.alignment: Qt.AlignTop
                    spacing: VitrailTokens.gap("md")

                    VitrailText {
                        variant: "label"
                        text: fieldColumn.modelData
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Username"
                        text: "juan"
                        supportingText: "As it appears on the lock screen"
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Search"
                        placeholder: "Type to search"
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Password"
                        type: "password"
                        text: "hunter2!"
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Email"
                        leadingIcon: "mail"
                        text: "juan@example.com"
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Password"
                        type: "password"
                        text: "wrong"
                        error: true
                        errorText: "Wrong password, try again"
                    }

                    VitrailField {
                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        label: "Disabled"
                        text: "read only text"
                        enabled: false
                    }

                    VitrailField {
                        id: focusedField

                        Layout.preferredWidth: 300
                        variant: fieldColumn.modelData
                        size: "sm"
                        label: "Small, focused"
                        text: "sm"
                        Component.onCompleted: if (fieldColumn.modelData === "outline") focusedField.forceActiveFocus()
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailSelect · variant × value, icons, empty, disabled"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: app.fields

                delegate: ColumnLayout {
                    id: selectColumn

                    required property string modelData

                    Layout.alignment: Qt.AlignTop
                    spacing: VitrailTokens.gap("md")

                    VitrailText {
                        variant: "label"
                        text: selectColumn.modelData
                    }

                    VitrailSelect {
                        Layout.preferredWidth: 300
                        variant: selectColumn.modelData
                        label: "Change every"
                        current: "30"
                        options: [{ key: "1", label: "1 min" }, { key: "30", label: "30 min" }, { key: "60", label: "1 h" }]
                    }

                    VitrailSelect {
                        Layout.preferredWidth: 300
                        variant: selectColumn.modelData
                        label: "Language"
                        current: "es"
                        options: [
                            { key: "en", label: "English", icon: "translate" },
                            { key: "es", label: "Español", icon: "translate" }
                        ]
                    }

                    VitrailSelect {
                        Layout.preferredWidth: 300
                        variant: selectColumn.modelData
                        label: "Nothing chosen"
                        options: [{ key: "a", label: "Option A" }]
                    }

                    VitrailSelect {
                        Layout.preferredWidth: 300
                        variant: selectColumn.modelData
                        label: "Disabled"
                        enabled: false
                        current: "a"
                        options: [{ key: "a", label: "Option A" }]
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailPicker · preview in the field, mosaic in the dialog"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            VitrailPicker {
                Layout.preferredWidth: 320
                label: "System font"
                current: "Roboto"
                options: [
                    { key: "Roboto", label: "Roboto", family: "Roboto" },
                    { key: "DejaVu Sans", label: "DejaVu Sans", family: "DejaVu Sans" },
                    { key: "Noto Sans", label: "Noto Sans", family: "Noto Sans" }
                ]
            }

            VitrailPicker {
                Layout.preferredWidth: 320
                label: "Cursor theme"
                current: "Adwaita"
                options: [
                    { key: "Adwaita", label: "Adwaita" },
                    { key: "Bibata", label: "Bibata" }
                ]
            }

            VitrailPicker {
                Layout.preferredWidth: 320
                label: "Disabled"
                enabled: false
                current: "Adwaita"
                options: [{ key: "Adwaita", label: "Adwaita" }]
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailColorPicker · size × colour"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: [
                    { size: "sm", color: "#f44336" },
                    { size: "md", color: "#2196f3" },
                    { size: "lg", color: "#9fd8a3" }
                ]

                delegate: VitrailColorPicker {
                    required property var modelData

                    Layout.alignment: Qt.AlignTop
                    size: modelData.size
                    color: modelData.color
                    placeholder: "Hex code"
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailIcon · size × tone"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: ["sm", "md", "lg", "xl"]

                delegate: ColumnLayout {
                    id: iconSize

                    required property string modelData

                    spacing: VitrailTokens.gap("xs")

                    VitrailIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "wifi"
                        size: iconSize.modelData
                    }

                    VitrailText {
                        Layout.alignment: Qt.AlignHCenter
                        variant: "label"
                        text: iconSize.modelData
                    }
                }
            }
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: [
                    { tone: "foreground" },
                    { tone: "primary" },
                    { tone: "muted" },
                    { tone: "error" }
                ]

                delegate: VitrailIcon {
                    id: iconTone

                    required property var modelData

                    icon: "favorite"
                    size: "lg"
                    tone: iconTone.modelData.tone
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailIcon · outlined × container"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: [false, true]

                delegate: ColumnLayout {
                    id: iconStyle

                    required property var modelData

                    spacing: VitrailTokens.gap("xs")

                    RowLayout {
                        spacing: VitrailTokens.gap("sm")

                        Repeater {
                            model: ["screen_record", "lan", "shield_lock", "favorite"]

                            delegate: VitrailIcon {
                                required property string modelData

                                icon: modelData
                                size: "lg"
                                container: iconStyle.modelData
                            }
                        }
                    }

                    VitrailText {
                        Layout.alignment: Qt.AlignHCenter
                        variant: "label"
                        text: iconStyle.modelData ? "container" : "outlined"
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailBusy · plain, contained, sizes · busy buttons"
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            Repeater {
                model: [
                    { size: "title", contained: false },
                    { size: "display", contained: false },
                    { size: "title", contained: true },
                    { size: "display", contained: true }
                ]

                delegate: VitrailBusy {
                    required property var modelData

                    running: true
                    size: VitrailTokens.size(modelData.size) * 1.5
                    contained: modelData.contained
                }
            }

            VitrailButton {
                busy: true
                text: "Connect"
                variant: "tonal"
            }

            VitrailButton {
                busy: true
                icon: "download"
                variant: "flat"
            }

            VitrailButton {
                busy: true
                text: "Checking"
                variant: "outlined"
                tone: "secondary"
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailTooltip · title, title + detail, long title"
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            Repeater {
                model: [
                    { text: "Applications", detail: "Super" },
                    { text: "eno1 · Wired", detail: "192.168.1.20" },
                    { text: "ProtonVPN", detail: "us-free-26 · US" },
                    { text: "No VPN", detail: "" },
                    { text: "A very long application title that has to be elided at the maximum width", detail: "" }
                ]

                // Held in a fixed box: the pill itself appears after the hover delay.
                delegate: Item {
                    id: slot

                    required property var modelData

                    implicitWidth: tooltip.implicitWidth
                    implicitHeight: tooltip.implicitHeight

                    VitrailTooltip {
                        id: tooltip

                        active: true
                        text: slot.modelData.text
                        detail: slot.modelData.detail
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailQuality · good, fair, poor, unknown"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: [
                    { level: "good", text: "74 ms" },
                    { level: "fair", text: "180 ms" },
                    { level: "poor", text: "420 ms" },
                    { level: "unknown", text: "—" }
                ]

                delegate: VitrailQuality {
                    required property var modelData

                    level: modelData.level
                    text: modelData.text
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailKeyboard · es, en, de, fr, it, pt"
        }

        GridLayout {
            columns: 3
            columnSpacing: VitrailTokens.gap("xl")
            rowSpacing: VitrailTokens.gap("lg")

            Repeater {
                model: ["es", "en", "de", "fr", "it", "pt"]

                delegate: ColumnLayout {
                    id: keyboardColumn

                    required property string modelData

                    Layout.alignment: Qt.AlignTop
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "label"
                        text: keyboardColumn.modelData.toUpperCase()
                    }

                    VitrailKeyboard {
                        Layout.preferredWidth: 380
                        layout: keyboardColumn.modelData
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailBar · frame × bar × edge"
        }

        Repeater {
            model: app.frames.length * app.bars.length

            delegate: ColumnLayout {
                id: row

                required property int index
                readonly property string frame: app.frames[Math.floor(index / app.bars.length)]
                readonly property string bar: app.bars[index % app.bars.length]

                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    variant: "label"
                    text: "frame: " + row.frame + "   bar: " + row.bar
                }

                RowLayout {
                    spacing: VitrailTokens.gap("lg")

                    Repeater {
                        model: app.edges

                        delegate: Preview {
                            required property string modelData

                            edge: modelData
                            bar: row.bar
                            frame: row.frame
                        }
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailBar · docked cards (popup + notification stack) × bar × edge"
        }

        Repeater {
            model: app.bars

            delegate: RowLayout {
                id: cardRow

                required property string modelData

                spacing: VitrailTokens.gap("lg")

                Repeater {
                    model: app.edges

                    delegate: Preview {
                        required property string modelData

                        edge: modelData
                        bar: cardRow.modelData
                        cards: true
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailBar · popup motion × bar × progress (top edge)"
        }

        Repeater {
            model: app.bars

            delegate: RowLayout {
                id: motionRow

                required property string modelData

                spacing: VitrailTokens.gap("lg")

                Repeater {
                    model: [0.15, 0.3, 0.5, 1]

                    delegate: Preview {
                        required property real modelData

                        edge: "top"
                        bar: motionRow.modelData
                        cards: true
                        progress: modelData
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "VitrailVisualiser · the five looks · real tokens"
        }

        RowLayout {
            spacing: VitrailTokens.gap("xl")

            Repeater {
                model: Object.keys(VitrailVariants.visualiser)

                delegate: ColumnLayout {
                    id: visualiserColumn

                    required property string modelData

                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "label"
                        text: visualiserColumn.modelData
                    }

                    VitrailVisualiser {
                        Layout.preferredWidth: 560
                        Layout.preferredHeight: VitrailTokens.ranges.visualiserHeight.value * 1.4
                        variant: visualiserColumn.modelData
                        tint: wallpaper.primary
                        values: app.sampleLevels
                    }
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "Launcher · variant (made-up apps, real tokens)"
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            Repeater {
                model: Object.keys(VitrailVariants.launcher)

                delegate: LauncherPreview {
                    required property string modelData

                    Layout.alignment: Qt.AlignTop
                    variant: modelData
                    zoom: modelData === "fullscreen" ? 0.4 : 0.6
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "Launch droplet · gooey open, bursting close"
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            DropletPreview {
                phase: "open"
                Layout.alignment: Qt.AlignTop
            }

            DropletPreview {
                phase: "burst"
                Layout.alignment: Qt.AlignTop
            }
        }

        VitrailText {
            variant: "title"
            text: "VolumeButton · level × muted × percent × no audio server"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VolumeButton {
                snapshot: ({ defaultSink: { id: 1, description: "Speakers", volume: 20, muted: false } })
            }

            VolumeButton {
                snapshot: ({ defaultSink: { id: 1, description: "Speakers", volume: 80, muted: false } })
                showPercent: true
            }

            VolumeButton {
                snapshot: ({ defaultSink: { id: 1, description: "Speakers", volume: 80, muted: true } })
            }

            VolumeButton {
                opened: true
                snapshot: ({ defaultSink: { id: 1, description: "Speakers", volume: 50, muted: false } })
            }

            VolumeButton {
                snapshot: ({ error: "unreadable" })
            }
        }

        VitrailText {
            variant: "title"
            text: "VolumePanel · master × applications × devices × microphone × no audio server"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: full.implicitWidth + 2 * VitrailTokens.gap("md")
                height: full.implicitHeight + 2 * VitrailTokens.gap("md")

                VolumePanel {
                    id: full

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({
                        defaultSink: { id: 1, description: "Speakers", volume: 64, muted: false },
                        defaultSource: { id: 3, description: "Headset microphone", volume: 100, muted: true },
                        sinks: [{ id: 1, name: "speakers", description: "Speakers", volume: 64, muted: false },
                                { id: 2, name: "headset", description: "Headset", volume: 40, muted: false }],
                        sources: [{ id: 3, name: "mic", description: "Headset microphone", volume: 100, muted: true }],
                        streams: [{ id: 10, serial: 110, app: "Firefox", name: "Video", icon: "", volume: 80, muted: false, corked: false, sink: 1 },
                                  { id: 11, serial: 111, app: "Music player", name: "Song", icon: "", volume: 35, muted: true, corked: true, sink: 2 }]
                    })
                }
            }

            VitrailSurface {
                width: broken.implicitWidth + 2 * VitrailTokens.gap("md")
                height: broken.implicitHeight + 2 * VitrailTokens.gap("md")

                VolumePanel {
                    id: broken

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ error: "unreadable" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "UpdatesButton · count × zero × no sources"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            UpdatesButton {
                snapshot: ({
                    official: [{ name: "linux", from: "6.12.1", to: "6.12.2" },
                               { name: "mesa", from: "1:24.2", to: "1:24.3" },
                               { name: "python", from: "3.12.7", to: "3.12.8" }],
                    aur: [{ name: "claude-desktop", from: "5.1", to: "6.2" }],
                    flatpak: [{ name: "org.mozilla.firefox", from: "", to: "135.0" }],
                    errors: {}, total: 5, checkedAt: 1763730000000
                })
            }

            UpdatesButton {
                snapshot: ({
                    official: [{ name: "linux", from: "6.12.1", to: "6.12.2" }],
                    aur: [], flatpak: [], errors: {}, total: 1, checkedAt: 1763730000000
                })
            }

            UpdatesButton {
                snapshot: ({ official: [], aur: [], flatpak: [], errors: {}, total: 0, checkedAt: 1763730000000 })
            }

            UpdatesButton {
                snapshot: ({ error: "unreadable" })
            }
        }

        VitrailText {
            variant: "title"
            text: "UpdatesPanel · sources × a failed source × no sources"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: updatesFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: updatesFull.implicitHeight + 2 * VitrailTokens.gap("md")

                UpdatesPanel {
                    id: updatesFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({
                        official: [{ name: "linux", from: "6.12.1", to: "6.12.2" },
                                   { name: "mesa", from: "1:24.2", to: "1:24.3" }],
                        aur: [{ name: "claude-desktop", from: "5.1", to: "6.2" }],
                        flatpak: [],
                        errors: { flatpak: "flatpak is not installed" },
                        total: 3,
                        checkedAt: 1763730000000,
                        commands: { official: ["sudo", "pacman", "-Syu"], aur: ["paru", "-Sua"] }
                    })
                }
            }

            VitrailSurface {
                width: brokenUpdates.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brokenUpdates.implicitHeight + 2 * VitrailTokens.gap("md")

                UpdatesPanel {
                    id: brokenUpdates

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ error: "unreadable" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "DisksButton · one drive × two drives × unmounted × ignored × no data"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            DisksButton {
                showMode: "always"
                snapshot: ({
                    devices: [{ name: "/dev/sdb1", label: "KINGSTON", uuid: "1A2B-3C4D",
                                fstype: "vfat", size: 16 * 1024 * 1024 * 1024, model: "USB DISK 3.0",
                                transport: "usb", mounted: true, mountpoint: "/run/media/juan/KINGSTON",
                                used: 4 * 1024 * 1024 * 1024, free: 12 * 1024 * 1024 * 1024 }],
                    total: 1
                })
            }

            DisksButton {
                showMode: "always"
                snapshot: ({
                    devices: [
                        { name: "/dev/sdb1", label: "KINGSTON", uuid: "1A2B-3C4D",
                          fstype: "vfat", size: 16 * 1024 * 1024 * 1024, model: "USB DISK 3.0",
                          transport: "usb", mounted: true, mountpoint: "/run/media/juan/KINGSTON",
                          used: 4 * 1024 * 1024 * 1024, free: 12 * 1024 * 1024 * 1024 },
                        { name: "/dev/sdc1", label: "Backup", uuid: "9F8E-7D6C",
                          fstype: "ext4", size: 32 * 1024 * 1024 * 1024, model: "Portable SSD T7",
                          transport: "usb", mounted: false, mountpoint: "", used: null, free: null }
                    ],
                    total: 2
                })
            }

            DisksButton {
                showMode: "always"
                snapshot: ({
                    devices: [{ name: "/dev/sdc1", label: "Backup", uuid: "9F8E-7D6C",
                                fstype: "ext4", size: 32 * 1024 * 1024 * 1024, model: "Portable SSD T7",
                                transport: "usb", mounted: false, mountpoint: "", used: null, free: null }],
                    total: 1
                })
            }

            DisksButton {
                showMode: "always"
                snapshot: ({
                    devices: [{ name: "/dev/sdb1", label: "KINGSTON", uuid: "1A2B-3C4D" }],
                    total: 1
                })
                ignore: '["KINGSTON"]'
            }

            DisksButton {
                showMode: "always"
                snapshot: ({ error: "unreadable" })
            }
        }

        VitrailText {
            variant: "title"
            text: "DisksPanel · mounted × unmounted × a failed action × no drives × no data"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: disksFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: disksFull.implicitHeight + 2 * VitrailTokens.gap("md")

                DisksPanel {
                    id: disksFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({
                        devices: [
                            { name: "/dev/sdb1", label: "KINGSTON", uuid: "1A2B-3C4D",
                              fstype: "vfat", size: 16 * 1024 * 1024 * 1024, model: "USB DISK 3.0",
                              transport: "usb", mounted: true, mountpoint: "/run/media/juan/KINGSTON",
                              used: 4 * 1024 * 1024 * 1024, free: 12 * 1024 * 1024 * 1024 },
                            { name: "/dev/sdc1", label: "Backup", uuid: "9F8E-7D6C",
                              fstype: "ext4", size: 32 * 1024 * 1024 * 1024, model: "Portable SSD T7",
                              transport: "usb", mounted: false, mountpoint: "", used: null, free: null }
                        ],
                        total: 2
                    })
                    error: "Error: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorized"
                }
            }

            VitrailSurface {
                width: disksEmpty.implicitWidth + 2 * VitrailTokens.gap("md")
                height: disksEmpty.implicitHeight + 2 * VitrailTokens.gap("md")

                DisksPanel {
                    id: disksEmpty

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ devices: [], total: 0 })
                }
            }

            VitrailSurface {
                width: brokenDisks.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brokenDisks.implicitHeight + 2 * VitrailTokens.gap("md")

                DisksPanel {
                    id: brokenDisks

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ error: "unreadable" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "ContainersButton · running × stopped × no engine"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            ContainersButton {
                showMode: "always"
                snapshot: ({
                    engine: "docker", running: 2, error: null,
                    containers: [
                        { id: "a1", name: "web", image: "nginx:latest", state: "running",
                          status: "Up 2 hours (healthy)", health: "healthy",
                          ports: "0.0.0.0:8080->80/tcp" },
                        { id: "b2", name: "db", image: "postgres:16", state: "running",
                          status: "Up 3 hours", health: "", ports: "" }
                    ]
                })
            }

            ContainersButton {
                showMode: "always"
                snapshot: ({
                    engine: "podman", running: 0, error: null,
                    containers: [
                        { id: "p1", name: "worker", image: "example/worker:1", state: "exited",
                          status: "Exited (0) 1 hour ago", health: "", ports: "" }
                    ]
                })
            }

            ContainersButton {
                showMode: "always"
                snapshot: ({ engine: null, running: 0, containers: [], error: null })
            }
        }

        VitrailText {
            variant: "title"
            text: "ContainersPanel · running and stopped × no engine × an engine error"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: containersFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: containersFull.implicitHeight + 2 * VitrailTokens.gap("md")

                ContainersPanel {
                    id: containersFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    pinned: '["db"]'
                    snapshot: ({
                        engine: "docker", running: 1, error: null,
                        containers: [
                            { id: "a1", name: "web", image: "nginx:latest", state: "running",
                              status: "Up 2 hours (healthy)", health: "healthy",
                              ports: "0.0.0.0:8080->80/tcp, :::8080->80/tcp" },
                            { id: "b2", name: "db", image: "docker.io/library/postgres:16",
                              state: "exited", status: "Exited (0) 1 hour ago", health: "",
                              ports: "" }
                        ]
                    })
                }
            }

            VitrailSurface {
                width: containersNoEngine.implicitWidth + 2 * VitrailTokens.gap("md")
                height: containersNoEngine.implicitHeight + 2 * VitrailTokens.gap("md")

                ContainersPanel {
                    id: containersNoEngine

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ engine: null, running: 0, containers: [], error: null })
                }
            }

            VitrailSurface {
                width: containersBroken.implicitWidth + 2 * VitrailTokens.gap("md")
                height: containersBroken.implicitHeight + 2 * VitrailTokens.gap("md")

                ContainersPanel {
                    id: containersBroken

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ engine: "docker", running: 0, containers: [], error: "docker ps failed" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "BrightnessButton · level × primary × no displays"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            BrightnessButton {
                snapshot: ({ status: "ok", devices: [
                    { name: "eDP-1", kind: "backlight", device: "intel_backlight", percent: 60, max: 10000 },
                    { name: "DP-1", kind: "ddc", bus: 6, percent: 40, max: 100 }
                ] })
                primary: "DP-1"
            }

            BrightnessButton {
                snapshot: ({ status: "ok", devices: [
                    { name: "DP-1", kind: "ddc", bus: 6, percent: 90, max: 100 }
                ] })
                primary: "DP-1"
            }

            BrightnessButton {
                opened: true
                snapshot: ({ status: "ok", devices: [
                    { name: "DP-1", kind: "ddc", bus: 6, percent: 40, max: 100 }
                ] })
                primary: "DP-1"
            }

            BrightnessButton {
                snapshot: ({ status: "access", devices: [] })
            }
        }

        VitrailText {
            variant: "title"
            text: "BrightnessPanel · monitors × a missing DDC display × night light × sun schedule"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: brightnessFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brightnessFull.implicitHeight + 2 * VitrailTokens.gap("md")

                BrightnessPanel {
                    id: brightnessFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    screens: ["eDP-1", "DP-1", "HDMI-A-1"]
                    snapshot: ({
                        status: "ok",
                        devices: [
                            { name: "eDP-1", kind: "backlight", device: "intel_backlight", percent: 60, max: 10000 },
                            { name: "DP-1", kind: "ddc", bus: 6, percent: 40, max: 100 }
                        ]
                    })
                    nightlight: ({
                        enabled: true,
                        temperature: 4000,
                        schedule: { mode: "fixed", start: "20:00", end: "07:00", sunrise: "06:30", sunset: "19:45" },
                        effective: { temperature: 4000, active: true },
                        next: { at: "07:00", temperature: 6500, active: false },
                        error: null
                    })
                    schedule: ({ mode: "fixed", start: "20:00", end: "07:00" })
                    temperature: 4000
                    nightLightOn: true
                }
            }

            VitrailSurface {
                width: brightnessSun.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brightnessSun.implicitHeight + 2 * VitrailTokens.gap("md")

                BrightnessPanel {
                    id: brightnessSun

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    screens: ["DP-1"]
                    snapshot: ({ status: "ok", devices: [{ name: "DP-1", kind: "ddc", bus: 6, percent: 70, max: 100 }] })
                    nightlight: ({
                        enabled: true,
                        temperature: 3500,
                        schedule: { mode: "sun", start: "20:00", end: "07:00", sunrise: "06:30", sunset: "19:45" },
                        effective: { temperature: 3500, active: true },
                        next: { at: "19:45", temperature: 3500, active: true },
                        error: null
                    })
                    schedule: ({ mode: "sun", start: "20:00", end: "07:00" })
                    temperature: 3500
                    nightLightOn: true
                }
            }

            VitrailSurface {
                width: brokenBrightness.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brokenBrightness.implicitHeight + 2 * VitrailTokens.gap("md")

                BrightnessPanel {
                    id: brokenBrightness

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    screens: ["eDP-1", "DP-1"]
                    snapshot: ({ error: "unreadable" })
                    nightlight: ({ enabled: false, temperature: 4000,
                                   schedule: { mode: "off", start: "20:00", end: "07:00" },
                                   effective: { temperature: 6500, active: false }, next: null,
                                   error: "hyprsunset is not installed (package hyprsunset)" })
                    schedule: ({ mode: "off", start: "20:00", end: "07:00" })
                    temperature: 4000
                }
            }
        }


        VitrailText {
            variant: "title"
            text: "HealthButton · clean × one warning × two problems × an error"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            HealthButton {
                showMode: "always"
                snapshot: ({ problems: [], count: 0, checkedAt: "2026-11-22T10:00:00Z", error: null })
            }

            HealthButton {
                snapshot: ({ problems: [
                    { id: "disk:/", severity: "warning", title: "Low disk space on /",
                      detail: "3.1% free (12.0 GB of 400.0 GB)", fix: null, logs: null }
                ], count: 1, checkedAt: "2026-11-22T10:00:00Z", error: null })
            }

            HealthButton {
                snapshot: ({ problems: [
                    { id: "service-user:vitrail-settings.service", severity: "warning",
                      title: "vitrail-settings.service", detail: "user service failed: Vitrail settings",
                      fix: ["systemctl", "--user", "restart", "vitrail-settings.service"], logs: null },
                    { id: "hyprland:config", severity: "warning", title: "Hyprland config errors",
                      detail: "line 12: unknown keyword", fix: ["hyprctl", "reload"], logs: null }
                ], count: 2, checkedAt: "2026-11-22T10:00:00Z", error: null })
            }

            HealthButton {
                opened: true
                snapshot: ({ problems: [
                    { id: "service-system:docker.service", severity: "error", title: "docker.service",
                      detail: "system service failed", fix: null, logs: null }
                ], count: 1, checkedAt: "2026-11-22T10:00:00Z", error: null })
                failed: ["volume"]
            }
        }

        VitrailText {
            variant: "title"
            text: "HealthPanel · problems with Fix and Logs × the bar's own failure × a clean machine"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: healthFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: healthFull.implicitHeight + 2 * VitrailTokens.gap("md")

                HealthPanel {
                    id: healthFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ problems: [
                        { id: "service-user:vitrail-settings.service", severity: "warning",
                          title: "vitrail-settings.service", detail: "user service failed: Vitrail settings",
                          fix: ["systemctl", "--user", "restart", "vitrail-settings.service"],
                          logs: ["journalctl", "--user", "-u", "vitrail-settings.service", "-n", "200"] },
                        { id: "disk:/", severity: "warning", title: "Low disk space on /",
                          detail: "3.1% free (12.0 GB of 400.0 GB)", fix: null, logs: null },
                        { id: "hyprland:config", severity: "warning", title: "Hyprland config errors",
                          detail: "line 12: unknown keyword", fix: ["hyprctl", "reload"],
                          logs: ["hyprctl", "configerrors"] }
                    ], count: 3, checkedAt: "2026-11-22T10:00:00Z", error: null })
                    failed: ["volume", "updates"]
                }
            }

            VitrailSurface {
                width: healthClean.implicitWidth + 2 * VitrailTokens.gap("md")
                height: healthClean.implicitHeight + 2 * VitrailTokens.gap("md")

                HealthPanel {
                    id: healthClean

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ problems: [], count: 0, checkedAt: "2026-11-22T10:00:00Z", error: null })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "PrivacyButton · idle (always) × microphone × camera and screen × a tone × unreadable"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            PrivacyButton {
                showMode: "always"
                snapshot: ({ uses: [], anyUse: false, watching: { microphone: true, camera: true, screen: true }, error: null })
            }

            PrivacyButton {
                snapshot: ({ uses: [
                    { kind: "microphone", app: "Firefox", label: "Firefox input", node: 61, since: null }
                ], anyUse: true, watching: { microphone: true, camera: true, screen: true }, error: null })
            }

            PrivacyButton {
                dotColor: "primary"
                snapshot: ({ uses: [
                    { kind: "camera", app: "Zoom", label: "v4l2_input", node: 70, since: null },
                    { kind: "screen", app: "OBS", label: "obs-screen", node: 71, since: null }
                ], anyUse: true, watching: { microphone: true, camera: true, screen: true }, error: null })
            }

            PrivacyButton {
                dotColor: "info"
                opened: true
                snapshot: ({ uses: [
                    { kind: "microphone", app: "Discord", label: "WEBRTC VoiceEngine", node: 72, since: null }
                ], anyUse: true, watching: { microphone: true, camera: true, screen: true }, error: null })
            }

            PrivacyButton {
                showMode: "always"
                snapshot: ({ uses: [], anyUse: false, watching: {}, error: "pw-dump is not available or did not answer" })
            }
        }

        VitrailText {
            variant: "title"
            text: "PrivacyPanel · microphone, camera and screen × only the microphone × nothing in use × no PipeWire"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: privacyFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: privacyFull.implicitHeight + 2 * VitrailTokens.gap("md")

                PrivacyPanel {
                    id: privacyFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ uses: [
                        { kind: "microphone", app: "Firefox", label: "Firefox input", node: 61, since: null },
                        { kind: "microphone", app: "Discord", label: "WEBRTC VoiceEngine", node: 62, since: null },
                        { kind: "camera", app: "Zoom", label: "v4l2_input.usb-cam", node: 70, since: null },
                        { kind: "screen", app: "OBS", label: "obs-screen", node: 71, since: null }
                    ], anyUse: true, watching: { microphone: true, camera: true, screen: true }, error: null })
                }
            }

            VitrailSurface {
                width: privacyMic.implicitWidth + 2 * VitrailTokens.gap("md")
                height: privacyMic.implicitHeight + 2 * VitrailTokens.gap("md")

                PrivacyPanel {
                    id: privacyMic

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    busy: true
                    snapshot: ({ uses: [
                        { kind: "microphone", app: "Firefox", label: "Firefox input", node: 61, since: null }
                    ], anyUse: true, watching: { microphone: true, camera: true, screen: true }, error: null })
                }
            }

            VitrailSurface {
                width: privacyIdle.implicitWidth + 2 * VitrailTokens.gap("md")
                height: privacyIdle.implicitHeight + 2 * VitrailTokens.gap("md")

                PrivacyPanel {
                    id: privacyIdle

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ uses: [], anyUse: false, watching: { microphone: true, camera: true, screen: true }, error: null })
                }
            }

            VitrailSurface {
                width: privacyError.implicitWidth + 2 * VitrailTokens.gap("md")
                height: privacyError.implicitHeight + 2 * VitrailTokens.gap("md")

                PrivacyPanel {
                    id: privacyError

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ uses: [], anyUse: false, watching: {}, error: "pw-dump is not available or did not answer" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "WeatherButton · clear × partly cloudy × rain × snow × storm × offline"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            WeatherButton {
                snapshot: ({
                    location: { name: "Madrid", country: "Spain" },
                    units: { temperature: "°C", humidity: "%", wind: "km/h" },
                    current: { temperature: 18.4, humidity: 62, wind: 11.2, code: 2, condition: "Partly cloudy" },
                    daily: [
                        { date: "2026-11-04", high: 21.0, low: 10.0, code: 2, condition: "Partly cloudy" },
                        { date: "2026-11-05", high: 20.5, low: 9.5, code: 61, condition: "Light rain" }
                    ]
                })
            }

            WeatherButton {
                snapshot: ({
                    location: { name: "Valencia", country: "Spain" },
                    units: { temperature: "°C" },
                    current: { temperature: 24.0, code: 0, condition: "Clear sky" },
                    daily: [{ date: "2026-11-04", high: 27.0, low: 15.0, code: 0, condition: "Clear sky" }]
                })
            }

            WeatherButton {
                snapshot: ({
                    location: { name: "Bilbao", country: "Spain" },
                    units: { temperature: "°C" },
                    current: { temperature: 13.0, code: 61, condition: "Light rain" },
                    daily: [{ date: "2026-11-04", high: 15.0, low: 8.0, code: 61, condition: "Light rain" }]
                })
            }

            WeatherButton {
                snapshot: ({
                    location: { name: "Oslo", country: "Norway" },
                    units: { temperature: "°C" },
                    current: { temperature: -4.0, code: 71, condition: "Light snow" },
                    daily: [{ date: "2026-11-04", high: -1.0, low: -8.0, code: 71, condition: "Light snow" }]
                })
            }

            WeatherButton {
                snapshot: ({
                    location: { name: "Seville", country: "Spain" },
                    units: { temperature: "°C" },
                    current: { temperature: 31.0, code: 95, condition: "Thunderstorm" },
                    daily: [{ date: "2026-11-04", high: 34.0, low: 22.0, code: 95, condition: "Thunderstorm" }]
                })
            }

            WeatherButton {
                showMode: "always"
                snapshot: ({ error: "offline" })
            }
        }

        VitrailText {
            variant: "title"
            text: "WeatherPanel · warm cache × city switcher × offline with no cache"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: weatherFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: weatherFull.implicitHeight + 2 * VitrailTokens.gap("md")

                WeatherPanel {
                    id: weatherFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    cities: '["Madrid","Valencia","Bilbao"]'
                    currentCity: "Madrid"
                    snapshot: ({
                        location: { name: "Madrid", country: "Spain" },
                        units: { temperature: "°C", humidity: "%", wind: "km/h" },
                        current: { temperature: 18.4, humidity: 62, wind: 11.2, code: 2, condition: "Partly cloudy" },
                        hourly: [
                            { time: "2026-11-04T15:00", temperature: 18.4, code: 2 },
                            { time: "2026-11-04T16:00", temperature: 18.9, code: 3 },
                            { time: "2026-11-04T17:00", temperature: 18.1, code: 61 },
                            { time: "2026-11-04T18:00", temperature: 17.2, code: 61 },
                            { time: "2026-11-04T19:00", temperature: 16.4, code: 80 },
                            { time: "2026-11-04T20:00", temperature: 15.7, code: 1 }
                        ],
                        daily: [
                            { date: "2026-11-04", high: 21.0, low: 10.0, code: 2, condition: "Partly cloudy" },
                            { date: "2026-11-05", high: 20.5, low: 9.5, code: 3, condition: "Overcast" },
                            { date: "2026-11-06", high: 19.0, low: 9.0, code: 61, condition: "Light rain" },
                            { date: "2026-11-07", high: 18.0, low: 8.0, code: 61, condition: "Light rain" },
                            { date: "2026-11-08", high: 17.5, low: 7.5, code: 80, condition: "Light showers" },
                            { date: "2026-11-09", high: 16.0, low: 6.0, code: 0, condition: "Clear sky" }
                        ],
                        updated: 1763730000,
                        cached: true,
                        error: "offline"
                    })
                }
            }

            VitrailSurface {
                width: weatherEmpty.implicitWidth + 2 * VitrailTokens.gap("md")
                height: weatherEmpty.implicitHeight + 2 * VitrailTokens.gap("md")

                WeatherPanel {
                    id: weatherEmpty

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    cities: '["Madrid"]'
                    currentCity: ""
                    snapshot: ({ error: "offline" })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "PeripheralsButton · three devices × a hidden kind × low × no data"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            BatteryPeripheralsButton {
                showMode: "always"
                snapshot: ({
                    devices: [
                        { path: "mouse_0", name: "Logitech G305", kind: "mouse", percentage: 55,
                          state: "discharging", timeToEmpty: 270, model: "Logitech G305", serial: "46-f4-18-ad" },
                        { path: "headset_1", name: "WH-1000XM4", kind: "headphones", percentage: 30,
                          state: "charging", timeToEmpty: null, model: "WH-1000XM4", serial: "AC:80:0A:12:34:56" },
                        { path: "gamepad_2", name: "Xbox Wireless Controller", kind: "gamepad", percentage: 80,
                          state: "discharging", timeToEmpty: 720, model: "Xbox Wireless Controller", serial: "E4:17:D8:AA:BB:CC" }
                    ],
                    lowest: { name: "Logitech G305", percentage: 55 },
                    error: null
                })
            }

            BatteryPeripheralsButton {
                showMode: "always"
                hide: '["mouse"]'
                snapshot: ({
                    devices: [
                        { path: "mouse_0", name: "Logitech G305", kind: "mouse", percentage: 55,
                          state: "discharging", timeToEmpty: 270, model: "Logitech G305", serial: "46-f4-18-ad" },
                        { path: "headset_1", name: "WH-1000XM4", kind: "headphones", percentage: 30,
                          state: "charging", timeToEmpty: null, model: "WH-1000XM4", serial: "AC:80:0A:12:34:56" },
                        { path: "gamepad_2", name: "Xbox Wireless Controller", kind: "gamepad", percentage: 80,
                          state: "discharging", timeToEmpty: 720, model: "Xbox Wireless Controller", serial: "E4:17:D8:AA:BB:CC" }
                    ],
                    lowest: { name: "Logitech G305", percentage: 55 },
                    error: null
                })
            }

            BatteryPeripheralsButton {
                showMode: "always"
                low: 20
                snapshot: ({
                    devices: [{ path: "mouse_0", name: "Logitech G305", kind: "mouse", percentage: 12,
                                state: "discharging", timeToEmpty: 45, model: "Logitech G305", serial: "46-f4-18-ad" }],
                    lowest: { name: "Logitech G305", percentage: 12 },
                    error: null
                })
            }

            BatteryPeripheralsButton {
                showMode: "always"
                snapshot: ({ devices: [], lowest: null, error: null })
            }
        }

        VitrailText {
            variant: "title"
            text: "PeripheralsPanel · three devices, one charging × no device × no data"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: peripheralsFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: peripheralsFull.implicitHeight + 2 * VitrailTokens.gap("md")

                PeripheralsPanel {
                    id: peripheralsFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({
                        devices: [
                            { path: "mouse_0", name: "Logitech G305", kind: "mouse", percentage: 55,
                              state: "discharging", timeToEmpty: 270, model: "Logitech G305", serial: "46-f4-18-ad" },
                            { path: "headset_1", name: "WH-1000XM4", kind: "headphones", percentage: 30,
                              state: "charging", timeToEmpty: null, model: "WH-1000XM4", serial: "AC:80:0A:12:34:56" },
                            { path: "gamepad_2", name: "Xbox Wireless Controller", kind: "gamepad", percentage: 80,
                              state: "discharging", timeToEmpty: 720, model: "Xbox Wireless Controller", serial: "E4:17:D8:AA:BB:CC" }
                        ],
                        lowest: { name: "Logitech G305", percentage: 55 },
                        error: null
                    })
                }
            }

            VitrailSurface {
                width: peripheralsEmpty.implicitWidth + 2 * VitrailTokens.gap("md")
                height: peripheralsEmpty.implicitHeight + 2 * VitrailTokens.gap("md")

                PeripheralsPanel {
                    id: peripheralsEmpty

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ devices: [], lowest: null, error: null })
                }
            }

            VitrailSurface {
                width: brokenPeripherals.implicitWidth + 2 * VitrailTokens.gap("md")
                height: brokenPeripherals.implicitHeight + 2 * VitrailTokens.gap("md")

                PeripheralsPanel {
                    id: brokenPeripherals

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ error: "unreadable" })
                }
            }
        }
    }

    // One scaled-down screen: wallpaper, frame and bar.
    component Preview: Item {
        id: tile

        property string edge: "left"
        property string bar: ""
        property string frame: ""
        property string fit: ""
        // An open bar popup and a notification stack; docked bars grow
        // them out of the frame.
        property bool cards: false
        // Where the liquid motion of the popup is, 0 closed .. 1 open.
        property real progress: 1
        readonly property var look: VitrailTokens.glass ? Frame.liquid(tile.progress, VitrailTokens.motion.liquid)
                                                        : Frame.smooth(tile.progress, VitrailTokens.motion.smooth)
        // The popup at rest: docked, flush with the frame; floating, a gap past the bar.
        readonly property rect restRect: {
            var h = screen.layout.dock, r = screen.layout.reserve
            var g = VitrailTokens.gap("md")
            var o = screen.style.docked ? h : { left: r.left + g, top: r.top + g, right: r.right + g, bottom: r.bottom + g }
            var w = tile.card.width, ht = tile.card.height
            var midX = (app.screenSize.width - w) / 2, midY = (app.screenSize.height - ht) / 2
            switch (screen.layout.edge) {
            case "right": return Qt.rect(app.screenSize.width - o.right - w, midY, w, ht)
            case "top": return Qt.rect(midX, o.top, w, ht)
            case "bottom": return Qt.rect(midX, app.screenSize.height - o.bottom - ht, w, ht)
            default: return Qt.rect(o.left, midY, w, ht)
            }
        }
        readonly property rect button: Qt.rect(app.screenSize.width / 2 - 15, app.screenSize.height / 2 - 15, 30, 30)
        readonly property size card: Qt.size(320, 180)
        readonly property var stack: Frame.stackRect(tile.edge === "top" ? "bottom-right" : "top-right",
                                                     app.screenSize.width, app.screenSize.height,
                                                     tile.card.width, tile.card.height, screen.layout,
                                                     screen.style.docked, VitrailTokens.gap("md"))

        implicitWidth: app.screenSize.width * app.scale
        implicitHeight: app.screenSize.height * app.scale
        clip: true

        // Stand-in for the wallpaper when --wallpaper is not given.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: wallpaper.primary }
                GradientStop { position: 1; color: wallpaper.surface }
            }
        }

        VitrailWallpaper {
            width: app.screenSize.width
            height: app.screenSize.height
            scale: app.scale
            transformOrigin: Item.TopLeft
            visible: app.wallpaperFile !== ""
            variant: tile.fit
            source: app.wallpaperFile
            hole: screen.layout.hole
            radius: screen.layout.radius
        }

        VitrailBar {
            id: screen

            width: app.screenSize.width
            height: app.screenSize.height
            scale: app.scale
            transformOrigin: Item.TopLeft
            edge: tile.edge
            variant: tile.bar
            frameVariant: tile.frame
            popupLook: tile.cards && screen.style.docked ? tile.look : null
            popupOrigin: tile.button
            popup: tile.restRect
            tabs: tile.cards && screen.style.docked
                  ? [{ edge: tile.stack.edge, reveal: 1, swell: 1,
                       rect: Qt.rect(tile.stack.x, tile.stack.y, tile.card.width, tile.card.height) }]
                  : []

            start: [
                VitrailText { text: "●" },
                VitrailText { text: "●" },
                VitrailText { text: "●" }
            ]
            center: VitrailText { variant: "label"; text: tile.edge }
            end: [
                VitrailText { text: "◆" },
                VitrailText { text: "◆" }
            ]
        }

        VitrailText {
            variant: "title"
            text: "DownloadsButton · a known total × two unknown totals × idle × unreadable"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            DownloadsButton {
                snapshot: ({
                    active: [{
                        id: "a1", name: "big.iso", path: "/home/u/Downloads/big.iso.part",
                        final: "/home/u/Downloads/big.iso", folder: "/home/u/Downloads",
                        size: 4000000, total: 10000000, percent: 40, speed: 1250000,
                        elapsed: 6, app: "Firefox", state: "live", finalExists: false
                    }],
                    recent: [], updated: 1763730000
                })
            }

            DownloadsButton {
                showMode: "always"
                snapshot: ({
                    active: [
                        { id: "b1", name: "photo.jpg", path: "/home/u/Downloads/photo.jpg.part",
                          final: "/home/u/Downloads/photo.jpg", folder: "/home/u/Downloads",
                          size: 900000, total: null, percent: null, speed: 220000,
                          elapsed: 12, app: "Firefox", state: "live", finalExists: false },
                        { id: "b2", name: "video.mkv", path: "/home/u/Downloads/video.mkv.crdownload",
                          final: "/home/u/Downloads/video.mkv", folder: "/home/u/Downloads",
                          size: 12000000, total: null, percent: null, speed: 480000,
                          elapsed: 41, app: "Chromium", state: "live", finalExists: false }
                    ],
                    recent: [], updated: 1763730000
                })
            }

            DownloadsButton {
                showMode: "always"
                snapshot: ({ active: [], recent: [], updated: 1763730000 })
            }

            DownloadsButton {
                showMode: "always"
                snapshot: ({ error: "unreadable" })
            }
        }

        VitrailText {
            variant: "title"
            text: "DownloadsPanel · running (known and measuring) × recent × nothing"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            VitrailSurface {
                width: downloadsFull.implicitWidth + 2 * VitrailTokens.gap("md")
                height: downloadsFull.implicitHeight + 2 * VitrailTokens.gap("md")

                DownloadsPanel {
                    id: downloadsFull

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({
                        active: [
                            { id: "a1", name: "big.iso", path: "/home/u/Downloads/big.iso.part",
                              final: "/home/u/Downloads/big.iso", folder: "/home/u/Downloads",
                              size: 4000000, total: 10000000, percent: 40, speed: 1250000,
                              elapsed: 6, app: "Firefox", state: "live", finalExists: false },
                            { id: "a2", name: "photo.jpg", path: "/home/u/Downloads/photo.jpg.part",
                              final: "/home/u/Downloads/photo.jpg", folder: "/home/u/Downloads",
                              size: 900000, total: null, percent: null, speed: 220000,
                              elapsed: 12, app: "Firefox", state: "live", finalExists: false }
                        ],
                        recent: [
                            { id: "r1", name: "notes.pdf", path: "/home/u/Downloads/notes.pdf",
                              folder: "/home/u/Downloads", size: 145000, app: "Firefox",
                              finishedAt: 1763729000, state: "done" },
                            { id: "r2", name: "wallpaper.png", path: "/home/u/Downloads/wallpaper.png",
                              folder: "/home/u/Downloads", size: 6800000, app: "Chromium",
                              finishedAt: 1763728000, state: "done" }
                        ],
                        updated: 1763730000
                    })
                }
            }

            VitrailSurface {
                width: downloadsEmpty.implicitWidth + 2 * VitrailTokens.gap("md")
                height: downloadsEmpty.implicitHeight + 2 * VitrailTokens.gap("md")

                DownloadsPanel {
                    id: downloadsEmpty

                    x: VitrailTokens.gap("md")
                    y: VitrailTokens.gap("md")
                    snapshot: ({ active: [], recent: [], updated: 1763730000 })
                }
            }
        }

        VitrailText {
            variant: "title"
            text: "BarElementBase · showMode × opened × face"
        }

        Row {
            spacing: VitrailTokens.gap("lg")

            BarElementBase {
                tooltip: "Normal"
                showMode: "always"
                icon: "widgets"
            }

            BarElementBase {
                tooltip: "Opened"
                opened: true
                icon: "widgets"
            }

            BarElementBase {
                tooltip: "Active-only (shown)"
                showMode: "active"
                active: true
                icon: "widgets"
            }

            BarElementBase {
                tooltip: "Active-only (hidden)"
                showMode: "active"
                active: false
                icon: "widgets"
            }

            BarElementBase {
                tooltip: "Icon and label"
                icon: "widgets"
                text: "42%"
                tone: "primary"
            }

            BarElementBase {
                tooltip: "Custom face"
                content: Component {
                    Rectangle {
                        implicitWidth: VitrailTokens.size("body")
                        implicitHeight: VitrailTokens.size("body")
                        radius: width / 2
                        color: VitrailTokens.color("error")
                    }
                }
            }
        }

        // A floating bar leaves its popup to an island that grows out of it.
        VitrailLiquidSkin {
            width: app.screenSize.width
            height: app.screenSize.height
            scale: app.scale
            transformOrigin: Item.TopLeft
            visible: tile.cards && !screen.style.docked
            edge: screen.layout.edge
            rect: tile.restRect
            origin: tile.button
            source: screen.islands ? Frame.nearestRect(screen.islandRects, app.screenSize.width / 2, app.screenSize.height / 2)
                                   : Qt.rect(screen.area.x, screen.area.y, screen.area.width, screen.area.height)
            look: tile.look
            gap: VitrailTokens.gap("md")
            opacityLevel: VitrailTokens.opacity
        }
    }
}
