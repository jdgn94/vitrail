import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "volume.js" as Volume

// The volume element's popup: the master volume with its device's name, one
// row per application stream (volume, mute, and the output it plays on), the
// output and input device choosers and the microphone's mute. The snapshot is
// vitrail.audio's; every change leaves as `audioAction(args)` and the shell
// runs the process. The gear opens the element's block in Settings → Bar
// elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // Preferences: the percent one wheel notch moves a slider, and whether
    // paused streams are left out of the list.
    property int step: 5
    property bool hideSilent: false

    // An icon name (the app's own) to the file that draws it, "" when there is
    // none. The shell supplies Quickshell's lookup; the gallery has no icons.
    property var iconPath: function (name) { return "" }

    signal settingsRequested()
    signal audioAction(var args)

    readonly property bool ready: Volume.ready(root.snapshot)
    readonly property var sink: Volume.sink(root.snapshot)
    readonly property var source: root.snapshot.defaultSource || null
    readonly property var sinks: root.snapshot.sinks || []
    readonly property var sources: root.snapshot.sources || []
    readonly property var sinkOptions: Volume.deviceOptions(root.sinks)
    readonly property var sourceOptions: Volume.deviceOptions(root.sources)
    // The listed streams' ids: it changes only when the list does, so the
    // rows (and a slider being dragged) survive a poll.
    property var streamIds: []
    readonly property real streamsMax: VitrailTokens.size("display") * 8

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function streamById(id) {
        var list = root.snapshot.streams || []
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].id) === String(id))
                return list[i]
        }
        return ({})
    }

    function syncStreams() {
        var ids = Volume.streams(root.snapshot, root.hideSilent).map(function (stream) { return String(stream.id) })
        if (JSON.stringify(ids) !== JSON.stringify(root.streamIds))
            root.streamIds = ids
    }

    onSnapshotChanged: root.syncStreams()
    onHideSilentChanged: root.syncStreams()
    Component.onCompleted: root.syncStreams()

    implicitWidth: 360
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
                text: root.t("bar.widget.volume")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        // No audio server to read: say so instead of drawing sliders that
        // would do nothing.
        VitrailText {
            objectName: "unavailable"

            Layout.fillWidth: true
            visible: !root.ready
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.volume.unreadable")
        }

        VolumeRow {
            objectName: "master"

            Layout.fillWidth: true
            visible: root.ready
            size: "md"
            name: root.sink ? root.sink.description : ""
            glyph: "speaker"
            muteGlyph: Volume.icon(root.snapshot)
            volume: root.sink ? root.sink.volume : 0
            muted: root.sink ? root.sink.muted : false
            wheelStep: root.step
            onVolumeRequested: function (value) { root.audioAction(Volume.volumeArgs("sink", value)) }
            onMuteRequested: root.audioAction(Volume.muteArgs("sink"))
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.ready
            variant: "label"
            text: root.t("bar.volume.apps")
        }

        VitrailText {
            objectName: "noStreams"

            Layout.fillWidth: true
            visible: root.ready && root.streamIds.length === 0
            variant: "body"
            text: root.t("bar.volume.noApps")
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, root.streamsMax)
            visible: root.ready && root.streamIds.length > 0
            contentWidth: width
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rows

                width: list.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.streamIds

                    delegate: VolumeRow {
                        id: line

                        required property string modelData
                        readonly property var stream: root.streamById(line.modelData)

                        objectName: "stream"

                        Layout.fillWidth: true
                        name: line.stream.app || ""
                        iconSource: line.stream.icon ? root.iconPath(line.stream.icon) : ""
                        glyph: "apps"
                        muteGlyph: line.stream.muted ? "volume_off" : "volume_up"
                        volume: line.stream.volume || 0
                        muted: !!line.stream.muted
                        wheelStep: root.step
                        options: root.sinkOptions
                        current: Volume.streamSink(line.stream)
                        outputLabel: root.t("bar.volume.sendTo")
                        onVolumeRequested: function (value) { root.audioAction(Volume.volumeArgs(line.stream.id, value)) }
                        onMuteRequested: root.audioAction(Volume.muteArgs(line.stream.id))
                        onOutputRequested: function (key) {
                            var name = Volume.sinkName(root.snapshot, key)
                            if (name !== "")
                                root.audioAction(Volume.moveArgs(line.stream, name))
                        }
                    }
                }
            }
        }

        VitrailSelect {
            objectName: "outputDevice"

            Layout.fillWidth: true
            visible: root.ready && root.sinkOptions.length > 0
            label: root.t("bar.volume.output")
            options: root.sinkOptions
            current: root.sink ? String(root.sink.id) : ""
            onSelected: function (key) { root.audioAction(Volume.defaultArgs(key)) }
        }

        VitrailSelect {
            objectName: "inputDevice"

            Layout.fillWidth: true
            visible: root.ready && root.sourceOptions.length > 0
            label: root.t("bar.volume.input")
            options: root.sourceOptions
            current: root.source ? String(root.source.id) : ""
            onSelected: function (key) { root.audioAction(Volume.defaultArgs(key)) }
        }

        RowLayout {
            objectName: "micRow"

            Layout.fillWidth: true
            visible: root.ready && root.source !== null
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: Volume.micIcon(root.snapshot)
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                elide: Text.ElideRight
                text: root.t("bar.volume.muteMic")
            }

            VitrailSwitch {
                objectName: "micMute"

                checked: root.source ? root.source.muted : false
                onToggled: root.audioAction(Volume.muteArgs("source"))
            }
        }
    }
}
