import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../kit"
import "../kit/base"

// A tray app's context menu as a bar popout: rows like the connection list's
// (the checked ones tinted), thin separators, disabled entries dimmed, check
// marks for toggles and a chevron for submenus, which slide in over the menu with a back row on top.
StackView {
    id: root

    required property var handle
    property var strings: ({})

    signal done()

    implicitWidth: root.currentItem ? root.currentItem.implicitWidth : 0
    implicitHeight: root.currentItem ? root.currentItem.implicitHeight : 0

    initialItem: MenuLevel {
        handle: root.handle
    }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    pushEnter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VitrailTokens.duration("base") }
        NumberAnimation { property: "x"; from: VitrailTokens.gap("lg"); to: 0; duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic }
    }
    pushExit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: VitrailTokens.duration("fast") }
    }
    popEnter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VitrailTokens.duration("base") }
    }
    popExit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: VitrailTokens.duration("fast") }
        NumberAnimation { property: "x"; to: VitrailTokens.gap("lg"); duration: VitrailTokens.duration("fast") }
    }

    Component {
        id: submenu

        MenuLevel {}
    }

    component MenuLevel: ColumnLayout {
        id: menu

        property var handle
        property bool nested: false

        spacing: VitrailTokens.gap("xs")

        StackView.onRemoved: menu.destroy()

        QsMenuOpener {
            id: opener

            menu: menu.handle
        }

        // Back to the parent menu.
        VitrailButton {
            visible: menu.nested
            Layout.bottomMargin: VitrailTokens.gap("xs")
            variant: "tonal"
            tone: "secondary"
            size: "sm"
            icon: "chevron_left"
            text: root.t("tray.back")
            onClicked: root.pop()
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: row

                required property var modelData

                // A check or radio entry that is on.
                readonly property bool checked: row.modelData.buttonType !== QsMenuButtonType.None
                                                && row.modelData.checkState === Qt.Checked

                Layout.preferredWidth: VitrailTokens.tray.menu
                implicitHeight: row.modelData.isSeparator ? VitrailTokens.gap("sm") : line.implicitHeight + 2 * VitrailTokens.gap("xs")

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    visible: row.modelData.isSeparator
                    color: VitrailTokens.color("foreground")
                    opacity: 0.12
                }

                Rectangle {
                    anchors.fill: parent
                    radius: VitrailTokens.radius / 2
                    visible: !row.modelData.isSeparator && (row.checked || (hover.hovered && row.modelData.enabled))
                    color: row.checked ? VitrailTokens.solid("primary", 0.14) : VitrailTokens.solid("foreground", 0.06)

                    Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
                }

                RowLayout {
                    id: line

                    anchors.verticalCenter: parent.verticalCenter
                    x: VitrailTokens.gap("sm")
                    width: parent.width - 2 * VitrailTokens.gap("sm")
                    visible: !row.modelData.isSeparator
                    spacing: VitrailTokens.gap("sm")
                    opacity: row.modelData.enabled ? 1 : 0.45

                    IconImage {
                        visible: row.modelData.icon !== ""
                        implicitSize: VitrailTokens.size("body") + 2
                        source: row.modelData.icon
                        asynchronous: true
                    }

                    // Checkbox and radio entries: a check when on.
                    VitrailText {
                        visible: row.modelData.buttonType !== QsMenuButtonType.None
                        variant: "icon"
                        font.pixelSize: VitrailTokens.size("body") + 2
                        icon: row.modelData.buttonType === QsMenuButtonType.RadioButton
                              ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                              : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                        color: row.checked ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "body"
                        elide: Text.ElideRight
                        text: row.modelData.text.replace(/_(?!_)/, "")
                    }

                    VitrailText {
                        visible: row.modelData.hasChildren
                        variant: "icon"
                        font.pixelSize: VitrailTokens.size("body") + 4
                        icon: "chevron_right"
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !row.modelData.isSeparator && row.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.hasChildren) {
                            root.push(submenu, { handle: row.modelData, nested: true })
                        } else {
                            row.modelData.triggered()
                            root.done()
                        }
                    }
                }
            }
        }
    }
}
