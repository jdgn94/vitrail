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
            popupOpen: tile.cards && screen.style.docked
            popup: {
                var h = screen.layout.hole
                var w = tile.card.width, ht = tile.card.height
                var midX = (app.screenSize.width - w) / 2, midY = (app.screenSize.height - ht) / 2
                switch (screen.layout.edge) {
                case "right": return Qt.rect(app.screenSize.width - h.right - w, midY, w, ht)
                case "top": return Qt.rect(midX, h.top, w, ht)
                case "bottom": return Qt.rect(midX, app.screenSize.height - h.bottom - ht, w, ht)
                default: return Qt.rect(h.left, midY, w, ht)
                }
            }
            tabs: tile.cards && screen.style.docked
                  ? [{ edge: tile.stack.edge, reveal: 1,
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
    }
}
