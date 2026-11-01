import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "wheel.js" as Wheel

// Labelled slider with a live value readout, in the Material 3 expressive
// shape: a thick track split by a vertical handle, with a gap on each side.
//
//   size / thickness  track thickness (tokens.slider sm / md / lg, or px)
//   segments          [{ to: 0.8, color }] colours the track by level, as
//                     fractions of the range; the last one should reach 1
//   icon, endIcon     Material Symbols drawn inside the track
//   readOnly          no handle, the filled and empty parts stay apart
//   continuous        no gap and no end stop: the filled and empty parts meet
//                     (a hairline progress bar: size "thin")
//   stopFilled        the end dot is hollow unless this is set
//   fillOpacity       strength of the filled (active) pieces only, 0..1; the
//                     empty part, the handle and the end stop stay as they are.
//                     Below 1 the fill is pre-tinted over the card (opaque, so
//                     it keeps a crisp edge over the blurred glass); 0 hides it
//                     (a wave drawn over the fill takes its place this way)
//   activeEnd         (read-only) where the filled part ends along the track,
//                     px from the track's start, just before the handle's gap
//   orientation       Qt.Vertical stands it up: the minimum at the bottom,
//                     `length` px tall (or whatever its parent gives it)
//   wheelStep         value units one wheel notch moves (0: the wheel is left
//                     to the parent, so a slider in a scrolling page does not
//                     steal its scrolling); wheel up / right is more. The owner
//                     follows `moved`, as with a drag
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
    property bool continuous: false
    property bool stopFilled: false
    property real fillOpacity: 1
    property int orientation: Qt.Horizontal
    property real length: VitrailTokens.slider.length
    property real wheelStep: 0

    signal moved(real value)

    readonly property real track: root.thickness > 0 ? root.thickness
                                                     : (VitrailTokens.slider[root.size] || VitrailTokens.slider.md)
    readonly property real gap: root.continuous ? 0 : VitrailTokens.slider.gap
    readonly property bool vertical: root.orientation === Qt.Vertical
    // The pointer holds the handle.
    readonly property bool pressed: slider.pressed
    readonly property real activeEnd: slider.activeEnd
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

    // Where the wheel left the value while the owner catches up, and the part
    // of a notch not applied yet.
    property real wheelValue: 0
    property real wheelRest: 0

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

    // The slider is always drawn along x; a vertical one is turned a quarter
    // (pointer input follows the turn), so every part below stays as it is.
    Item {
        id: frame

        Layout.fillWidth: !root.vertical
        Layout.fillHeight: root.vertical
        implicitWidth: root.vertical ? root.handleHeight : slider.implicitWidth
        implicitHeight: root.vertical ? root.length : root.handleHeight

        // Up or right adds; a held-back owner (audio, a monitor) does not
        // stall a fast spin: the wheel counts from its own last value.
        // Under Wayland a wheel comes as a touchpad: the default (mouse only)
        // would never see it.
        WheelHandler {
            enabled: root.wheelStep > 0 && !root.readOnly
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (event) {
                var angle = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x
                var pixels = event.pixelDelta.y !== 0 ? event.pixelDelta.y : -event.pixelDelta.x
                var turned = Wheel.notches(angle, pixels, VitrailTokens.slider.wheelAngle, VitrailTokens.slider.wheelPixels)
                var base = wheelHold.running ? root.wheelValue : root.value
                var state = Wheel.advance(wheelHold.running ? root.wheelRest : 0, turned, root.wheelStep,
                                          root.stepSize, base, root.from, root.to)
                root.wheelRest = state.acc
                wheelHold.restart()
                if (state.value !== base) {
                    root.wheelValue = state.value
                    root.moved(state.value)
                } else {
                    root.wheelValue = base
                }
            }
        }

        Timer {
            id: wheelHold

            interval: VitrailTokens.duration("slow")
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

            anchors.centerIn: parent
            width: root.vertical ? frame.height : frame.width
            height: root.vertical ? frame.width : frame.height
            rotation: root.vertical ? -90 : 0
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
                        readonly property real inner: root.continuous ? 0 : VitrailTokens.slider.handle / 2

                        anchors.fill: parent

                        Rectangle {
                            readonly property real stop: Math.min(band.end, slider.activeEnd)

                            x: band.start
                            width: Math.max(0, stop - band.start)
                            height: parent.height
                            visible: width > 0 && root.fillOpacity > 0
                            color: root.fillOpacity >= 1 ? band.modelData.color
                                                         : VitrailTokens.solid(band.modelData.color, root.fillOpacity)
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
                            color: VitrailTokens.solid(band.modelData.color, 0.28)
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
                    visible: root.endIcon === "" && !root.continuous && slider.inactiveStart < x
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
                    rotation: root.vertical ? 90 : 0
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
                    rotation: root.vertical ? 90 : 0
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
}
