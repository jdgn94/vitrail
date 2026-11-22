import QtQuick
import ".."

// A line graph of `values`, oldest first, newest at the right edge. A null (or
// non-finite) value is a gap: the line breaks there instead of dropping to
// zero. The y axis runs from 0 to `maximum`; the area under the line is the
// tone at the graph's fill share.
Item {
    id: root

    property var values: []
    property real maximum: 100
    // How many points the graph is wide; the ring's capacity.
    property int capacity: 60
    // The quarter lines; one of two lines sharing a graph turns them off.
    property bool showGrid: true
    // A family from VitrailVariants.tone.
    property string tone: "primary"
    readonly property var family: VitrailVariants.tone[root.tone] || VitrailVariants.tone.primary
    readonly property color stroke: VitrailTokens.color(root.family.role, "transparent")
    readonly property color grid: Qt.alpha(VitrailTokens.color("foreground", "transparent"), VitrailTokens.graph.grid)

    implicitWidth: VitrailTokens.size("display") * 6
    implicitHeight: VitrailTokens.size("display") * 1.2

    onValuesChanged: canvas.requestPaint()
    onMaximumChanged: canvas.requestPaint()
    onStrokeChanged: canvas.requestPaint()
    onGridChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var context = getContext("2d")
            context.reset()
            var w = width
            var h = height
            var line = VitrailTokens.graph.line
            var list = root.values || []
            var top = root.maximum > 0 ? root.maximum : 1
            var step = root.capacity > 1 ? w / (root.capacity - 1) : w
            // The newest point sits on the right edge; a short list starts later.
            var first = w - (list.length - 1) * step

            context.strokeStyle = root.grid
            context.lineWidth = 1
            for (var quarter = 1; quarter < 4 && root.showGrid; quarter++) {
                var y = Math.round(h * quarter / 4) + 0.5
                context.beginPath()
                context.moveTo(0, y)
                context.lineTo(w, y)
                context.stroke()
            }

            function at(index) {
                var value = Number(list[index])
                if (list[index] === null || list[index] === undefined || !isFinite(value))
                    return null
                var share = Math.max(0, Math.min(value / top, 1))
                return { x: first + index * step, y: line / 2 + (h - line) * (1 - share) }
            }

            var run = []
            function flush() {
                if (run.length === 0)
                    return
                context.beginPath()
                context.moveTo(run[0].x, h)
                for (var i = 0; i < run.length; i++)
                    context.lineTo(run[i].x, run[i].y)
                context.lineTo(run[run.length - 1].x, h)
                context.closePath()
                context.fillStyle = Qt.alpha(root.stroke, VitrailTokens.graph.fill)
                context.fill()
                context.beginPath()
                context.moveTo(run[0].x, run[0].y)
                for (var j = 1; j < run.length; j++)
                    context.lineTo(run[j].x, run[j].y)
                context.strokeStyle = root.stroke
                context.lineWidth = line
                context.lineJoin = "round"
                context.stroke()
                run = []
            }

            for (var index = 0; index < list.length; index++) {
                var point = at(index)
                if (point === null)
                    flush()
                else
                    run.push(point)
            }
            flush()
        }
    }
}
