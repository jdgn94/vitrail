import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../kit"
import "../../kit/base"
import "../worldmap.js" as Map

// Equirectangular world map with one dot per time zone. The wheel zooms around
// the pointer, dragging pans, hovering a dot names the zone and its local time,
// clicking one emits `picked`. The land is Natural Earth, read from the SVG in
// kit/assets and drawn as vector so it stays sharp at any zoom.
Item {
    id: root

    property var zones: []
    // The zone to highlight, and the one the system uses now (ringed).
    property string selected: ""
    property string current: ""
    property color sea: VitrailTokens.color("surface")
    property color land: VitrailTokens.color("surfaceHigh")
    property color accent: VitrailTokens.color("primary")
    property color foreground: VitrailTokens.color("foreground")

    signal picked(string id)

    readonly property real hitRadius: VitrailTokens.size("body")
    readonly property real dotSize: VitrailTokens.gap("sm")
    // The map is twice as wide as tall: at zoom 1 it fills the item exactly.
    readonly property real mapScale: root.width * root.zoom / 3600
    property real zoom: 1
    property real ox: 0
    property real oy: 0
    // Where the view is heading: wheel steps and drags start from here, not
    // from the middle of an animation.
    property var goal: ({ zoom: 1, ox: 0, oy: 0 })
    property bool animate: false
    property bool panning: false
    readonly property var view: ({ zoom: root.zoom, ox: root.ox, oy: root.oy })
    readonly property var chosenZone: Map.find(root.zones, root.selected)
    readonly property var systemZone: Map.find(root.zones, root.current)
    property var hovered: null
    property real now: Date.now()
    property string landPath: ""

    implicitHeight: root.width / 2
    clip: true

    function show(next, animated) {
        root.animate = animated
        root.zoom = next.zoom
        root.ox = next.ox
        root.oy = next.oy
        root.goal = next
    }

    function zoomBy(factor, px, py) {
        root.show(Map.zoomAbout(root.goal, root.goal.zoom * factor, px, py, root.width, root.height), true)
    }

    // Brings a zone into view; one that is already inside stays put, and the
    // whole map (zoom 1) never moves.
    function reveal(zone) {
        if (!zone || root.goal.zoom <= 1)
            return
        var at = Map.screenOf(zone, root.goal, root.width)
        var margin = root.dotSize
        if (at.x > margin && at.x < root.width - margin && at.y > margin && at.y < root.height - margin)
            return
        root.show(Map.centerOn(zone.lon, zone.lat, Math.max(root.goal.zoom, 2.5), root.width, root.height), true)
    }

    function loadLand() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            var found = /\sd="([^"]+)"/.exec(request.responseText)
            root.landPath = found ? found[1] : ""
        }
        request.open("GET", Qt.resolvedUrl("../../kit/assets/world-110m.svg"))
        request.send()
    }

    Component.onCompleted: root.loadLand()
    onChosenZoneChanged: root.reveal(root.chosenZone)
    onHoveredChanged: if (root.hovered) root.now = Date.now()
    onWidthChanged: root.show(Map.clamp(root.goal, root.width, root.height), false)

    Behavior on zoom { enabled: root.animate; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
    Behavior on ox { enabled: root.animate; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
    Behavior on oy { enabled: root.animate; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

    Timer {
        interval: 30000
        running: root.hovered !== null
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Rectangle {
        anchors.fill: parent
        color: root.sea
    }

    Shape {
        x: root.ox
        y: root.oy
        width: 3600
        height: 1800
        scale: root.mapScale
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.land
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                path: root.landPath
            }
        }
    }

    Repeater {
        model: root.zones

        delegate: Rectangle {
            id: dot

            required property var modelData

            readonly property point at: Map.screenOf(dot.modelData, root.view, root.width)

            x: dot.at.x - width / 2
            y: dot.at.y - height / 2
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            visible: dot.at.x > -width && dot.at.x < root.width + width
                     && dot.at.y > -height && dot.at.y < root.height + height
            color: root.accent
            opacity: 0.6
        }
    }

    // The zone the system uses now: a ring.
    Rectangle {
        readonly property point at: root.systemZone ? Map.screenOf(root.systemZone, root.view, root.width) : Qt.point(0, 0)

        visible: root.systemZone !== null && root.systemZone !== root.chosenZone
        x: at.x - width / 2
        y: at.y - height / 2
        width: root.dotSize * 2
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.foreground
    }

    // The chosen zone: a solid dot in a soft halo.
    Rectangle {
        readonly property point at: root.chosenZone ? Map.screenOf(root.chosenZone, root.view, root.width) : Qt.point(0, 0)

        visible: root.chosenZone !== null
        x: at.x - width / 2
        y: at.y - height / 2
        width: root.dotSize * 3.5
        height: width
        radius: width / 2
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)

        Rectangle {
            anchors.centerIn: parent
            width: root.dotSize * 1.75
            height: width
            radius: width / 2
            color: root.accent
            border.width: 2
            border.color: root.foreground
        }
    }

    // The zone under the pointer grows.
    Rectangle {
        readonly property point at: root.hovered ? Map.screenOf(root.hovered, root.view, root.width) : Qt.point(0, 0)

        visible: root.hovered !== null
        x: at.x - width / 2
        y: at.y - height / 2
        width: root.dotSize * 2
        height: width
        radius: width / 2
        color: root.accent
        border.width: 2
        border.color: root.foreground
    }

    MouseArea {
        id: pointer

        property real pressX: 0
        property real pressY: 0
        property var start: root.goal
        property bool moved: false

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.hovered ? Qt.PointingHandCursor : (pointer.pressed && pointer.moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

        onPressed: function (mouse) {
            pointer.pressX = mouse.x
            pointer.pressY = mouse.y
            pointer.start = root.goal
            pointer.moved = false
        }

        onPositionChanged: function (mouse) {
            if (pointer.pressed) {
                var dx = mouse.x - pointer.pressX
                var dy = mouse.y - pointer.pressY
                if (!pointer.moved && dx * dx + dy * dy < 16)
                    return
                pointer.moved = true
                root.hovered = null
                root.show(Map.clamp({ zoom: pointer.start.zoom, ox: pointer.start.ox + dx, oy: pointer.start.oy + dy },
                                    root.width, root.height), false)
                return
            }
            root.hovered = Map.nearest(root.zones, root.view, root.width, mouse.x, mouse.y, root.hitRadius)
        }

        onExited: root.hovered = null

        onReleased: function (mouse) {
            if (pointer.moved)
                return
            var hit = Map.nearest(root.zones, root.view, root.width, mouse.x, mouse.y, root.hitRadius)
            if (hit)
                root.picked(hit.id)
        }

        onWheel: function (wheel) {
            root.zoomBy(wheel.angleDelta.y > 0 ? 1.3 : 1 / 1.3, wheel.x, wheel.y)
            root.hovered = null
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: VitrailTokens.gap("sm")
        spacing: VitrailTokens.gap("xs")

        VitrailButton {
            variant: "tonal"
            size: "sm"
            icon: "add"
            onClicked: root.zoomBy(1.6, root.width / 2, root.height / 2)
        }

        VitrailButton {
            variant: "tonal"
            size: "sm"
            icon: "remove"
            onClicked: root.zoomBy(1 / 1.6, root.width / 2, root.height / 2)
        }

        VitrailButton {
            variant: "tonal"
            size: "sm"
            icon: "my_location"
            onClicked: root.chosenZone
                       ? root.show(Map.centerOn(root.chosenZone.lon, root.chosenZone.lat, Math.max(root.goal.zoom, 2.5), root.width, root.height), true)
                       : root.show({ zoom: 1, ox: 0, oy: 0 }, true)
        }
    }

    VitrailTooltip {
        readonly property point at: root.hovered ? Map.screenOf(root.hovered, root.view, root.width) : Qt.point(0, 0)
        readonly property bool above: at.y - height - root.dotSize * 2 >= 0

        text: root.hovered ? root.hovered.id.replace(/_/g, " ") : ""
        detail: root.hovered ? Map.localTime(root.hovered.offset, root.now) + " · " + Map.offsetLabel(root.hovered.offset) : ""
        active: root.hovered !== null
        edge: above ? "bottom" : "top"
        x: Math.max(0, Math.min(root.width - width, at.x - width / 2))
        y: above ? at.y - height - root.dotSize * 2 : at.y + root.dotSize * 2
    }
}
