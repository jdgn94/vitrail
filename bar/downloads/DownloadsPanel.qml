import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "downloads.js" as Downloads

// The downloads element's popup: one row per running download with the same
// honest bar the notification card draws (determinate only when the downloader
// reserved a total, a sliding bar and the word "measuring" otherwise), its
// size, speed and elapsed time, and Open folder / Open file / Cancel; then the
// recent finished ones with their final name, size and the same two ways to
// open them. `downloadsRecent` says how many of those the list keeps. A calm
// line stands in when there is nothing, never an empty card. The gear opens
// the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `downloadsRecent` preference: how many finished rows the popup keeps.
    property int recentLimit: Downloads.RECENT_DEFAULT

    signal settingsRequested()
    // The element deletes and moves nothing itself: the shell answers these.
    signal openFolderRequested(string path)
    signal openFileRequested(string path)
    signal cancelRequested(string path)

    readonly property bool ready: Downloads.ready(root.snapshot)
    readonly property var activeRows: Downloads.active(root.snapshot)
    readonly property var recentRows: Downloads.recent(root.snapshot, root.recentLimit)
    readonly property bool empty: root.ready && root.activeRows.length === 0
                                  && root.recentRows.length === 0
    // About eight rows fit before the list scrolls.
    readonly property real listMax: VitrailTokens.size("display") * 8

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 400
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
                text: root.t("bar.widget.downloads")
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
            text: root.t("bar.downloads.unreadable")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(content.implicitHeight, root.listMax)
            visible: root.ready
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: content

                width: list.width
                spacing: VitrailTokens.gap("md")

                VitrailText {
                    Layout.fillWidth: true
                    visible: root.activeRows.length > 0
                    variant: "label"
                    text: root.t("bar.downloads.active")
                }

                Repeater {
                    model: root.activeRows

                    delegate: ColumnLayout {
                        id: download

                        required property var modelData

                        readonly property int percent: Downloads.percentOf(download.modelData)

                        objectName: "downloadRow"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("xs")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "label"
                                elide: Text.ElideRight
                                text: String(download.modelData.name || "")
                            }

                            VitrailText {
                                objectName: "percent"

                                visible: download.percent >= 0
                                variant: "label"
                                text: download.percent >= 0 ? download.percent + "%" : ""
                            }

                            VitrailText {
                                objectName: "measuring"

                                visible: download.percent < 0
                                variant: "label"
                                opacity: 0.7
                                text: root.t("bar.downloads.measuring")
                            }
                        }

                        // The same bar as the notification card: the fill grows
                        // from the left when the total is known, and slides when
                        // it is not. No percentage is invented either way.
                        Item {
                            id: track

                            objectName: "bar"

                            Layout.fillWidth: true
                            implicitHeight: VitrailTokens.slider.thin

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: VitrailTokens.solid("foreground", 0.15)
                            }

                            Rectangle {
                                id: progress

                                height: parent.height
                                radius: height / 2
                                color: VitrailTokens.color("primary")
                                width: download.percent >= 0 ? parent.width * download.percent / 100
                                                             : parent.width * 0.25
                                visible: String(download.modelData.state || "") !== "cancelling"
                            }

                            Binding {
                                target: progress
                                property: "x"
                                value: 0
                                when: download.percent >= 0
                                     || String(download.modelData.state || "") === "cancelling"
                                restoreMode: Binding.RestoreNone
                            }

                            SequentialAnimation {
                                running: download.percent < 0
                                         && String(download.modelData.state || "") !== "cancelling"
                                loops: Animation.Infinite

                                NumberAnimation {
                                    target: progress
                                    property: "x"
                                    from: 0
                                    to: Math.max(0, track.width - progress.width)
                                    duration: VitrailTokens.duration("slow")
                                    easing.type: Easing.InOutCubic
                                }

                                NumberAnimation {
                                    target: progress
                                    property: "x"
                                    from: Math.max(0, track.width - progress.width)
                                    to: 0
                                    duration: VitrailTokens.duration("slow")
                                    easing.type: Easing.InOutCubic
                                }
                            }
                        }

                        VitrailText {
                            objectName: "stats"

                            Layout.fillWidth: true
                            variant: "label"
                            opacity: 0.7
                            elide: Text.ElideRight
                            text: Downloads.stateText(download.modelData, root.t) !== ""
                                  ? Downloads.stateText(download.modelData, root.t)
                                  : Downloads.stats(download.modelData, root.t)
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: VitrailTokens.gap("sm")

                            VitrailButton {
                                objectName: "openFolder"

                                variant: "tonal"
                                tone: "secondary"
                                size: "sm"
                                icon: "folder_open"
                                text: root.t("downloads.action.folder")
                                enabled: String(download.modelData.folder || "") !== ""
                                onClicked: root.openFolderRequested(String(download.modelData.folder))
                            }

                            VitrailButton {
                                objectName: "openFile"

                                variant: "tonal"
                                tone: "secondary"
                                size: "sm"
                                icon: "open_in_new"
                                text: root.t("downloads.action.file")
                                enabled: download.modelData.finalExists === true
                                onClicked: root.openFileRequested(String(download.modelData.final))
                            }

                            VitrailButton {
                                objectName: "cancel"

                                variant: "tonal"
                                tone: "error"
                                size: "sm"
                                icon: "close"
                                text: root.t("downloads.action.cancel")
                                onClicked: root.cancelRequested(String(download.modelData.path))
                            }
                        }
                    }
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: root.recentRows.length > 0
                    variant: "label"
                    text: root.t("bar.downloads.recent")
                }

                Repeater {
                    model: root.recentRows

                    delegate: RowLayout {
                        id: finished

                        required property var modelData

                        objectName: "recentRow"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("sm")

                        VitrailText {
                            Layout.fillWidth: true
                            variant: "body"
                            elide: Text.ElideRight
                            text: String(finished.modelData.name || "")
                        }

                        VitrailText {
                            objectName: "recentSize"

                            variant: "label"
                            opacity: 0.7
                            text: Downloads.humanSize(finished.modelData.size)
                        }

                        VitrailButton {
                            objectName: "openFolder"

                            variant: "plain"
                            tone: "secondary"
                            size: "sm"
                            icon: "folder_open"
                            enabled: String(finished.modelData.folder || "") !== ""
                            onClicked: root.openFolderRequested(String(finished.modelData.folder))
                        }

                        VitrailButton {
                            objectName: "openFile"

                            variant: "plain"
                            tone: "secondary"
                            size: "sm"
                            icon: "open_in_new"
                            onClicked: root.openFileRequested(String(finished.modelData.path))
                        }
                    }
                }

                VitrailText {
                    objectName: "empty"

                    Layout.fillWidth: true
                    visible: root.empty
                    variant: "body"
                    wrapMode: Text.WordWrap
                    text: root.t("bar.downloads.empty")
                }
            }
        }
    }
}
