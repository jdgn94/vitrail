import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "binds.js" as Binds

// The keybind cheatsheet: a search field over the shortcuts Hyprland reports,
// then the filtered list. The field keeps the keyboard: up and down move, Enter
// does nothing, Escape closes. Only kit components draw it.
Item {
    id: root

    property var strings: ({})
    // `[{mods, key, dispatcher, arg, description}]` from vitrail/binds.py.
    property var rows: []
    // False when hyprctl could not read Hyprland's binds.
    property bool available: true
    property alias query: field.text
    property int current: 0

    signal dismissed()

    readonly property var filtered: Binds.filter(root.rows, root.query)
    readonly property real listMax: VitrailTokens.field.height.md * 7

    implicitWidth: 460
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function move(step) {
        var count = root.filtered.length
        if (count === 0)
            return
        root.current = Math.max(0, Math.min(count - 1, root.current + step))
    }

    // The keys the field hands over before the text sees them.
    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Down:
            root.move(1)
            event.accepted = true
            return
        case Qt.Key_Up:
            root.move(-1)
            event.accepted = true
            return
        case Qt.Key_PageDown:
            root.move(5)
            event.accepted = true
            return
        case Qt.Key_PageUp:
            root.move(-5)
            event.accepted = true
            return
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // Nothing to run here: the cheatsheet is a reference.
            event.accepted = true
            return
        case Qt.Key_Escape:
            event.accepted = true
            root.dismissed()
            return
        }
    }

    onQueryChanged: {
        root.current = 0
        list.positionViewAtBeginning()
    }
    onFilteredChanged: root.current = Math.min(root.current, Math.max(0, root.filtered.length - 1))
    onCurrentChanged: if (root.filtered.length > 0) list.positionViewAtIndex(root.current, ListView.Contain)

    Component.onCompleted: field.forceActiveFocus()

    Keys.onEscapePressed: root.dismissed()

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                text: root.t("binds.title")
            }

            VitrailText {
                visible: root.available
                variant: "label"
                text: root.t("binds.count").arg(root.rows.length)
            }
        }

        VitrailField {
            id: field

            Layout.fillWidth: true
            size: "md"
            leadingIcon: "search"
            placeholder: root.t("binds.search")
            onKeyPressed: function (event) { root.handleKey(event) }
        }

        VitrailText {
            objectName: "bindsUnavailable"

            Layout.fillWidth: true
            Layout.preferredHeight: VitrailTokens.field.height.md
            visible: !root.available
            verticalAlignment: Text.AlignVCenter
            variant: "content"
            text: root.t("binds.unavailable")
        }

        VitrailText {
            objectName: "bindsEmpty"

            Layout.fillWidth: true
            Layout.preferredHeight: VitrailTokens.field.height.md
            visible: root.available && root.filtered.length === 0
            verticalAlignment: Text.AlignVCenter
            variant: "content"
            text: root.t("binds.empty")
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, root.listMax)
            visible: root.filtered.length > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered
            currentIndex: root.current
            spacing: VitrailTokens.gap("xs")

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool selected: row.index === root.current

                width: ListView.view.width
                implicitHeight: Math.max(line.implicitHeight + 2 * VitrailTokens.gap("sm"),
                                        VitrailTokens.field.height.sm)

                VitrailSurface {
                    anchors.fill: parent
                    visible: row.selected
                    style: VitrailTokens.surfaceMode
                    tint: VitrailTokens.color("primary")
                    opacityLevel: VitrailTokens.opacity * 0.2
                    radius: VitrailTokens.radius / 2
                }

                HoverHandler {
                    id: hover

                    onHoveredChanged: if (hover.hovered) root.current = row.index
                }

                RowLayout {
                    id: line

                    anchors.fill: parent
                    anchors.leftMargin: VitrailTokens.gap("sm")
                    anchors.rightMargin: VitrailTokens.gap("sm")
                    spacing: VitrailTokens.gap("md")

                    VitrailText {
                        Layout.preferredWidth: Math.max(VitrailTokens.size("body") * 10,
                                                        VitrailTokens.field.height.md * 2)
                        variant: "body"
                        font.weight: Font.DemiBold
                        color: row.selected ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
                        elide: Text.ElideRight
                        text: Binds.combo(row.modelData)
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "content"
                        color: row.selected ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
                        elide: Text.ElideRight
                        text: Binds.label(row.modelData, root.t)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                variant: "label"
                text: root.t("binds.hint.navigate")
            }

            Item {
                Layout.fillWidth: true
            }

            VitrailText {
                variant: "label"
                text: root.t("binds.hint.close")
            }
        }
    }
}
