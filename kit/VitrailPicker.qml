import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "base"

// A field that shows what is chosen and opens a mosaic of everything else.
//
// It is the pickers of the Fonts page in one component: an option may carry a
// set of pictures (`icons`, an icon pack's or a cursor's) or a font family
// (`family`, drawn as "Aa" in that family). The compact trigger is a field
// with four pictures at 24 px. `large` turns it into the approved preview
// card: the whole mosaic over the name, a real radius and the accent ring on
// focus; clicking it still opens the same dialog. The dialog shows every
// picture with the name underneath, like KDE's theme pickers, and is sized by
// its content.
FocusScope {
    id: root

    property string label: ""
    // { key, label, icons?, family?, glyph?, tab? }
    property var options: []
    property string current: ""
    // Tabs split the dialog's options; a row without `tab` belongs to the
    // first one. `actions` are buttons under the grid, each shown on its own
    // tab (or on every tab when `tab` is empty).
    property var tabs: []
    property string currentTab: ""
    property var actions: []
    property string emptyText: ""
    // A search box appears in the dialog when this has text.
    property string searchHint: ""
    // What the trigger draws; a cursor reads better alone at 24 px.
    property int triggerShown: 4
    property int triggerColumns: 2
    property int triggerSize: 24
    // The dialog's cells: a font needs only "Aa", an icon pack a large mosaic.
    property int cellPreview: 84
    property int cellColumns: 3
    property int cellWidth: 148
    property int cellHeight: 148
    // The big card used by the application-icon and cursor pickers.
    property bool large: false
    property string variant: ""
    property color foreground: VitrailTokens.color("foreground")
    property color accent: VitrailTokens.color("primary")
    property color panel: VitrailTokens.color("surfaceHigh")

    signal selected(string key)
    // `tab` is the tab the button was shown on (empty without tabs).
    signal actionTriggered(string key, string tab)

    readonly property var style: VitrailStyle.resolve("field", root.variant)
    readonly property var surface: VitrailVariants.surface[VitrailTokens.surfaceMode]
                                     || VitrailVariants.surface.glass
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property real boxHeight: VitrailTokens.field.height.md
    readonly property real largeHeight: root.cellPreview + VitrailTokens.size("subtitle")
                                        + 3 * VitrailTokens.gap("md")
    readonly property real radius: root.large ? VitrailTokens.radius
                                               : Math.min(VitrailTokens.radius, root.boxHeight / 2)

    // The size comes from the full list so searching does not resize it.
    readonly property int maxColumns: 5
    readonly property real availableWidth: root.Window.window ? root.Window.window.width : 1000
    readonly property real availableHeight: root.Window.window ? root.Window.window.height : 680
    // The header, the search box and the margins around the grid.
    readonly property real chrome: 2 * VitrailTokens.field.height.md
                                   + 4 * VitrailTokens.gap("md") + 2 * VitrailTokens.gap("sm")
    readonly property int columns: {
        var fit = Math.floor((root.availableWidth - 2 * VitrailTokens.gap("xl")) / root.cellWidth)
        return Math.max(1, Math.min(root.maxColumns,
                                    Math.min(fit, Math.max(1, root.options.length))))
    }
    readonly property int rows: Math.ceil(Math.max(1, root.options.length) / root.columns)
    // Rows that fit the window; the rest scrolls.
    readonly property int maxRows: Math.max(1, Math.floor(
        (root.availableHeight - 2 * VitrailTokens.gap("xl") - root.chrome) / root.cellHeight))
    readonly property real gridWidth: root.columns * root.cellWidth
    readonly property real gridHeight: Math.min(root.rows, root.maxRows) * root.cellHeight
    readonly property int currentIndex: root.indexOfKey(root.current)
    readonly property var currentOption: root.currentIndex >= 0 ? root.options[root.currentIndex] : null
    readonly property string currentLabel: root.currentOption ? root.currentOption.label : root.current

    // The row the dialog has highlighted and the action asking to confirm.
    property int highlighted: 0
    property string filter: ""
    property string pendingAction: ""
    readonly property bool expanded: popup.visible
    // The rows on the current tab: everything, or what the search keeps.
    readonly property var matched: {
        var rows = root.options
        if (root.tabs.length > 0) {
            var tab = root.currentTab || root.tabs[0].key
            rows = rows.filter(function (row) {
                return (row.tab === undefined || row.tab === "") ? tab === root.tabs[0].key
                                                                 : row.tab === tab
            })
        }
        var needle = root.filter.trim().toLowerCase()
        if (needle === "")
            return rows
        return rows.filter(function (row) {
            return String(row.label).toLowerCase().indexOf(needle) >= 0
        })
    }
    readonly property var visibleActions: root.actions.filter(function (action) {
        return action.tab === undefined || action.tab === "" || action.tab === root.currentTab
    })

    onFilterChanged: {
        root.highlighted = 0
        grid.currentIndex = 0
    }

    onCurrentTabChanged: {
        root.filter = ""
        root.pendingAction = ""
        root.highlighted = Math.max(0, root.matchedIndexOfKey(root.current))
        grid.currentIndex = root.highlighted
    }

    function matchedIndexOfKey(key) {
        for (var i = 0; i < root.matched.length; i++) {
            if (root.matched[i].key === key)
                return i
        }
        return -1
    }

    function indexOfKey(key) {
        for (var i = 0; i < root.options.length; i++) {
            if (root.options[i].key === key)
                return i
        }
        return -1
    }

    function open() {
        if (root.options.length === 0)
            return
        if (root.tabs.length > 0) {
            if (root.currentTab === "")
                root.currentTab = root.tabs[0].key
            var chosen = root.options.find(function (row) {
                return row.key === root.current && row.tab
            })
            if (chosen)
                root.currentTab = chosen.tab
        }
        root.filter = ""
        root.pendingAction = ""
        root.highlighted = Math.max(0, root.matchedIndexOfKey(root.current))
        grid.currentIndex = root.highlighted
        popup.open()
    }

    function close() {
        popup.close()
    }

    function pick(index) {
        var rows = root.matched
        if (index < 0 || index >= rows.length)
            return
        root.selected(rows[index].key)
        root.close()
    }

    // One click asks for confirmation (`confirm`); the next one acts.
    function activateAction(key) {
        var action = root.visibleActions.find(function (row) {
            return row.key === key
        })
        if (!action || action.enabled === false)
            return
        if (action.confirm && root.pendingAction !== key) {
            root.pendingAction = key
            return
        }
        root.pendingAction = ""
        root.actionTriggered(key, root.currentTab)
    }

    implicitWidth: root.large ? Math.max(root.cellPreview + 2 * VitrailTokens.gap("md"),
                                         VitrailTokens.size("display") * 7)
                              : VitrailTokens.size("display") * 9
    implicitHeight: root.large ? root.largeHeight : root.boxHeight
    activeFocusOnTab: true
    opacity: root.enabled ? 1 : 0.45

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.open()
            event.accepted = true
        }
    }

    // The same preview in the trigger, the grid and (scaled) the dialog.
    component Preview: Item {
        id: preview

        property var option: null
        property real size: 24
        property int columns: 2
        // 0 draws every picture the option has.
        property int maxShown: 4

        readonly property var icons: preview.option && preview.option.icons ? preview.option.icons : []
        readonly property int count: preview.icons.length === 0 ? 0
                                     : (preview.maxShown > 0 ? Math.min(preview.maxShown,
                                                                        preview.icons.length)
                                                             : preview.icons.length)
        readonly property int rows: preview.count === 0 ? 1
                                   : Math.ceil(preview.count / Math.max(1, preview.columns))
        readonly property real gap: 2
        // A square slot that fits every row and column inside `size`.
        readonly property real slot: Math.max(1, Math.min(
            (preview.size - (preview.columns - 1) * preview.gap) / Math.max(1, preview.columns),
            (preview.size - (preview.rows - 1) * preview.gap) / Math.max(1, preview.rows)))

        implicitWidth: size
        implicitHeight: size

        Grid {
            id: pack

            anchors.centerIn: parent
            visible: preview.count > 0
            columns: preview.columns
            spacing: preview.gap

            Repeater {
                model: pack.visible ? preview.count : 0

                Image {
                    width: preview.slot
                    height: preview.slot
                    source: "file://" + preview.icons[index]
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(width, height)
                    asynchronous: true
                }
            }
        }

        VitrailIcon {
            id: glyph

            anchors.fill: parent
            visible: preview.count === 0 && !!preview.option && !!preview.option.glyph
            // The chosen cell only changes colour; icons are never filled.
            pixelSize: Math.min(preview.size, VitrailTokens.size("title"))
            icon: visible ? preview.option.glyph : ""
        }

        VitrailText {
            anchors.fill: parent
            visible: preview.count === 0 && !glyph.visible && !!preview.option
                     && !!preview.option.family
            variant: preview.size >= 40 ? "title" : "label"
            family: preview.option && preview.option.family ? preview.option.family : ""
            text: "Aa"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.panel.r, root.panel.g, root.panel.b,
                       root.large ? root.surface.raised : root.style.fill)
        border.width: root.activeFocus ? root.style.focus : root.style.border
        border.color: root.activeFocus ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g,
                                                               root.foreground.b, root.surface.edge)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: VitrailTokens.gap("md")
            anchors.rightMargin: VitrailTokens.gap("sm")
            visible: !root.large
            spacing: VitrailTokens.gap("sm")

            Preview {
                Layout.preferredWidth: root.triggerSize
                Layout.preferredHeight: root.triggerSize
                option: root.currentOption
                size: root.triggerSize
                columns: root.triggerColumns
                maxShown: root.triggerShown
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.currentLabel
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: VitrailTokens.gap("md")
            visible: root.large
            spacing: VitrailTokens.gap("sm")

            Preview {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.cellPreview
                Layout.preferredHeight: root.cellPreview
                option: root.currentOption
                size: root.cellPreview
                columns: root.cellColumns
                maxShown: 0
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.currentLabel
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        TapHandler {
            onTapped: {
                root.forceActiveFocus()
                root.open()
            }
        }
    }

    Popup {
        id: popup

        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        // No scrim: the platform style's dim washes a dark window white.
        dim: false
        padding: 0
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        // Sized by the content (the full list, not the filtered rows) and not
        // resizable: a Popup has no frame.
        width: contentItem.implicitWidth
        height: contentItem.implicitHeight

        onOpened: {
            grid.forceActiveFocus()
            grid.positionViewAtIndex(grid.currentIndex, GridView.Beginning)
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: VitrailTokens.motion.smooth.scale; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: VitrailTokens.duration("fast") }
        }

        background: Rectangle {
            radius: VitrailTokens.radius
            color: root.panel
            border.width: root.surface.border
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                                  root.surface.edge)
        }

        contentItem: ColumnLayout {
            spacing: VitrailTokens.gap("sm")

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: VitrailTokens.gap("md")
                spacing: VitrailTokens.gap("sm")

                VitrailText {
                    Layout.fillWidth: true
                    variant: "title"
                    text: root.label
                    elide: Text.ElideRight
                }

                VitrailButton {
                    variant: "plain"
                    tone: "secondary"
                    icon: "close"
                    onClicked: root.close()
                }
            }

            VitrailTabs {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                visible: root.tabs.length > 0
                tabs: root.tabs
                current: root.currentTab
                foreground: root.foreground
                accent: root.accent
                onSelected: root.currentTab = key
            }

            VitrailField {
                id: searchField

                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                visible: root.searchHint !== ""
                placeholder: root.searchHint
                leadingIcon: "search"
                text: root.filter
                onTextChanged: root.filter = searchField.text
            }

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                visible: root.matched.length === 0 && root.emptyText !== ""
                text: root.emptyText
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7)
                horizontalAlignment: Text.AlignHCenter
            }

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                Layout.bottomMargin: VitrailTokens.gap("md")
                visible: root.matched.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.matched
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                Layout.preferredWidth: root.gridWidth
                Layout.preferredHeight: root.gridHeight
                keyNavigationEnabled: true
                focus: true

                onCurrentIndexChanged: root.highlighted = currentIndex

                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.pick(grid.currentIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                    }
                }

                delegate: Rectangle {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool chosen: cell.modelData.key === root.current
                    readonly property bool pointed: cellHover.hovered

                    width: grid.cellWidth - VitrailTokens.gap("sm")
                    height: grid.cellHeight - VitrailTokens.gap("sm")
                    radius: VitrailTokens.radius
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b,
                                   cell.chosen ? 0.16 : cell.pointed ? root.style.hover : 0)
                    border.width: cell.chosen ? root.style.focus : 0
                    border.color: root.accent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: VitrailTokens.gap("sm")
                        spacing: VitrailTokens.gap("xs")

                        Preview {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.cellPreview
                            Layout.preferredHeight: root.cellPreview
                            option: cell.modelData
                            size: root.cellPreview
                            columns: root.cellColumns
                            maxShown: 0
                        }

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "label"
                            text: cell.modelData.label
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler { id: cellHover }

                    TapHandler {
                        onTapped: root.pick(cell.index)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                Layout.bottomMargin: VitrailTokens.gap("md")
                visible: root.visibleActions.length > 0
                spacing: VitrailTokens.gap("sm")

                Item { Layout.fillWidth: true }

                Repeater {
                    model: root.visibleActions

                    VitrailButton {
                        required property var modelData

                        readonly property bool confirming: root.pendingAction === modelData.key
                                                          && !!modelData.confirm

                        text: confirming ? modelData.confirm : (modelData.label || "")
                        icon: modelData.icon || ""
                        variant: modelData.variant || "tonal"
                        tone: modelData.tone || "secondary"
                        size: "sm"
                        enabled: modelData.enabled !== false
                        onClicked: root.activateAction(modelData.key)
                    }
                }
            }
        }
    }
}
