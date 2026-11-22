import QtQuick
import "../kit"

// One symbol's day: a line through the sparkline the snapshot carries, drawn
// with the same Canvas the media panel's progress wave uses (no charting
// dependency). The tone follows the sign of the change; a symbol without a
// series draws nothing at all.
Item {
    id: root

    property var values: []
    // A palette role: primary when it rose, error when it fell, muted flat.
    property string tone: "muted"

    objectName: "sparkline"

    implicitWidth: VitrailTokens.size("display") * 3
    implicitHeight: VitrailTokens.size("title")

    Canvas {
        id: canvas

        readonly property real line: Math.max(1, VitrailTokens.gap("xs") / 2)

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: root

            function onValuesChanged() { canvas.requestPaint() }
            function onToneChanged() { canvas.requestPaint() }
        }

        Connections {
            target: VitrailTokens

            function onPaletteChanged() { canvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var points = root.values
            if (!Array.isArray(points) || points.length < 2)
                return
            var min = Infinity
            var max = -Infinity
            for (var i = 0; i < points.length; i++) {
                var value = Number(points[i])
                if (!isFinite(value))
                    continue
                min = Math.min(min, value)
                max = Math.max(max, value)
            }
            if (!isFinite(min) || !isFinite(max))
                return
            var span = max - min
            var pad = canvas.line
            ctx.strokeStyle = VitrailTokens.color(root.tone, VitrailTokens.color("foreground"))
            ctx.lineWidth = canvas.line
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            for (var j = 0; j < points.length; j++) {
                var x = pad + (canvas.width - 2 * pad) * j / (points.length - 1)
                var y = span <= 0 ? canvas.height / 2
                                   : pad + (canvas.height - 2 * pad) * (max - Number(points[j])) / span
                if (j === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }
}
