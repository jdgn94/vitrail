import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
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
                           cursorDesigns: [], iconDesigns: [], iconUser: [],
                           iconPreviews: {}, cursorPreviews: {} })
    property string tab: "text"
    // The import/delete feedback.
    property string iconMessage: ""
    property string iconState: "idle"
    property var iconNonce: 0
    property int iconPolls: 0
    // The cursor picker's import/delete feedback and which pref it targets.
    property string cursorMessage: ""
    property string cursorState: "idle"
    property var cursorNonce: 0
    property int cursorPolls: 0
    property string cursorTarget: "shared"
    // The state file the launcher injected, and the result beside it.
    property string fontsFile: ""

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    // The installed packs, one row each. Adaptive is a switch on the chosen
    // pack, not a second set of generated rows.
    function iconOptions(current) {
        var previews = page.fonts.iconPreviews || {}
        var rows = []
        var seen = Object.create(null)
        function add(name) {
            if (seen[name])
                return
            seen[name] = true
            var pictures = previews[name] || []
            rows.push({
                key: name,
                label: name,
                icons: pictures,
                glyph: pictures.length === 0 ? "apps" : ""
            })
        }
        ;(page.fonts.iconDesigns || []).forEach(add)
        if (current)
            add(current)
        rows.sort(function (a, b) { return a.label.localeCompare(b.label) })
        return rows
    }

    readonly property bool iconDeletable: (page.fonts.iconUser || []).indexOf(page.prefs.iconTheme) >= 0
    readonly property var iconActions: [
        { key: "import", label: page.t("fonts.iconTheme.import"), icon: "upload_file",
          variant: "tonal", tone: "secondary" },
        { key: "delete", label: page.t("fonts.iconTheme.delete"),
          confirm: page.t("fonts.iconTheme.deleteConfirm"), icon: "delete",
          variant: "outlined", tone: "error", enabled: page.iconDeletable }
    ]

    // The window cannot run commands: the request key is picked up by
    // apply-settings.sh, which runs `vitrail fonts apply`; the result and the
    // refreshed pack list are two cache files this page polls meanwhile.
    function request(paths, nonce) {
        return [nonce || Date.now()].concat(paths).join("|")
    }

    function dirname(path) {
        return String(path || "").replace(/\/[^\/]*$/, "")
    }

    function readJson(path, done) {
        if (!path) {
            done(null)
            return
        }
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            try {
                done(JSON.parse(request.responseText))
            } catch (error) {
                done(null)
            }
        }
        request.open("GET", "file://" + path + "?_=" + Date.now())
        request.send()
    }

    function beginIconRequest(nonce) {
        page.iconMessage = ""
        page.iconState = "pending"
        page.iconNonce = nonce || Date.now()
        page.iconPolls = 0
        iconPoll.start()
    }

    function finishIconRequest(result) {
        iconPoll.stop()
        page.iconState = "done"
        if (!result.ok) {
            page.iconMessage = page.t("fonts.iconTheme.failed") + " " + (result.message || "")
            return
        }
        page.iconMessage = result.action === "remove"
                          ? page.t("fonts.iconTheme.removed") : page.t("fonts.iconTheme.imported")
        if (result.action === "remove" && page.prefs.iconTheme === result.name)
            page.prefs.iconTheme = "Adwaita"
        if (result.action === "import")
            page.prefs.iconTheme = String(result.name || "")
        page.readJson(page.fontsFile, function (state) {
            if (state && state.iconThemes)
                page.fonts = state
        })
    }

    function pollIconRequest() {
        page.iconPolls += 1
        if (page.iconPolls > 20) {
            iconPoll.stop()
            page.iconMessage = page.t("fonts.iconTheme.failed")
            return
        }
        page.readJson(page.dirname(page.fontsFile) + "/icons-result.json", function (result) {
            if (!result || String(result.nonce) !== String(page.iconNonce))
                return
            page.finishIconRequest(result)
        })
    }

    function onIconAction(key) {
        if (key === "import") {
            importDialog.open()
            return
        }
        if (key === "delete" && page.iconDeletable) {
            var nonce = Date.now()
            page.prefs.iconRemove = page.request([page.prefs.iconTheme], nonce)
            page.beginIconRequest(nonce)
        }
    }

    function cursorValue(target) {
        if (target === "light")
            return page.prefs.cursorThemeLight
        if (target === "dark")
            return page.prefs.cursorThemeDark
        return page.prefs.cursorTheme
    }

    function setCursorTheme(target, name) {
        if (target === "light")
            page.prefs.cursorThemeLight = name
        else if (target === "dark")
            page.prefs.cursorThemeDark = name
        else
            page.prefs.cursorTheme = name
    }

    function onCursorAction(key, current, target) {
        page.cursorTarget = target || "shared"
        if (key === "import") {
            cursorImportDialog.open()
            return
        }
        if (key === "delete" && (page.fonts.cursorUser || []).indexOf(current) >= 0) {
            var nonce = Date.now()
            page.prefs.cursorRemove = page.request([current], nonce)
            page.beginCursorRequest(nonce)
        }
    }

    function beginCursorRequest(nonce) {
        page.cursorMessage = ""
        page.cursorState = "pending"
        page.cursorNonce = nonce || Date.now()
        page.cursorPolls = 0
        cursorPoll.start()
    }

    function pollCursorRequest() {
        page.cursorPolls += 1
        if (page.cursorPolls > 20) {
            cursorPoll.stop()
            page.cursorMessage = page.t("fonts.cursor.failed")
            return
        }
        page.readJson(page.dirname(page.fontsFile) + "/cursors-result.json", function (result) {
            if (!result || String(result.nonce) !== String(page.cursorNonce))
                return
            page.finishCursorRequest(result)
        })
    }

    function finishCursorRequest(result) {
        cursorPoll.stop()
        page.cursorState = "done"
        if (!result.ok) {
            page.cursorMessage = page.t("fonts.cursor.failed") + " " + (result.message || "")
            return
        }
        page.cursorMessage = result.action === "remove"
                          ? page.t("fonts.cursor.removed") : page.t("fonts.cursor.imported")
        if (result.action === "import") {
            page.setCursorTheme(page.cursorTarget, String(result.name || ""))
        } else if (page.cursorValue(page.cursorTarget) === result.name) {
            page.setCursorTheme(page.cursorTarget,
                                page.cursorTarget === "shared" ? "Adwaita" : "")
        }
        page.readJson(page.fontsFile, function (state) {
            if (state && state.cursorThemes)
                page.fonts = state
        })
    }

    // Cursor rows: the installed packs, one list. Adaptive is a switch on the
    // chosen pack, not a separate set of rows. The first row is the shared
    // pack, only when a split asks for a per-theme override.
    function cursorOptions(current, inherit) {
        var previews = page.fonts.cursorPreviews || {}
        var shared = page.prefs.cursorTheme || "Adwaita"
        var rows = []
        var seen = Object.create(null)
        function add(name, icons) {
            if (seen[name])
                return
            seen[name] = true
            var pictures = icons || []
            rows.push({
                key: name,
                label: name,
                icons: pictures,
                glyph: pictures.length === 0 ? "mouse" : ""
            })
        }
        if (inherit)
            rows.push({
                key: "",
                label: page.t("fonts.cursor.inherit").replace("%1", shared),
                icons: previews[shared] || [],
                glyph: (previews[shared] || []).length === 0 ? "mouse" : ""
            })
        ;(page.fonts.cursorDesigns || []).forEach(function (name) {
            add(name, previews[name])
        })
        if (current)
            add(current, previews[current])
        rows.sort(function (a, b) {
            return a.key === "" ? -1 : b.key === "" ? 1 : a.label.localeCompare(b.label)
        })
        return rows
    }

    function options(names, current) {
        var rows = FontsView.options(names || [], current || "")
        for (var i = 0; i < rows.length; i++)
            rows[i].family = rows[i].key
        return rows
    }

    // One cursor card: the icon and label, the large picker and a note saying
    // which theme uses it. The single case centres one of these; the split
    // puts two equal ones side by side.
    component CursorCard: ColumnLayout {
        id: card

        property string icon: "mouse"
        property string label: ""
        property string note: ""
        property string current: ""
        property bool inherit: false
        property string pickerName: ""
        property string target: "shared"

        signal selected(string key)

        readonly property var actions: [
            { key: "import", label: page.t("fonts.cursor.import"), icon: "upload_file",
              variant: "tonal", tone: "secondary" },
            { key: "delete", label: page.t("fonts.cursor.delete"),
              confirm: page.t("fonts.cursor.deleteConfirm"), icon: "delete",
              variant: "outlined", tone: "error",
              enabled: (page.fonts.cursorUser || []).indexOf(card.current) >= 0 }
        ]

        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            VitrailIcon {
                icon: card.icon
                color: page.palette.muted
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: card.label
                color: page.palette.foreground
            }
        }

        VitrailPicker {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 240
            objectName: card.pickerName
            large: true
            label: card.label
            searchHint: page.t("fonts.search")
            cellPreview: 120
            cellColumns: 4
            cellWidth: 176
            cellHeight: 184
            emptyText: page.t("fonts.cursor.empty")
            current: card.current
            options: page.cursorOptions(card.current, card.inherit)
            actions: card.actions
            foreground: page.palette.foreground
            accent: page.palette.primary
            panel: page.palette.surfaceHigh
            onActionTriggered: function (key) { page.onCursorAction(key, card.current, card.target) }
            onSelected: card.selected(key)
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            text: card.note
            color: page.palette.muted
            wrapMode: Text.WordWrap
        }
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
                            options: page.options(page.fonts.fonts, page.prefs.fontSystem)
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
                            options: page.options(page.fonts.monospace, page.prefs.fontConsole)
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

                            // The chosen family's own glyph, beside the choice.
                            VitrailIcon {
                                pixelSize: VitrailTokens.size("title")
                                family: VitrailTokens.font.iconFamilyOf(page.prefs.uiIcons)
                                icon: "interests"
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

                            VitrailSegmented {
                                options: [
                                    { key: "outlined", label: page.t("fonts.uiIcons.outline") },
                                    { key: "container", label: page.t("fonts.uiIcons.container") }
                                ]
                                current: page.prefs.uiIconFill
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onSelected: page.prefs.uiIconFill = key
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "palette"
                        label: page.t("fonts.iconTheme.adaptive")
                        description: page.t("fonts.iconTheme.adaptive.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "iconAdaptiveSwitch"
                            checked: page.prefs.iconAdaptive
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.iconAdaptive = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "tonality"
                        label: page.t("fonts.iconTheme.fill")
                        description: page.t("fonts.iconTheme.fill.help")
                        enabled: page.prefs.iconAdaptive
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            objectName: "iconFillSelect"
                            enabled: page.prefs.iconAdaptive
                            opacity: page.prefs.iconAdaptive ? 1 : 0.45
                            options: [
                                { key: "pack", label: page.t("fonts.iconTheme.pack") },
                                { key: "light", label: page.t("fonts.iconTheme.light") },
                                { key: "solid", label: page.t("fonts.iconTheme.solid") }
                            ]
                            current: page.prefs.iconFill
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: function (key) { page.prefs.iconFill = key }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("md")

                        RowLayout {
                            objectName: "iconPickerHeader"
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 24
                                pixelSize: VitrailTokens.size("title")
                                icon: "widgets"
                                color: page.palette.muted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("xs")

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "body"
                                    text: page.t("fonts.iconTheme")
                                    color: page.palette.foreground
                                    wrapMode: Text.WordWrap
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "content"
                                    text: page.t("fonts.iconTheme.help")
                                    color: page.palette.muted
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item { Layout.fillWidth: true }

                            VitrailPicker {
                                objectName: "iconThemePicker"
                                Layout.preferredWidth: 240
                                large: true
                                label: page.t("fonts.iconTheme")
                                searchHint: page.t("fonts.search")
                                cellPreview: 120
                                cellColumns: 4
                                cellWidth: 176
                                cellHeight: 184
                                current: page.prefs.iconTheme
                                options: page.iconOptions(page.prefs.iconTheme)
                                actions: page.iconActions
                                emptyText: page.t("fonts.iconTheme.empty")
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                panel: page.palette.surfaceHigh
                                onActionTriggered: function (key) { page.onIconAction(key) }
                                onSelected: page.prefs.iconTheme = key
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("md")
                        Layout.rightMargin: VitrailTokens.gap("md")
                        visible: page.iconMessage !== ""
                        variant: "label"
                        text: page.iconMessage
                        color: page.iconState === "done" && page.iconMessage.indexOf(
                                   page.t("fonts.iconTheme.failed")) === 0
                               ? (page.palette.error || page.palette.foreground)
                               : page.palette.muted
                        wrapMode: Text.WordWrap
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
                        icon: "contrast"
                        label: page.t("fonts.cursor.split")
                        description: page.t("fonts.cursor.split.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.cursorThemeSplit
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.cursorThemeSplit = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "palette"
                        label: page.t("fonts.cursor.adaptive")
                        description: page.t("fonts.cursor.adaptive.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "cursorAdaptiveSwitch"
                            checked: page.prefs.cursorAdaptive
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.cursorAdaptive = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "tonality"
                        label: page.t("fonts.cursor.monochrome")
                        description: page.t("fonts.cursor.monochrome.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "cursorMonochromeSwitch"
                            enabled: page.prefs.cursorAdaptive
                            opacity: page.prefs.cursorAdaptive ? 1 : 0.45
                            checked: page.prefs.cursorMonochrome
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.cursorMonochrome = value }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !page.prefs.cursorThemeSplit
                        spacing: VitrailTokens.gap("lg")

                        Item { Layout.fillWidth: true }

                        CursorCard {
                            objectName: "cursorSharedCard"
                            Layout.preferredWidth: 240
                            pickerName: "cursorThemePicker"
                            icon: "mouse"
                            label: page.t("fonts.cursor")
                            note: page.t("fonts.cursor.shared.help")
                            current: page.prefs.cursorTheme
                            inherit: false
                            target: "shared"
                            onSelected: function (key) { page.prefs.cursorTheme = key }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: page.prefs.cursorThemeSplit
                        spacing: VitrailTokens.gap("md")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 24
                                pixelSize: VitrailTokens.size("title")
                                icon: "mouse"
                                color: page.palette.muted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("xs")

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "body"
                                    text: page.t("fonts.cursor")
                                    color: page.palette.foreground
                                    wrapMode: Text.WordWrap
                                }

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "content"
                                    text: page.t("fonts.cursor.split.help")
                                    color: page.palette.muted
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("xl")

                            CursorCard {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 240
                                pickerName: "cursorLightPicker"
                                icon: "light_mode"
                                label: page.t("fonts.cursor.light")
                                note: page.t("fonts.cursor.light.note")
                                current: page.prefs.cursorThemeLight
                                inherit: true
                                target: "light"
                                onSelected: function (key) { page.prefs.cursorThemeLight = key }
                            }

                            CursorCard {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 240
                                pickerName: "cursorDarkPicker"
                                icon: "dark_mode"
                                label: page.t("fonts.cursor.dark")
                                note: page.t("fonts.cursor.dark.note")
                                current: page.prefs.cursorThemeDark
                                inherit: true
                                target: "dark"
                                onSelected: function (key) { page.prefs.cursorThemeDark = key }
                            }
                        }
                    }

                    VitrailSettingRow {
                        icon: "straighten"
                        label: page.t("fonts.cursorSize")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            objectName: "cursorSizeSelect"
                            Layout.preferredWidth: 150
                            label: page.t("fonts.cursorSize")
                            // The recommended static sizes; a value stored by an
                            // older build stays listed instead of being lost.
                            options: {
                                var sizes = [16, 20, 24, 28, 32, 40, 48]
                                var now = Number(page.prefs.cursorSize)
                                if (now > 0 && sizes.indexOf(now) < 0)
                                    sizes.push(now)
                                sizes.sort(function (a, b) { return a - b })
                                return sizes.map(function (size) {
                                    return { key: String(size), label: size + " px" }
                                })
                            }
                            current: String(page.prefs.cursorSize)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.cursorSize = Number(key)
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("md")
                        Layout.rightMargin: VitrailTokens.gap("md")
                        visible: page.cursorMessage !== ""
                        variant: "label"
                        text: page.cursorMessage
                        color: page.cursorState === "done" && page.cursorMessage.indexOf(
                                   page.t("fonts.cursor.failed")) === 0
                               ? (page.palette.error || page.palette.foreground)
                               : page.palette.muted
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Timer {
        id: iconPoll

        interval: 700
        repeat: true
        onTriggered: page.pollIconRequest()
    }

    Timer {
        id: cursorPoll

        interval: 700
        repeat: true
        onTriggered: page.pollCursorRequest()
    }

    FileDialog {
        id: importDialog

        title: page.t("fonts.iconTheme.import")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Icon packs (*.zip)"]
        onAccepted: {
            var path = decodeURIComponent(String(importDialog.selectedFile).replace(/^file:\/\//, ""))
            var nonce = Date.now()
            page.prefs.iconImport = page.request([path], nonce)
            page.beginIconRequest(nonce)
        }
    }

    FileDialog {
        id: cursorImportDialog

        title: page.t("fonts.cursor.import")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Cursor themes (*.zip)"]
        onAccepted: {
            var path = decodeURIComponent(String(cursorImportDialog.selectedFile).replace(/^file:\/\//, ""))
            var nonce = Date.now()
            page.prefs.cursorImport = page.request([path], nonce)
            page.beginCursorRequest(nonce)
        }
    }
}
