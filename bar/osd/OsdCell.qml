import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "osd.js" as Osd

// One slider of the OSD with its icon and its percentage. On a side edge it
// stands up (icon above, percentage below); on the top or bottom edge it lies
// down (icon first, percentage last). The icon of volume and microphone is a
// mute button; brightness has none. A slider that cannot work is dimmed and
// says why in its `tooltip`.
Item {
    id: root

    // volume, mic or brightness.
    property string kind: ""
    property bool vertical: true
    // Sizes from osd.js: { thickness, length, icon, textWide, textTall, pad, spacing, inner }.
    property var metrics: ({})
    // 0..100.
    property real value: 0
    property string icon: ""
    // The icon mutes (volume, mic) and the state it shows.
    property bool muteable: false
    property bool muted: false
    property bool available: true
    // What the pointer reads over a slider that cannot be used; a muteable
    // icon names what a click does.
    property string tooltip: ""
    property string tooltipDetail: ""
    // The slider's thickness (sm / md / lg) and the percent one wheel notch
    // moves.
    property string sliderSize: VitrailTokens.osd.size
    property real step: VitrailTokens.osd.step

    signal moved(real value)
    signal muteRequested()
    signal settingsRequested()

    readonly property bool hovered: hover.hovered
    readonly property bool pressed: slider.pressed || mute.pressed
    readonly property bool settingsHovered: gear.hovered
    readonly property var size: Osd.cell(root.vertical, root.metrics)

    implicitWidth: root.size.width
    implicitHeight: root.size.height
    opacity: root.available ? 1 : 0.45

    HoverHandler {
        id: hover
    }

    GridLayout {
        anchors.fill: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: root.metrics.inner
        columnSpacing: root.metrics.inner

        // The icon: a button that mutes, or a plain glyph.
        Item {
            Layout.preferredWidth: root.metrics.icon
            Layout.preferredHeight: root.metrics.icon
            Layout.alignment: Qt.AlignCenter

            VitrailButton {
                id: mute

                anchors.fill: parent
                visible: root.muteable
                enabled: root.available
                variant: "plain"
                tone: root.muted ? "error" : "secondary"
                size: "md"
                icon: root.icon
                onClicked: root.muteRequested()
            }

            VitrailText {
                anchors.centerIn: parent
                visible: !root.muteable
                variant: "icon"
                text: root.icon
                color: VitrailTokens.color("foreground")
            }
        }

        VitrailSlider {
            id: slider

            Layout.fillWidth: !root.vertical
            Layout.fillHeight: root.vertical
            Layout.preferredWidth: root.vertical ? root.metrics.thickness : root.metrics.length
            Layout.preferredHeight: root.vertical ? root.metrics.length : root.metrics.thickness
            orientation: root.vertical ? Qt.Vertical : Qt.Horizontal
            size: root.sliderSize
            length: root.metrics.length
            from: 0
            to: 100
            stepSize: 1
            wheelStep: root.step
            value: root.value
            enabled: root.available
            accent: root.muted ? VitrailTokens.color("muted") : VitrailTokens.color("primary")
            onMoved: function (value) { root.moved(value) }
        }

        VitrailText {
            Layout.preferredWidth: root.vertical ? root.metrics.thickness : root.metrics.textWide
            Layout.preferredHeight: root.vertical ? root.metrics.textTall : root.metrics.thickness
            horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: root.vertical ? Text.AlignBottom : Text.AlignVCenter
            variant: "label"
            text: root.available ? Math.round(root.value) + "%" : "–"
        }

        // The gear: the settings of this slider (the layer picks the page).
        Item {
            Layout.preferredWidth: root.metrics.gear || root.metrics.icon
            Layout.preferredHeight: root.metrics.gear || root.metrics.icon
            Layout.alignment: Qt.AlignCenter

            VitrailButton {
                id: gear

                objectName: "osdSettings"
                anchors.fill: parent
                variant: "plain"
                tone: "secondary"
                size: "md"
                icon: "settings"
                onClicked: root.settingsRequested()
            }
        }
    }
}
