import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../fontsview.js" as FontsView

// Fonts category: one page for the whole session's type, the shell's icons,
// the apps' icon pack and the pointer. Each choice opens a mosaic of what the
// machine has (`vitrail.fonts state`: the lists and one preview per pack), and
// the apply script writes the choice to fontconfig, GTK, qt6ct, kitty, the
// Hyprland cursor and environment.d.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property var fonts: ({ fonts: [], monospace: [], iconThemes: [], cursorThemes: [],
                           cursorDesigns: [], iconPreviews: {}, cursorPreviews: {} })
    property string tab: "text"

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    // The installed list as picker rows; `kind` adds the preview the mosaic
    // and the trigger draw (a family's own letters, a pack's icons, a cursor).
    // Only packs with a real preview are offered: a cursor-only theme that
    // declares itself an icon theme would be a blank cell.
    function iconOptions(names, current) {
        var withPreview = (names || []).filter(function (name) {
            return ((page.fonts.iconPreviews || {})[name] || []).length > 0
        })
        return page.options(withPreview, current, "icons")
    }

    // A generated cursor is "Vitrail · <pack>"; an installed one keeps its
    // own name.
    function cursorLabel(name) {
        var pack = name.indexOf("vitrail-") === 0 ? name.substring(8) : ""
        if (pack === "")
            return name
        return page.t("fonts.vitrail") + " · " + pack.replace(/-/g, " ")
    }

    // The Vitrail design active now ("" when a plain theme is chosen).
    function cursorDesign() {
        var name = page.prefs.cursorTheme || ""
        return name.indexOf("vitrail-") === 0 ? name.substring(8) : ""
    }

    // The Vitrail icon layer active now ("" when a plain pack is chosen).
    function iconDesign() {
        var name = page.prefs.iconTheme || ""
        return name.indexOf("vitrail-icons-") === 0 ? name.substring(14) : ""
    }

    function iconDesignOptions(names, current) {
        var rows = [{ key: "", label: page.t("fonts.design.off"), icons: [], glyph: "block" }]
        var packs = FontsView.options(names || [], "", undefined)
        for (var i = 0; i < packs.length; i++) {
            var pack = packs[i].key
            rows.push({
                key: pack,
                label: page.t("fonts.vitrail") + " · " + pack.replace(/-/g, " "),
                icons: (page.fonts.iconPreviews || {})[pack] || []
            })
        }
        if (current && (names || []).indexOf(current) < 0)
            rows.splice(1, 0, { key: current, label: page.t("fonts.vitrail") + " · " + current,
                                icons: (page.fonts.iconPreviews || {})[current] || [] })
        return rows
    }

    function chooseIconDesign(design) {
        var name = page.prefs.iconTheme || ""
        var pack = name.indexOf("vitrail-icons-") === 0 ? name.substring(14) : name
        page.prefs.iconTheme = design === "" ? (pack || "Adwaita") : "vitrail-icons-" + design
    }

    // "Off" plus one Vitrail design per installed pack.
    function designOptions(names, current) {
        var rows = [{
            key: "",
            label: page.t("fonts.design.off"),
            icons: [],
            glyph: "block"
        }]
        var packs = FontsView.options(names || [], "", page.cursorOrder)
        for (var i = 0; i < packs.length; i++) {
            var pack = packs[i].key
            rows.push({
                key: pack,
                label: page.t("fonts.vitrail") + " · " + pack.replace(/-/g, " "),
                icons: (page.fonts.cursorPreviews || {})[pack] || []
            })
        }
        if (current && (names || []).indexOf(current) < 0)
            rows.splice(1, 0, { key: current, label: page.t("fonts.vitrail") + " · " + current,
                                icons: (page.fonts.cursorPreviews || {})[current] || [] })
        return rows
    }

    // The design picker writes the theme name: offline it is the pack itself.
    function chooseDesign(design) {
        var name = page.prefs.cursorTheme || ""
        var pack = name.indexOf("vitrail-") === 0 ? name.substring(8) : name
        page.prefs.cursorTheme = design === "" ? (pack || "Adwaita") : "vitrail-" + design
    }

    // A design sorts right after its pack: "Adwaita", "Vitrail · Adwaita".
    function cursorOrder(a, b) {
        return page.cursorSortKey(a.key).localeCompare(page.cursorSortKey(b.key))
    }

    function cursorSortKey(key) {
        return key.indexOf("vitrail-") === 0 ? key.substring(8) + " ·" : key
    }

    function options(names, current, kind) {
        var rows = FontsView.options(names || [], current || "",
                                     kind === "cursor" ? page.cursorOrder : undefined)
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (kind === "font")
                row.family = row.key
            else if (kind === "icons")
                row.icons = (page.fonts.iconPreviews || {})[row.key] || []
            else if (kind === "cursor") {
                row.icons = (page.fonts.cursorPreviews || {})[row.key] || []
                row.label = page.cursorLabel(row.key)
            }
        }
        return rows
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "text", icon: "font_download", label: page.t("fonts.tab.text") },
                { key: "icons", icon: "apps", label: page.t("fonts.tab.icons") },
                { key: "cursor", icon: "mouse", label: page.t("fonts.tab.cursor") }
            ]
            current: page.tab
            foreground: page.palette.foreground
            accent: page.palette.primary
            onSelected: page.tab = key
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

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "text"
                    icon: "font_download"
                    title: page.t("fonts.section.text")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "text_fields"
                        label: page.t("fonts.system")
                        description: page.t("fonts.system.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "systemFontPicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.system")
                            searchHint: page.t("fonts.search")
                            current: page.prefs.fontSystem
                            options: page.options(page.fonts.fonts, page.prefs.fontSystem, "font")
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.fontSystem = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "terminal"
                        label: page.t("fonts.console")
                        description: page.t("fonts.console.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "consoleFontPicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.console")
                            searchHint: page.t("fonts.search")
                            current: page.prefs.fontConsole
                            options: page.options(page.fonts.monospace, page.prefs.fontConsole, "font")
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.fontConsole = key
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("md")
                        variant: "subtitle"
                        family: page.prefs.fontSystem
                        text: page.t("fonts.preview")
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "icons"
                    icon: "apps"
                    title: page.t("fonts.section.icons")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "interests"
                        label: page.t("fonts.uiIcons")
                        description: page.t("fonts.uiIcons.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        RowLayout {
                            spacing: VitrailTokens.gap("md")

                            // The chosen family's own glyph, beside the switch.
                            VitrailText {
                                variant: "icon"
                                font.pixelSize: VitrailTokens.size("title")
                                family: VitrailTokens.font.iconFamilyOf(page.prefs.uiIcons)
                                text: "interests"
                                color: page.palette.primary
                            }

                            VitrailSegmented {
                                options: [
                                    { key: "rounded", label: page.t("fonts.uiIcons.rounded") },
                                    { key: "sharp", label: page.t("fonts.uiIcons.sharp") },
                                    { key: "outlined", label: page.t("fonts.uiIcons.outlined") }
                                ]
                                current: page.prefs.uiIcons
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onSelected: page.prefs.uiIcons = key
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "palette"
                        label: page.t("fonts.design")
                        description: page.t("fonts.iconsTint.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "iconDesignPicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.design")
                            searchHint: page.t("fonts.search")
                            triggerShown: 4
                            triggerColumns: 2
                            current: page.iconDesign()
                            options: page.iconDesignOptions(page.fonts.iconDesigns,
                                                            page.iconDesign())
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.chooseIconDesign(key)
                        }
                    }

                    VitrailSettingRow {
                        icon: "widgets"
                        label: page.t("fonts.iconTheme")
                        description: page.t("fonts.iconTheme.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "iconThemePicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.iconTheme")
                            searchHint: page.t("fonts.search")
                            current: page.prefs.iconTheme
                            options: page.iconOptions(page.fonts.iconThemes, page.prefs.iconTheme)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.iconTheme = key
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "cursor"
                    icon: "mouse"
                    title: page.t("fonts.section.cursor")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "ads_click"
                        label: page.t("fonts.cursor")
                        description: page.t("fonts.cursor.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "cursorThemePicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.cursor")
                            searchHint: page.t("fonts.search")
                            triggerShown: 1
                            triggerColumns: 1
                            current: page.prefs.cursorTheme
                            options: page.options(page.fonts.cursorThemes, page.prefs.cursorTheme,
                                                  "cursor")
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.cursorTheme = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "palette"
                        label: page.t("fonts.design")
                        description: page.t("fonts.design.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailPicker {
                            objectName: "cursorDesignPicker"
                            Layout.preferredWidth: 320
                            label: page.t("fonts.design")
                            searchHint: page.t("fonts.search")
                            triggerShown: 1
                            triggerColumns: 1
                            current: page.cursorDesign()
                            options: page.designOptions(page.fonts.cursorDesigns,
                                                        page.cursorDesign())
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.chooseDesign(key)
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("fonts.cursorSize")
                        suffix: " px"
                        from: VitrailTokens.ranges.cursor.min
                        to: VitrailTokens.ranges.cursor.max
                        stepSize: VitrailTokens.ranges.cursor.step
                        value: page.prefs.cursorSize
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.cursorSize = value
                    }
                }
            }
        }
    }
}
