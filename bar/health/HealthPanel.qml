import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "health.js" as Health

// The health element's popup: one row per problem (a severity dot, the title,
// the detail wrapped and capped) with the buttons the problem allows: Fix runs
// its argv and Logs shows its output, both in a terminal the user can see. A
// clean machine gets one calm line. The gear opens the element's block in
// Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The ids of the bar elements that failed to load (the shell's own signal).
    property var failed: []

    signal settingsRequested()
    // The argv of a problem's `fix` or `logs`; the shell quotes it and opens
    // it in the terminal. Nothing here runs a fix on its own.
    signal fixRequested(var argv)
    signal logsRequested(var argv)
    signal refreshRequested()

    readonly property var problems: Health.problems(root.snapshot, root.failed)
    readonly property bool ready: Health.ready(root.snapshot)
    // About six problems fit before the list scrolls.
    readonly property real listMax: VitrailTokens.size("display") * Health.ROW_LIMIT * 2

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 380
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
                text: root.t("bar.widget.health")
            }

            VitrailButton {
                objectName: "refresh"

                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "refresh"
                onClicked: root.refreshRequested()
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        RowLayout {
            objectName: "fine"

            Layout.fillWidth: true
            visible: root.ready && root.problems.length === 0
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "task_alt"
                container: false
                tone: "primary"
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                wrapMode: Text.WordWrap
                text: root.t("bar.health.fine")
            }
        }

        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready && root.problems.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.health.unreadable")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, root.listMax)
            visible: root.problems.length > 0
            contentWidth: width
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rows

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.problems

                    delegate: ColumnLayout {
                        id: row

                        required property var modelData

                        objectName: "problemRow"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                objectName: "severity"

                                icon: "circle"
                                size: "sm"
                                container: false
                                tone: Health.tone(row.modelData.severity)
                            }

                            VitrailText {
                                objectName: "title"

                                Layout.fillWidth: true
                                variant: "label"
                                elide: Text.ElideRight
                                text: Health.title(row.modelData, root.t)
                            }
                        }

                        VitrailText {
                            objectName: "detail"

                            Layout.fillWidth: true
                            visible: text !== ""
                            variant: "label"
                            opacity: 0.7
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            text: Health.detail(row.modelData, root.t)
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            visible: Health.hasArgv(row.modelData.fix) || Health.hasArgv(row.modelData.logs)
                            spacing: VitrailTokens.gap("sm")

                            VitrailButton {
                                objectName: "logs"

                                visible: Health.hasArgv(row.modelData.logs)
                                variant: "tonal"
                                tone: "secondary"
                                size: "sm"
                                icon: "terminal"
                                text: root.t("bar.health.logs")
                                onClicked: root.logsRequested(Health.argv(row.modelData.logs))
                            }

                            VitrailButton {
                                objectName: "fix"

                                visible: Health.hasArgv(row.modelData.fix)
                                variant: "tonal"
                                tone: "primary"
                                size: "sm"
                                icon: "restart_alt"
                                text: root.t("bar.health.fix")
                                onClicked: root.fixRequested(Health.argv(row.modelData.fix))
                            }
                        }
                    }
                }
            }
        }
    }
}
