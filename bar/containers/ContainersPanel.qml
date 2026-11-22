import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "containers.js" as Containers

// The containers element's popup: one row per container with its name, its
// image, its state and health, its ports, and the buttons its state allows
// (Start while stopped, Stop while running, Logs always, in the shell's
// terminal). Pinned containers come first and carry a pin toggle. A machine
// with neither engine gets one calm line naming both, and an engine error is
// one calm line with the reason. The gear opens the element's block in
// Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `containersPinned` preference: one JSON array of names.
    property string pinned: ""
    // An action is running: every action waits for it.
    property bool busy: false
    // The last failed action's stderr, as one calm line.
    property string error: ""

    signal settingsRequested()
    // One container action: start/stop take its id, logs opens the terminal.
    signal actionRequested(string action, string id)
    // The row's pin was toggled.
    signal pinRequested(string name, bool on)

    readonly property bool ready: Containers.ready(root.snapshot)
    readonly property string engine: Containers.engineOf(root.snapshot)
    readonly property var rows: Containers.ordered(root.snapshot, root.pinned)
    readonly property string engineError: root.ready && root.engine !== ""
                                            && root.snapshot.error ? String(root.snapshot.error) : ""
    // About five rows fit before the list starts to scroll.
    readonly property real listMax: VitrailTokens.size("display") * 10

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // A container's state, with its health when the engine reports one.
    function stateLabel(one) {
        var state = Containers.stateKey(one)
        var label = state === "" ? (one ? String(one.state || "") : "") : root.t(state)
        var health = Containers.healthKey(one)
        return health === "" ? label : label + " · " + root.t(health)
    }

    implicitWidth: VitrailTokens.size("display") * 25
    implicitHeight: body.implicitHeight

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
                elide: Text.ElideRight
                text: root.t("bar.widget.containers")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.containers.unreadable")
        }

        VitrailText {
            objectName: "engineError"

            Layout.fillWidth: true
            visible: root.engineError !== ""
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.containers.error")
                  .replace("%1", root.engine).replace("%2", root.engineError)
        }

        VitrailText {
            objectName: "noEngine"

            Layout.fillWidth: true
            visible: root.ready && root.engine === ""
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.containers.noEngine")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(cards.implicitHeight, root.listMax)
            visible: root.ready && root.engine !== "" && root.rows.length > 0
            contentWidth: width
            contentHeight: cards.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: cards

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.rows

                    delegate: ColumnLayout {
                        id: card

                        required property var modelData

                        readonly property var container: card.modelData
                        readonly property bool pinned: Containers.isPinned(root.pinned, card.container.name)
                        readonly property bool up: Containers.isRunning(card.container)

                        objectName: "container"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: "deployed_code"
                                color: VitrailTokens.color("muted")
                            }

                            VitrailText {
                                objectName: "containerName"

                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: card.container.name || ""
                            }

                            VitrailText {
                                objectName: "containerImage"

                                Layout.maximumWidth: VitrailTokens.size("display") * 10
                                variant: "label"
                                elide: Text.ElideRight
                                text: card.container.image || ""
                            }

                            VitrailText {
                                objectName: "containerState"

                                variant: "label"
                                text: root.stateLabel(card.container)
                            }

                            VitrailButton {
                                objectName: "pin"

                                variant: card.pinned ? "tonal" : "plain"
                                tone: card.pinned ? "primary" : "secondary"
                                size: "sm"
                                icon: "push_pin"
                                onClicked: root.pinRequested(card.container.name, !card.pinned)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                objectName: "containerPorts"

                                Layout.fillWidth: true
                                visible: (card.container.ports || "") !== ""
                                variant: "label"
                                elide: Text.ElideRight
                                text: card.container.ports || ""
                            }

                            VitrailButton {
                                objectName: "start"

                                visible: !card.up
                                variant: "tonal"
                                tone: "primary"
                                size: "sm"
                                icon: "play_arrow"
                                text: root.t("bar.containers.start")
                                enabled: !root.busy
                                onClicked: root.actionRequested("start", card.container.id)
                            }

                            VitrailButton {
                                objectName: "stop"

                                visible: card.up
                                variant: "tonal"
                                tone: "secondary"
                                size: "sm"
                                icon: "stop"
                                text: root.t("bar.containers.stop")
                                enabled: !root.busy
                                onClicked: root.actionRequested("stop", card.container.id)
                            }

                            VitrailButton {
                                objectName: "logs"

                                variant: "plain"
                                tone: "secondary"
                                size: "sm"
                                icon: "description"
                                text: root.t("bar.containers.logs")
                                enabled: !root.busy
                                onClicked: root.actionRequested("logs", card.container.id)
                            }
                        }
                    }
                }
            }
        }

        VitrailText {
            objectName: "empty"

            Layout.fillWidth: true
            visible: root.ready && root.engine !== "" && root.engineError === ""
                     && root.rows.length === 0
            variant: "body"
            text: root.t("bar.containers.empty")
        }

        VitrailText {
            objectName: "actionError"

            Layout.fillWidth: true
            visible: root.error !== ""
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.error
        }
    }
}
