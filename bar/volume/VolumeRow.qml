import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// One line of the volume popup: an icon (an app's, or a glyph), a name, a
// mute button, a slider with its percentage, and an optional output chooser
// under it. The master volume and every application stream use it.
//
// A drag asks for a new volume at most once per `throttle`, and the slider
// keeps the dragged value until the snapshot catches up, so it does not jump
// back to the last poll while wpctl is still working.
ColumnLayout {
    id: root

    property string name: ""
    // The app's icon file ("" draws `glyph`).
    property string iconSource: ""
    property string glyph: "volume_up"
    property string muteGlyph: "volume_up"
    property string muteTooltip: ""
    property real volume: 0
    property bool muted: false
    // Output chooser: { key, label } options and the current key; hidden when
    // `options` is empty.
    property var options: []
    property string current: ""
    property string outputLabel: ""
    property string size: "sm"
    // The percent one wheel notch moves the slider.
    property real wheelStep: 5

    signal volumeRequested(real value)
    signal muteRequested()
    signal outputRequested(string key)

    readonly property bool holding: slider.pressed || hold.running
    readonly property real shown: root.holding ? root.local : root.volume
    property real local: 0
    property real sent: -1
    // Where the throttle's trailing call picks up.
    property real pending: -1

    function request(value) {
        root.local = value
        hold.restart()
        if (throttle.running) {
            root.pending = value
            return
        }
        root.send(value)
        throttle.start()
    }

    function send(value) {
        root.pending = -1
        root.sent = value
        root.volumeRequested(value)
    }

    spacing: VitrailTokens.gap("xs")

    Timer {
        id: throttle

        interval: VitrailTokens.duration("fast")
        onTriggered: {
            if (root.pending >= 0 && root.pending !== root.sent) {
                root.send(root.pending)
                throttle.start()
            }
        }
    }

    // How long the dragged value outlives the last move.
    Timer {
        id: hold

        interval: VitrailTokens.duration("slow") * 2
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        Item {
            Layout.preferredWidth: VitrailTokens.size("display")
            Layout.preferredHeight: VitrailTokens.size("display")

            Image {
                id: art

                anchors.fill: parent
                anchors.margins: VitrailTokens.gap("xs")
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(width, height)
                source: root.iconSource
                visible: status === Image.Ready
            }

            VitrailIcon {
                anchors.centerIn: parent
                visible: !art.visible
                icon: root.glyph
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "body"
            elide: Text.ElideRight
            text: root.name
        }

        VitrailButton {
            objectName: "mute"

            Layout.preferredWidth: VitrailTokens.size("display")
            Layout.preferredHeight: VitrailTokens.size("display")
            icon: root.muteGlyph
            variant: "plain"
            tone: root.muted ? "error" : "secondary"
            size: "sm"
            onClicked: root.muteRequested()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        VitrailSlider {
            id: slider

            objectName: "slider"

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            size: root.size
            from: 0
            to: 100
            stepSize: 1
            wheelStep: root.wheelStep
            value: root.shown
            accent: root.muted ? VitrailTokens.color("muted") : VitrailTokens.color("primary")
            onMoved: function (value) { root.request(value) }
        }

        VitrailText {
            objectName: "percent"

            Layout.preferredWidth: Math.round(VitrailTokens.size("label") * 3.2)
            horizontalAlignment: Text.AlignRight
            variant: "label"
            text: Math.round(root.shown) + "%"
        }
    }

    VitrailSelect {
        objectName: "output"

        Layout.fillWidth: true
        visible: root.options.length > 1
        label: root.outputLabel
        options: root.options
        current: root.current
        onSelected: function (key) { root.outputRequested(key) }
    }
}
