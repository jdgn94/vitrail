import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The sample element's popup: the snapshot's run and when it was taken. The
// gear opens the element's own page in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})

    signal settingsRequested()

    readonly property bool ready: root.snapshot.counter !== undefined && !root.snapshot.error

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 320
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.ready ? root.t("bar.widget.sample.run").replace("%1", root.snapshot.counter)
                                 : root.t("bar.widget.sample.unavailable")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            visible: root.ready
            text: root.t("bar.widget.sample.updated").replace("%1", Qt.formatTime(new Date(root.snapshot.updated * 1000), "HH:mm"))
        }
    }
}
