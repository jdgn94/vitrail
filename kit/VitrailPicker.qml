import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "base"

// A field that shows what is chosen and opens a mosaic of everything else.
//
// It is the three pickers of the Fonts page in one component: an option may
// carry a set of pictures (`icons`, an icon pack's or a cursor's) or a font
// family (`family`, drawn as "Aa" in that family). The trigger shows four at
// 24 px; the dialog shows them all at 84 px with the name underneath, like
// KDE's theme pickers. The dialog is sized by its content and cannot be
// resized.
FocusScope {
    id: root

    property string label: ""
    // { key, label, icons?, family? }
    property var options: []
    property string current: ""
    // A search box appears in the dialog when this has text.
    property string searchHint: ""
    // What the trigger draws; a cursor reads better alone at 24 px.
    property int triggerShown: 4
    property int triggerColumns: 2
    property string variant: ""
    property color foreground: VitrailTokens.color("foreground")
    property color accent: VitrailTokens.color("primary")
    property color panel: VitrailTokens.color("surfaceHigh")

    signal selected(string key)

    readonly property var style: VitrailStyle.resolve("field", root.variant)
    readonly property var surface: VitrailVariants.surface[VitrailTokens.surfaceMode]
                                     || VitrailVariants.surface.glass
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property real boxHeight: VitrailTokens.field.height.md
    readonly property real radius: Math.min(VitrailTokens.radius, root.boxHeight / 2)

    // The dialog: a cell holds 84 px of pictures over the name, and the size
    // comes from the full list so searching does not resize it.
    readonly property int cellWidth: 148
    readonly property int cellHeight: 148
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

    // The row the dialog has highlighted.
    property int highlighted: 0
    property string filter: ""
    readonly property bool expanded: popup.visible
    // The rows the dialog shows: everything, or what the field keeps.
    readonly property var matched: {
        var needle = root.filter.trim().toLowerCase()
        if (needle === "")
            return root.options
        return root.options.filter(function (row) {
            return String(row.label).toLowerCase().indexOf(needle) >= 0
        })
    }

    onFilterChanged: {
        root.highlighted = 0
        grid.currentIndex = 0
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
        root.filter = ""
        root.highlighted = Math.max(0, root.currentIndex)
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

    implicitWidth: VitrailTokens.size("display") * 9
    implicitHeight: root.boxHeight
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

        VitrailText {
            anchors.fill: parent
            visible: preview.count === 0
            variant: preview.size >= 40 ? "title" : "label"
            family: preview.option && preview.option.family ? preview.option.family : ""
            text: preview.option && preview.option.family ? "Aa" : (preview.option ? preview.option.label : "")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.panel.r, root.panel.g, root.panel.b, root.style.fill)
        border.width: root.activeFocus ? root.style.focus : root.style.border
        border.color: root.activeFocus ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g,
                                                               root.foreground.b, root.surface.edge)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: VitrailTokens.gap("md")
            anchors.rightMargin: VitrailTokens.gap("sm")
            spacing: VitrailTokens.gap("sm")

            Preview {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                option: root.currentOption
                size: 24
                columns: root.triggerColumns
                maxShown: root.triggerShown
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                text: root.currentLabel
                elide: Text.ElideRight
            }

            VitrailText {
                variant: "icon"
                font.pixelSize: VitrailTokens.size("subtitle")
                text: "expand_more"
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7)
                rotation: root.expanded ? 180 : 0

                Behavior on rotation { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
            }
        }

        HoverHandler { id: hover }

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

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                Layout.bottomMargin: VitrailTokens.gap("md")
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

                    readonly property bool chosen: cell.index === root.currentIndex
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
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 84
                            option: cell.modelData
                            size: 84
                            columns: 3
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
        }
    }
}
