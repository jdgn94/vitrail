import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "actions.js" as Session

// Full-screen session menu: a dimmed backdrop, a greeting and a row of large
// round actions. Arrow keys (and Tab) move the focus ring, Enter or Space runs
// the action under it, a letter runs its own, Escape or a click on the
// backdrop dismisses. It only reports `chosen` / `dismissed`; the window and
// the commands belong to the shell.
Item {
    id: root

    property var strings: ({})
    property string user: ""
    property date now: new Date()
    property bool canHibernate: false
    // Fades and scales in while true.
    property bool open: false
    property int current: 0

    signal chosen(string key)
    signal dismissed()

    readonly property var items: Session.available(root.canHibernate)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function focusMenu() {
        root.current = 0
        root.forceActiveFocus()
    }

    function choose(index) {
        if (index >= 0 && index < root.items.length)
            root.chosen(root.items[index].key)
    }

    function move(delta) {
        root.current = Session.step(root.current, root.items.length, delta)
    }

    focus: true
    opacity: root.open ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

    onOpenChanged: if (root.open) root.focusMenu()

    Keys.onPressed: function (event) {
        event.accepted = true
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            root.move(-1)
            break
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            root.move(1)
            break
        case Qt.Key_Home:
            root.current = 0
            break
        case Qt.Key_End:
            root.current = root.items.length - 1
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.choose(root.current)
            break
        case Qt.Key_Escape:
            root.dismissed()
            break
        default:
            var index = event.modifiers === Qt.NoModifier ? Session.byShortcut(root.items, event.text) : -1
            if (index >= 0)
                root.choose(index)
            else
                event.accepted = false
        }
    }

    // Glass keeps the surface translucent so the compositor's blur shows.
    VitrailSurface {
        anchors.fill: parent
        style: VitrailTokens.surfaceMode
        radius: 0
        tint: VitrailTokens.color("surface")
        opacityLevel: VitrailTokens.opacity
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: VitrailTokens.gap("xl")
        scale: root.open ? 1 : 0.94

        Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("slow"); easing.type: Easing.OutCubic } }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: VitrailTokens.gap("xs")

            VitrailText {
                Layout.alignment: Qt.AlignHCenter
                variant: "display"
                text: root.t("session.greeting").replace("%1", root.user)
            }

            VitrailText {
                Layout.alignment: Qt.AlignHCenter
                variant: "subtitle"
                font.features: ({ "tnum": 1 })
                text: Qt.formatTime(root.now, "HH:mm")
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: VitrailTokens.gap("lg")

            Repeater {
                model: root.items

                delegate: ColumnLayout {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property bool focused: root.current === tile.index

                    spacing: VitrailTokens.gap("sm")

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: button.implicitWidth
                        implicitHeight: button.implicitHeight

                        // The focus ring, a little outside the circle.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -VitrailTokens.gap("xs")
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: VitrailTokens.color(tile.modelData.tone === "error" ? "error" : "primary")
                            opacity: tile.focused ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                        }

                        VitrailButton {
                            id: button

                            variant: "tonal"
                            tone: tile.modelData.tone
                            size: "xl"
                            icon: tile.modelData.icon
                            onClicked: root.chosen(tile.modelData.key)
                            onHoveredChanged: if (hovered) root.current = tile.index
                        }
                    }

                    VitrailText {
                        Layout.alignment: Qt.AlignHCenter
                        variant: "body"
                        font.weight: tile.focused ? Font.DemiBold : Font.Normal
                        text: root.t(tile.modelData.label)
                    }
                }
            }
        }
    }
}
