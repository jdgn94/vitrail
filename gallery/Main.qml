import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../kit/composed"
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
    readonly property var panels: Object.keys(VitrailVariants.panel)
    readonly property var fits: Object.keys(VitrailVariants.wallpaper)
    readonly property var buttons: Object.keys(VitrailVariants.button)
    readonly property var fields: Object.keys(VitrailVariants.field)
    readonly property var edges: ["left", "top", "right", "bottom"]
    // Optional image or video to preview the wallpaper fits with.
    readonly property string wallpaperFile: Args.value("--wallpaper", "")
    // Each preview is a full screen scaled down, so tokens keep real sizes.
    readonly property size screenSize: Qt.size(1280, 720)
    readonly property real scale: Number(Args.value("--scale", "0.24"))

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
                label: "mouse wheel · 5% a notch"
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
            text: "VitrailIcon · size × tone × filled"
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
                    { tone: "foreground", filled: false },
                    { tone: "primary", filled: true },
                    { tone: "muted", filled: false },
                    { tone: "error", filled: true }
                ]

                delegate: VitrailIcon {
                    id: iconTone

                    required property var modelData

                    icon: "favorite"
                    size: "lg"
                    tone: iconTone.modelData.tone
                    filled: iconTone.modelData.filled
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
            text: "VitrailBar · panel × wallpaper × edge"
        }

        Repeater {
            model: app.panels.length * app.fits.length

            delegate: ColumnLayout {
                id: panelRow

                required property int index
                readonly property string panel: app.panels[Math.floor(index / app.fits.length)]
                readonly property string fit: app.fits[index % app.fits.length]

                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    variant: "label"
                    text: "panel: " + panelRow.panel + "   wallpaper: " + panelRow.fit
                }

                RowLayout {
                    spacing: VitrailTokens.gap("lg")

                    Repeater {
                        model: app.edges

                        delegate: Preview {
                            required property string modelData

                            edge: modelData
                            panel: panelRow.panel
                            fit: panelRow.fit
                        }
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
    }

    // One scaled-down screen: wallpaper, frame, bar and, optionally, a panel.
    component Preview: Item {
        id: tile

        property string edge: "left"
        property string bar: ""
        property string frame: ""
        property string panel: ""
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
            panelVariant: tile.panel
            panelOpen: tile.panel !== ""
            panelPush: tile.fit !== "screen"
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
            panelContent: VitrailText { variant: "title"; text: tile.panel }
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
