import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "base"

// A field that shows what is chosen and opens a mosaic of everything else.
//
// It is the three pickers of the Fonts page in one component: an option may
// carry a picture (`image`), a set of pictures (`icons`, up to four, for an
// icon pack) or a font family (`family`, drawn as "Aa" in that family).
// The trigger shows the same preview at 24 px; the dialog shows it at 56 px
// with the name underneath, like KDE's theme pickers.
FocusScope {
    id: root

    property string label: ""
    // { key, label, image?, icons?, family? }
    property var options: []
    property string current: ""
    // A search box appears in the dialog when this has text.
    property string searchHint: ""
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

        readonly property bool hasPicture: !!(preview.option && preview.option.image)
        readonly property var icons: preview.option && preview.option.icons ? preview.option.icons : []

        implicitWidth: size
        implicitHeight: size

        Image {
            id: picture

            anchors.fill: parent
            visible: preview.hasPicture
            source: visible ? "file://" + preview.option.image : ""
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(preview.size, preview.size)
            asynchronous: true

        }

        Grid {
            id: pack

            anchors.fill: parent
            visible: !preview.hasPicture && preview.icons.length > 0
            columns: 2
            spacing: 2

            Repeater {
                model: pack.visible ? Math.min(4, preview.icons.length) : 0

                Image {
                    width: (preview.size - 2) / 2
                    height: width
                    source: "file://" + preview.icons[index]
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(width, height)
                    asynchronous: true
                }
            }
        }

        VitrailText {
            anchors.fill: parent
            visible: !preview.hasPicture && !pack.visible
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
        width: Math.min(760, (parent ? parent.width : 760) - 2 * VitrailTokens.gap("xl"))
        height: Math.min(560, (parent ? parent.height : 560) - 2 * VitrailTokens.gap("xl"))

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
                Layout.fillHeight: true
                Layout.leftMargin: VitrailTokens.gap("md")
                Layout.rightMargin: VitrailTokens.gap("md")
                Layout.bottomMargin: VitrailTokens.gap("md")
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.matched
                cellWidth: 132
                cellHeight: 148
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
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            option: cell.modelData
                            size: 56
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
