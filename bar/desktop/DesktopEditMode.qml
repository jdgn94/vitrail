import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../layouts.js" as Layouts
import "../widgets.js" as Registry
import "desktopEditor.js" as Editor

// The in-place desktop editor. The desktop itself shrinks to 85% inside this
// full-screen container while the bar and the notification panel step aside
// (bar/desktop/policy.js). The three tabs put the desktop in the middle, the
// bar and the panel beside it; this phase edits the desktop.
//
// The document is the state: every drag, resize, variant or typography change
// goes through bar/layouts.js and is emitted as `layoutChanged`, so nothing is
// applied half-way and closing does not need a "save". An empty or stale
// document is an empty desktop, exactly as the real layer reads it.
Item {
    id: root

    property bool active: false
    property string monitor: ""
    property string layoutText: ""
    property var strings: ({})
    property var fonts: []
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Which tab is up: the desktop is the default and the middle one.
    property string tab: "desktop"
    // The palette family whose variants are shown ("" = none).
    property string paletteWidget: ""
    // The placed widget being edited ("" = none).
    property string selection: ""

    signal layoutChanged(string text)
    signal finished()

    readonly property var document: Layouts.effective(root.layoutText, root.monitor, null, "desktop")
    readonly property var placed: root.document.widgets
    readonly property var selectedEntry: root.entry(root.selection)
    readonly property var paletteWidgets: ["clock", "media", "image", "notes"]
    // 0 closed, 1 open: the container's own scale lives on this number, so the
    // desktop visibly shrinks into place instead of appearing at 85%.
    property real progress: root.active ? 1 : 0

    Behavior on progress {
        NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic }
    }

    visible: root.active || root.progress > 0
    opacity: root.progress
    focus: root.active
    activeFocusOnTab: true

    Keys.onEscapePressed: root.finish()

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function meta(id) {
        return Layouts.find(id, "desktop")
    }

    function labelOf(id) {
        var widget = root.meta(id)
        return root.t(widget ? widget.labelKey : id)
    }

    function entry(id) {
        for (var i = 0; i < root.placed.length; i++) {
            if (root.placed[i].id === id)
                return root.placed[i]
        }
        return null
    }

    // Every edit is one whole document write, as the settings editor does.
    function commit(widgets) {
        var text = Layouts.write(root.layoutText, root.monitor, { widgets: widgets }, "desktop")
        if (text !== null)
            root.layoutChanged(text)
    }

    // --- the palette ---------------------------------------------------------

    function variants(id) {
        var widget = root.meta(id)
        return widget ? widget.styles : []
    }

    function variantLabel(style) {
        return root.t("panel.editor.style." + style)
    }

    function chooseWidget(id) {
        root.paletteWidget = root.paletteWidget === id ? "" : id
    }

    // The variant that was chosen is placed, or an already placed widget takes
    // the new style. The position is the centre, a little lower each time so
    // two new widgets do not sit exactly on top of each other.
    function chooseVariant(id, style) {
        var count = root.placed.length
        var widgets = Layouts.desktopAdd(root.placed, id, 0.5, 0.35 + Math.min(0.4, count * 0.07))
        widgets = Layouts.desktopConfigure(widgets, id, { style: style })
        root.selection = id
        root.paletteWidget = id
        root.commit(widgets)
    }

    // --- the canvas ----------------------------------------------------------

    function moveWidget(id, x, y, width, height, areaWidth, areaHeight) {
        var point = Editor.moveTo(x, y, width, height, areaWidth, areaHeight)
        root.commit(Layouts.desktopMove(root.placed, id, point.x, point.y))
    }

    function resizeWidget(id, width) {
        root.commit(Layouts.desktopConfigure(root.placed, id,
                                             { size: Editor.sizeForWidth(id, width) }))
    }

    function removeWidget(id) {
        root.commit(Layouts.desktopRemove(root.placed, id))
        if (root.selection === id)
            root.selection = ""
    }

    function selectWidget(id) {
        root.selection = id
    }

    // --- the inspector -------------------------------------------------------

    function sizeOptions(id) {
        var widget = root.meta(id)
        return widget ? widget.sizes.map(function (size) {
            return { key: size, label: root.t("panel.editor.size." + size) }
        }) : []
    }

    function styleOptions(id) {
        var widget = root.meta(id)
        if (!widget)
            return []
        return [{ key: "", label: root.t("panel.editor.style.default") }].concat(
            widget.styles.map(function (style) {
                return { key: style, label: root.variantLabel(style) }
            }))
    }

    function fontOptions() {
        return [{ key: "", label: root.t("desktop.editor.font.inherit") }].concat(
            (root.fonts || []).map(function (family) {
                return { key: family, label: family }
            }))
    }

    function weightOptions() {
        return ["", "regular", "medium", "bold"].map(function (weight) {
            return { key: weight,
                     label: root.t("desktop.editor.weight." + (weight === "" ? "inherit" : weight)) }
        })
    }

    function setSize(id, size) {
        root.commit(Layouts.desktopConfigure(root.placed, id, { size: size }))
    }

    function setStyle(id, style) {
        root.commit(Layouts.desktopConfigure(root.placed, id, { style: style }))
    }

    function setFont(id, font) {
        root.commit(Layouts.desktopConfigure(root.placed, id, { font: font }))
    }

    function setWeight(id, weight) {
        root.commit(Layouts.desktopConfigure(root.placed, id, { weight: weight }))
    }

    function setItalic(id, italic) {
        root.commit(Layouts.desktopConfigure(root.placed, id, { italic: italic }))
    }

    function finish() {
        root.finished()
    }

    // The tabs, in display order: the desktop is the middle one.
    readonly property var tabs: [
        { key: "bar", icon: "toolbar", label: root.t("desktop.edit.tab.bar") },
        { key: "desktop", icon: "desktop_windows", label: root.t("desktop.edit.tab.desktop") },
        { key: "panel", icon: "view_sidebar", label: root.t("desktop.edit.tab.panel") }
    ]

    VitrailSurface {
        anchors.fill: parent
        radius: 0
        tint: VitrailTokens.color("surface", "#1d2024")
        opacityLevel: VitrailTokens.opacity * 0.61
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VitrailTokens.gap("lg")
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("md")

            VitrailText {
                variant: "title"
                text: root.t("desktop.edit.title")
            }

            Item { Layout.fillWidth: true }

            VitrailTabs {
                objectName: "desktopEditTabs"

                tabs: root.tabs
                current: root.tab
                foreground: VitrailTokens.color("foreground", "#e2e2e9")
                accent: VitrailTokens.color("primary", "#a8c7fa")
                onSelected: root.tab = key
            }

            Item { Layout.fillWidth: true }

            VitrailButton {
                objectName: "desktopEditDone"

                variant: "filled"
                icon: "check"
                text: root.t("desktop.edit.done")
                onClicked: root.finish()
            }
        }

        // The desktop tab: the desktop at 85%, with the palette below it.
        Item {
            id: desktopTab

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.tab === "desktop"

            Item {
                id: stage

                anchors.fill: parent

                // The whole desktop, shrunk into the container. The animation
                // starts at 100% and settles at 85%.
                Item {
                    id: desktopFrame

                    anchors.centerIn: parent
                    width: stage.width * (0.85 + 0.15 * (1 - root.progress))
                    height: stage.height * (0.85 + 0.15 * (1 - root.progress))

                    readonly property real desktopScale: root.screenWidth > 0
                                                         ? desktopFrame.width / root.screenWidth : 0.4

                    VitrailSurface {
                        anchors.fill: parent
                        radius: VitrailTokens.radius
                        tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                        opacityLevel: VitrailTokens.opacity * 0.39
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.placed.length === 0
                        spacing: VitrailTokens.gap("xs")

                        VitrailIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: "widgets"
                            size: "xl"
                            tone: "muted"
                        }

                        VitrailText {
                            variant: "content"
                            text: root.t("desktop.editor.empty")
                        }
                    }

                    Repeater {
                        model: root.placed

                        delegate: Item {
                            id: placedCard

                            required property var modelData
                            required property int index

                            readonly property var widget: root.meta(placedCard.modelData.id)
                            readonly property bool selected: root.selection === placedCard.modelData.id
                            readonly property real naturalWidth: Registry.widthOf(placedCard.modelData.id,
                                                                                  placedCard.modelData.size)
                            readonly property real cardHeight: {
                                var height = placedCard.modelData.size === "sm" ? VitrailTokens.desktopEdit.cardSm
                                           : (placedCard.modelData.size === "lg" ? VitrailTokens.desktopEdit.cardLg
                                                                                : VitrailTokens.desktopEdit.cardMd)
                                return Math.max(36, height * desktopFrame.desktopScale)
                            }
                            property real dragWidth: -1

                            objectName: "desktopEditWidget." + placedCard.modelData.id
                            z: grab.active || resize.active ? 2 : (placedCard.selected ? 1 : 0)
                            width: placedCard.dragWidth > 0 ? placedCard.dragWidth
                                                           : Math.min(desktopFrame.width,
                                                                      placedCard.naturalWidth * desktopFrame.desktopScale)
                            height: placedCard.cardHeight

                            Binding on x {
                                when: !grab.active
                                value: Math.max(0, Math.min(desktopFrame.width - placedCard.width,
                                                            placedCard.modelData.x * desktopFrame.width))
                            }
                            Binding on y {
                                when: !grab.active
                                value: Math.max(0, Math.min(desktopFrame.height - placedCard.height,
                                                            placedCard.modelData.y * desktopFrame.height))
                            }

                            Behavior on x {
                                enabled: !grab.active
                                NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
                            }
                            Behavior on y {
                                enabled: !grab.active
                                NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
                            }

                            VitrailSurface {
                                anchors.fill: parent
                                radius: VitrailTokens.radius * 0.75
                                tint: placedCard.selected ? VitrailTokens.color("primary", "#a8c7fa")
                                                          : VitrailTokens.color("surface", "#1d2024")
                                opacityLevel: VitrailTokens.opacity * (placedCard.selected ? 0.31 : 0.83)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: VitrailTokens.gap("sm")
                                spacing: VitrailTokens.gap("xs")

                                VitrailIcon {
                                    icon: placedCard.widget ? placedCard.widget.icon : "widgets"
                                    size: placedCard.modelData.size === "lg" ? "md" : "sm"
                                    color: placedCard.selected
                                           ? VitrailTokens.color("primary", "#a8c7fa")
                                           : VitrailTokens.color("foreground", "#e2e2e9")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    VitrailText {
                                        Layout.fillWidth: true
                                        variant: placedCard.modelData.size === "lg" ? "body" : "label"
                                        elide: Text.ElideRight
                                        text: root.labelOf(placedCard.modelData.id)
                                    }

                                    VitrailText {
                                        Layout.fillWidth: true
                                        visible: placedCard.height > 52
                                        variant: "label"
                                        color: VitrailTokens.color("muted", "#9aa0a6")
                                        elide: Text.ElideRight
                                        text: root.t("panel.editor.size." + placedCard.modelData.size)
                                              + " · " + (placedCard.modelData.style === ""
                                                         ? root.t("panel.editor.style.default")
                                                         : root.variantLabel(placedCard.modelData.style))
                                    }
                                }
                            }

                            HoverHandler {
                                cursorShape: grab.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            }

                            TapHandler {
                                onTapped: root.selectWidget(placedCard.modelData.id)
                            }

                            DragHandler {
                                id: grab

                                target: placedCard
                                xAxis.minimum: 0
                                xAxis.maximum: Math.max(0, desktopFrame.width - placedCard.width)
                                yAxis.minimum: 0
                                yAxis.maximum: Math.max(0, desktopFrame.height - placedCard.height)

                                onActiveChanged: {
                                    if (!grab.active)
                                        root.moveWidget(placedCard.modelData.id, placedCard.x, placedCard.y,
                                                        placedCard.width, placedCard.height,
                                                        desktopFrame.width, desktopFrame.height)
                                }
                            }

                            // A corner drag asks the registry for the nearest
                            // size; the document never grows a size of its own.
                            Item {
                                objectName: "desktopResizeHandle"

                                property real startWidth: 0
                                visible: placedCard.selected

                                anchors {
                                    right: placedCard.right
                                    bottom: placedCard.bottom
                                    margins: -VitrailTokens.gap("xs")
                                }
                                width: VitrailTokens.desktopEdit.handle
                                height: VitrailTokens.desktopEdit.handle

                                VitrailIcon {
                                    anchors.centerIn: parent
                                    icon: "drag_indicator"
                                    size: "sm"
                                    color: VitrailTokens.color("primary", "#a8c7fa")
                                }

                                DragHandler {
                                    id: resize

                                    target: null

                                    onActiveChanged: {
                                        if (resize.active) {
                                            resize.parent.startWidth = placedCard.width
                                        } else {
                                            root.resizeWidget(placedCard.modelData.id,
                                                              placedCard.width / Math.max(0.01, desktopFrame.desktopScale))
                                            placedCard.dragWidth = -1
                                        }
                                    }

                                    onTranslationChanged: {
                                        if (!resize.active)
                                            return
                                        placedCard.dragWidth = Math.max(48 * desktopFrame.desktopScale,
                                                                        resize.parent.startWidth + resize.activeTranslation.x)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // The bar and the panel tabs: the same editor chrome, with the notice
        // this phase leaves them.
        VitrailSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.tab !== "desktop"
            radius: VitrailTokens.radius
            tint: VitrailTokens.color("surfaceHigh", "#282a2f")
            opacityLevel: VitrailTokens.opacity * 0.39

            Column {
                anchors.centerIn: parent
                spacing: VitrailTokens.gap("sm")

                VitrailIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: root.tab === "bar" ? "toolbar" : "view_sidebar"
                    size: "xl"
                    tone: "muted"
                }

                VitrailText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "subtitle"
                    text: root.tab === "bar" ? root.t("desktop.edit.tab.bar")
                                             : root.t("desktop.edit.tab.panel")
                }

                VitrailText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "body"
                    color: VitrailTokens.color("muted", "#9aa0a6")
                    text: root.t("desktop.edit.comingSoon")
                }
            }
        }

        // The selected widget's size, variant and typography. The document is
        // the state, so every control is a whole write.
        VitrailSurface {
            objectName: "desktopEditInspector"

            Layout.fillWidth: true
            visible: root.tab === "desktop" && root.selectedEntry !== null
            implicitHeight: inspector.implicitHeight + 2 * VitrailTokens.gap("sm")
            radius: VitrailTokens.radius * 0.85
            tint: VitrailTokens.color("surfaceHigh", "#282a2f")
            opacityLevel: VitrailTokens.opacity * 0.83

            ColumnLayout {
                id: inspector

                anchors.fill: parent
                anchors.margins: VitrailTokens.gap("sm")
                spacing: VitrailTokens.gap("xs")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "body"
                        elide: Text.ElideRight
                        text: root.t("desktop.edit.selected") + ": "
                              + root.labelOf(root.selection)
                    }

                    VitrailSegmented {
                        objectName: "desktopEditSizes"

                        options: root.sizeOptions(root.selection)
                        current: root.selectedEntry ? root.selectedEntry.size : "md"
                        foreground: VitrailTokens.color("foreground", "#e2e2e9")
                        accent: VitrailTokens.color("primary", "#a8c7fa")
                        onSelected: root.setSize(root.selection, key)
                    }

                    VitrailSegmented {
                        objectName: "desktopEditStyles"

                        options: root.styleOptions(root.selection)
                        current: root.selectedEntry ? root.selectedEntry.style : ""
                        foreground: VitrailTokens.color("foreground", "#e2e2e9")
                        accent: VitrailTokens.color("primary", "#a8c7fa")
                        onSelected: root.setStyle(root.selection, key)
                    }

                    Item { Layout.fillWidth: true }

                    VitrailButton {
                        objectName: "desktopEditRemove"

                        variant: "text"
                        tone: "error"
                        icon: "delete"
                        onClicked: root.removeWidget(root.selection)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailPicker {
                        objectName: "desktopEditFont"

                        Layout.preferredWidth: 240
                        label: root.t("desktop.editor.font")
                        searchHint: root.t("desktop.editor.font.search")
                        current: root.selectedEntry ? root.selectedEntry.font : ""
                        options: root.fontOptions()
                        foreground: VitrailTokens.color("foreground", "#e2e2e9")
                        accent: VitrailTokens.color("primary", "#a8c7fa")
                        panel: VitrailTokens.color("surfaceHigh", "#282a2f")
                        onSelected: root.setFont(root.selection, key)
                    }

                    VitrailSegmented {
                        objectName: "desktopEditWeights"

                        options: root.weightOptions()
                        current: root.selectedEntry ? root.selectedEntry.weight : ""
                        foreground: VitrailTokens.color("foreground", "#e2e2e9")
                        accent: VitrailTokens.color("primary", "#a8c7fa")
                        onSelected: root.setWeight(root.selection, key)
                    }

                    VitrailSwitch {
                        objectName: "desktopEditItalic"

                        checked: root.selectedEntry ? root.selectedEntry.italic : false
                        foreground: VitrailTokens.color("foreground", "#e2e2e9")
                        accent: VitrailTokens.color("primary", "#a8c7fa")
                        onToggled: root.setItalic(root.selection, value)
                    }

                    VitrailText {
                        variant: "label"
                        color: VitrailTokens.color("muted", "#9aa0a6")
                        text: root.t("desktop.editor.italic")
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // The bottom palette: four base widgets, each with its three variants.
        VitrailSurface {
            objectName: "desktopEditPalette"

            Layout.fillWidth: true
            visible: root.tab === "desktop"
            implicitHeight: paletteColumn.implicitHeight + 2 * VitrailTokens.gap("sm")
            radius: VitrailTokens.radius
            tint: VitrailTokens.color("surfaceHigh", "#282a2f")
            opacityLevel: VitrailTokens.opacity * 0.83

            ColumnLayout {
                id: paletteColumn

                anchors.fill: parent
                anchors.margins: VitrailTokens.gap("sm")
                spacing: VitrailTokens.gap("xs")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailText {
                        variant: "label"
                        color: VitrailTokens.color("muted", "#9aa0a6")
                        text: root.t("desktop.edit.palette")
                    }

                    Repeater {
                        model: root.paletteWidgets

                        delegate: VitrailButton {
                            required property string modelData

                            objectName: "desktopPalette." + modelData
                            variant: root.paletteWidget === modelData ? "tonal" : "text"
                            size: "sm"
                            icon: root.meta(modelData) ? root.meta(modelData).icon : "widgets"
                            text: root.labelOf(modelData)
                            onClicked: root.chooseWidget(modelData)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")
                    visible: root.paletteWidget !== ""

                    VitrailText {
                        variant: "label"
                        color: VitrailTokens.color("muted", "#9aa0a6")
                        text: root.t("desktop.edit.variants")
                    }

                    Repeater {
                        model: root.variants(root.paletteWidget)

                        delegate: VitrailButton {
                            required property string modelData

                            objectName: "desktopVariant." + root.paletteWidget + "." + modelData
                            variant: "outlined"
                            size: "sm"
                            text: root.variantLabel(modelData)
                            onClicked: root.chooseVariant(root.paletteWidget, modelData)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
