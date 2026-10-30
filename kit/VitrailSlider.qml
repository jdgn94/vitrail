import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Labelled slider with a live value readout, in the Material 3 expressive
// shape: a thick track split by a vertical handle, with a gap on each side.
//
//   size / thickness  track thickness (tokens.slider sm / md / lg, or px)
//   segments          [{ to: 0.8, color }] colours the track by level, as
//                     fractions of the range; the last one should reach 1
//   icon, endIcon     Material Symbols drawn inside the track
//   readOnly          no handle, the filled and empty parts stay apart
//   stopFilled        the end dot is hollow unless this is set
ColumnLayout {
    id: root

    property string label: ""
    property string suffix: ""
    property real from: 0
    property real to: 10
    property real stepSize: 1
    property real value: 0
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")
    // Icon colour where it sits on the filled part.
    property color onAccent: VitrailTokens.color("accentForeground", "#002f65")

    property string size: "md"
    property real thickness: 0
    property var segments: []
    property string icon: ""
    property string endIcon: ""
    property bool readOnly: false
    property bool stopFilled: false

    signal moved(real value)

    readonly property real track: root.thickness > 0 ? root.thickness
                                                     : (VitrailTokens.slider[root.size] || VitrailTokens.slider.md)
    readonly property real gap: VitrailTokens.slider.gap
    readonly property real handleHeight: root.track + 4 * root.gap
    readonly property var bands: {
        var list = root.segments && root.segments.length ? root.segments : [{ to: 1, color: root.accent }]
        var from = 0
        return list.map(function (band) {
            var item = { from: from, to: Math.min(1, band.to), color: band.color || root.accent }
            from = item.to
            return item
        })
    }

    function bandColor(fraction) {
        for (var i = 0; i < root.bands.length; i++) {
            if (fraction <= root.bands[i].to)
                return root.bands[i].color
        }
        return root.bands[root.bands.length - 1].color
    }

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        visible: root.label !== ""

        Text {
            Layout.fillWidth: true
            text: root.label
            color: root.foreground
            font.pixelSize: 13
            font.family: VitrailTokens.fontFamily
        }

        Text {
            text: Math.round(root.value) + root.suffix
            color: root.foreground
            opacity: 0.65
            font.pixelSize: 12
            font.family: VitrailTokens.fontFamily
        }
    }

    Slider {
        id: slider

        // Handle centre and the two track ends either side of it.
        readonly property real span: slider.availableWidth
        property real handleWidth: root.readOnly ? 0
                                            : VitrailTokens.slider.handle / (slider.pressed ? 2 : 1)
        readonly property real centre: Math.max(slider.handleWidth / 2,
                                                Math.min(slider.span - slider.handleWidth / 2,
                                                         slider.visualPosition * slider.span))
        readonly property real activeEnd: Math.max(0, slider.centre - slider.handleWidth / 2 - root.gap)
        readonly property real inactiveStart: Math.min(slider.span, slider.centre + slider.handleWidth / 2 + root.gap)
        readonly property real iconSize: root.track * 0.75

        Layout.fillWidth: true
        implicitHeight: root.handleHeight
        padding: 0
        enabled: !root.readOnly
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        onMoved: root.moved(slider.value)

        Behavior on handleWidth { NumberAnimation { duration: VitrailTokens.duration("fast") } }

        background: Item {
            x: slider.leftPadding
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.span
            height: root.track

            // Each band draws its filled piece and its empty piece. Outer ends
            // are pills; the ends at the handle are nearly square.
            Repeater {
                model: root.bands

                delegate: Item {
                    id: band

                    required property var modelData

                    readonly property real start: band.modelData.from * slider.span
                    readonly property real end: band.modelData.to * slider.span
                    readonly property real outer: root.track / 2
                    readonly property real inner: VitrailTokens.slider.handle / 2

                    anchors.fill: parent

                    Rectangle {
                        readonly property real stop: Math.min(band.end, slider.activeEnd)

                        x: band.start
                        width: Math.max(0, stop - band.start)
                        height: parent.height
                        visible: width > 0
                        color: band.modelData.color
                        topLeftRadius: band.start === 0 ? band.outer : 0
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: stop === slider.activeEnd ? band.inner : 0
                        bottomRightRadius: topRightRadius
                    }

                    Rectangle {
                        readonly property real begin: Math.max(band.start, slider.inactiveStart)

                        x: begin
                        width: Math.max(0, band.end - begin)
                        height: parent.height
                        visible: width > 0
                        color: Qt.rgba(band.modelData.color.r, band.modelData.color.g, band.modelData.color.b, 0.28)
                        topLeftRadius: begin === slider.inactiveStart ? band.inner : 0
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: band.end === slider.span ? band.outer : 0
                        bottomRightRadius: topRightRadius
                    }
                }
            }

            // End stop, hidden once the fill reaches it or an end icon sits there.
            Rectangle {
                readonly property real diameter: root.track * 0.375

                x: slider.span - root.track / 2 - diameter / 2
                anchors.verticalCenter: parent.verticalCenter
                width: diameter
                height: diameter
                radius: diameter / 2
                visible: root.endIcon === "" && slider.inactiveStart < x
                color: root.stopFilled ? root.bandColor(1) : "transparent"
                border.width: root.stopFilled ? 0 : Math.max(1, diameter / 4)
                border.color: root.bandColor(1)
            }

            // Inside the fill when it is long enough, else just past the handle.
            Text {
                readonly property bool onFill: slider.activeEnd >= root.track + slider.iconSize

                x: onFill ? (root.track - slider.iconSize) / 2
                          : slider.inactiveStart + (root.track - slider.iconSize) / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: root.icon !== ""
                text: root.icon
                color: onFill ? root.onAccent : root.bandColor(slider.visualPosition)
                font.family: VitrailTokens.iconFamily
                font.variableAxes: ({ "FILL": 1 })
                font.pixelSize: slider.iconSize
            }

            Text {
                readonly property bool onFill: slider.activeEnd >= slider.span - root.track / 2

                x: slider.span - (root.track + slider.iconSize) / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: root.endIcon !== "" && slider.inactiveStart <= x
                text: root.endIcon
                color: onFill ? root.onAccent : root.bandColor(1)
                font.family: VitrailTokens.iconFamily
                font.variableAxes: ({ "FILL": 1 })
                font.pixelSize: slider.iconSize
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.centre - width / 2
            y: slider.topPadding + (slider.availableHeight - height) / 2
            implicitWidth: slider.handleWidth
            implicitHeight: root.handleHeight
            width: slider.handleWidth
            radius: width / 2
            visible: !root.readOnly
            color: root.bandColor(slider.visualPosition)
        }
    }
}
