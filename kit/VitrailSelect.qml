import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "base"
import "shapes.js" as Shapes

// Dropdown for a list of { key, label, icon? } entries, in the look of
// VitrailField: an outlined box with the label in the notch, the current
// value and a chevron that turns when the menu is open. The menu grows from
// the box with a fade and a slight scale; its rows are pills like the tray
// menu's, with a check on the current one.
//
// Keys (box focused): Down / Up / Enter / Space open it; with it open, Up /
// Down / Home / End move the highlight, Enter picks, Escape closes, and
// typing letters jumps to the option that starts with them.
FocusScope {
    id: root

    property string label: ""
    property var options: []
    property string current: ""
    // Field variant (outline / filled); empty inherits the style default.
    property string variant: ""
    property color foreground: VitrailTokens.color("foreground", "#e2e2e9")
    property color accent: VitrailTokens.color("primary", "#a8c7fa")
    property color panel: VitrailTokens.color("surfaceHigh", "#1d2024")

    signal selected(string key)

    readonly property var style: VitrailStyle.resolve("field", root.variant)
    readonly property int currentIndex: root.indexOfKey(root.current)
    readonly property var currentOption: root.currentIndex >= 0 ? root.options[root.currentIndex] : null
    readonly property string currentLabel: root.currentOption ? root.currentOption.label : ""
    // The menu is shown (set as it starts to open, cleared as it starts to close).
    property bool expanded: false
    // Row under the keyboard or the pointer.
    property int highlighted: -1
    readonly property bool active: root.expanded || root.activeFocus
    readonly property bool hasLabel: root.label !== ""
    readonly property bool floated: root.hasLabel && (root.active || root.currentLabel !== "")
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property real padX: VitrailTokens.gap("md")
    readonly property real boxHeight: VitrailTokens.field.height.md
    readonly property real radius: Math.min(VitrailTokens.radius, root.boxHeight / 2)
    readonly property real iconPx: VitrailTokens.size("subtitle")
    readonly property color ink: root.foreground
    readonly property color ring: root.active ? root.accent : VitrailTokens.color("muted")
    readonly property int maxRows: 8
    readonly property var surface: VitrailVariants.surface[VitrailTokens.surfaceMode] || VitrailVariants.surface.glass

    // 0 = label resting in the box, 1 = floating on the border.
    property real labelLift: root.floated ? 1 : 0
    property string typed: ""

    function indexOfKey(key) {
        for (var i = 0; i < root.options.length; i++) {
            if (root.options[i].key === key)
                return i
        }
        return -1
    }

    function open() {
        if (root.expanded || root.options.length === 0)
            return
        root.highlighted = Math.max(0, root.currentIndex)
        popup.open()
    }

    function close() {
        popup.close()
    }

    function pick(index) {
        if (index < 0 || index >= root.options.length)
            return
        root.selected(root.options[index].key)
        root.close()
    }

    function move(index) {
        root.highlighted = Math.max(0, Math.min(root.options.length - 1, index))
        list.positionViewAtIndex(root.highlighted, ListView.Contain)
    }

    // Jumps to the first option whose label starts with what was typed.
    function jump(text) {
        root.typed += text.toLowerCase()
        typing.restart()
        for (var i = 0; i < root.options.length; i++) {
            if (String(root.options[i].label).toLowerCase().indexOf(root.typed) === 0) {
                if (root.expanded)
                    root.move(i)
                else
                    root.selected(root.options[i].key)
                return
            }
        }
    }

    implicitWidth: VitrailTokens.size("display") * 8
    implicitHeight: root.boxHeight
    activeFocusOnTab: true
    opacity: root.enabled ? 1 : 0.45

    Behavior on labelLift { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

    Keys.onPressed: function (event) {
        var key = event.key
        event.accepted = true
        if (key === Qt.Key_Escape && root.expanded) {
            root.close()
        } else if (!root.expanded && (key === Qt.Key_Down || key === Qt.Key_Up || key === Qt.Key_Return
                                      || key === Qt.Key_Enter || key === Qt.Key_Space || key === Qt.Key_F4)) {
            root.open()
        } else if (root.expanded && key === Qt.Key_Down) {
            root.move(root.highlighted + 1)
        } else if (root.expanded && key === Qt.Key_Up) {
            root.move(root.highlighted - 1)
        } else if (root.expanded && key === Qt.Key_Home) {
            root.move(0)
        } else if (root.expanded && key === Qt.Key_End) {
            root.move(root.options.length - 1)
        } else if (root.expanded && (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)) {
            root.pick(root.highlighted)
        } else if (event.text.length === 1 && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            root.jump(event.text)
        } else {
            event.accepted = false
        }
    }

    Timer {
        id: typing

        interval: VitrailTokens.duration("typeahead")
        onTriggered: root.typed = ""
    }

    FontMetrics {
        id: labelMetrics

        font.pixelSize: VitrailTokens.size("label")
        font.family: VitrailTokens.fontFamily
    }

    Item {
        id: box

        width: root.width
        height: root.boxHeight

        Rectangle {
            id: fill

            anchors.fill: parent
            topLeftRadius: root.radius
            topRightRadius: root.radius
            bottomLeftRadius: root.style.indicator ? 0 : root.radius
            bottomRightRadius: root.style.indicator ? 0 : root.radius
            color: {
                var c = VitrailTokens.color(root.style.role)
                return Qt.rgba(c.r, c.g, c.b, root.style.fill)
            }
        }

        // The state layer under the pointer.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: fill.topLeftRadius
            topRightRadius: fill.topRightRadius
            bottomLeftRadius: fill.bottomLeftRadius
            bottomRightRadius: fill.bottomRightRadius
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, hover.hovered && !root.active ? root.style.hover : 0)

            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
        }

        Shape {
            id: outline

            readonly property real inset: root.style.focus / 2
            readonly property real notchPad: VitrailTokens.gap("xs")
            property real stroke: root.active ? root.style.focus : root.style.border

            visible: !root.style.indicator
            x: outline.inset
            y: outline.inset
            width: box.width - 2 * outline.inset
            height: box.height - 2 * outline.inset
            preferredRendererType: Shape.CurveRenderer

            Behavior on stroke { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

            ShapePath {
                fillColor: "transparent"
                strokeWidth: outline.stroke
                strokeColor: root.active ? root.accent : hover.hovered ? root.ink : VitrailTokens.color("muted")

                Behavior on strokeColor { ColorAnimation { duration: root.duration } }

                PathSvg {
                    path: Shapes.outlinePath(outline.width, outline.height, root.radius - outline.inset,
                                             floatingLabel.x - outline.notchPad - outline.inset,
                                             root.hasLabel && root.style.notch
                                             ? (floatingLabel.width + 2 * outline.notchPad) * root.labelLift : 0)
                }
            }
        }

        // Filled variant: a line along the bottom, the accent on focus.
        Rectangle {
            visible: root.style.indicator
            y: box.height - (root.active ? root.style.focus : root.style.border)
            width: box.width
            height: root.active ? root.style.focus : root.style.border
            color: root.ring
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                root.forceActiveFocus()
                if (root.expanded)
                    root.close()
                else
                    root.open()
            }
        }

        VitrailIcon {
            id: leading

            visible: root.currentOption !== null && !!root.currentOption.icon
            x: root.padX
            anchors.verticalCenter: parent.verticalCenter
            pixelSize: root.iconPx
            icon: root.currentOption && root.currentOption.icon ? root.currentOption.icon : ""
            color: root.ink
        }

        VitrailText {
            id: valueText

            x: root.padX + (leading.visible ? root.iconPx + VitrailTokens.gap("sm") : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: chevron.x - x - VitrailTokens.gap("xs")
            elide: Text.ElideRight
            color: root.ink
            // Under a resting label the value waits for the label to rise.
            opacity: root.hasLabel ? root.labelLift : 1
            text: root.currentLabel
        }

        VitrailText {
            id: floatingLabel

            readonly property real restY: (root.boxHeight - labelMetrics.height) / 2
            readonly property real floatY: root.style.notch ? -labelMetrics.height / 2 : VitrailTokens.gap("xs")

            visible: root.hasLabel
            x: root.padX + (root.style.notch ? Math.max(root.padX, root.radius + outline.notchPad) - root.padX : 0) * root.labelLift
            y: restY + (floatY - restY) * root.labelLift
            width: Math.min(implicitWidth, chevron.x - x - VitrailTokens.gap("xs"))
            elide: Text.ElideRight
            font.pixelSize: Math.round(VitrailTokens.size("body") + (VitrailTokens.size("label") - VitrailTokens.size("body")) * root.labelLift)
            color: root.active ? root.accent : VitrailTokens.color("muted")
            text: root.label

            Behavior on color { ColorAnimation { duration: root.duration } }
        }

        VitrailIcon {
            id: chevron

            objectName: "chevron"
            anchors.right: parent.right
            anchors.rightMargin: VitrailTokens.gap("sm")
            anchors.verticalCenter: parent.verticalCenter
            pixelSize: root.iconPx
            icon: "expand_more"
            color: root.active ? root.accent : VitrailTokens.color("muted")
            rotation: root.expanded ? 180 : 0

            Behavior on rotation { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: root.duration } }
        }
    }

    Popup {
        id: popup

        y: box.height + VitrailTokens.gap("xs")
        width: box.width
        padding: VitrailTokens.gap("xs")
        focus: false
        closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
        transformOrigin: Popup.Top
        implicitHeight: Math.min(list.contentHeight, list.rowHeight * root.maxRows) + topPadding + bottomPadding
        onAboutToShow: root.expanded = true
        onAboutToHide: root.expanded = false

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: VitrailTokens.motion.smooth.scale; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: VitrailTokens.duration("fast") }
            NumberAnimation { property: "scale"; to: VitrailTokens.motion.smooth.scale; duration: VitrailTokens.duration("fast") }
        }

        background: Rectangle {
            radius: root.radius
            color: root.panel
            border.width: root.surface.border
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.surface.edge)
        }

        contentItem: ListView {
            id: list

            readonly property real rowHeight: VitrailTokens.size("body") + 2 * VitrailTokens.gap("sm") + VitrailTokens.gap("xs")

            objectName: "options"
            model: root.options
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool chosen: row.index === root.currentIndex

                width: list.width
                height: list.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: VitrailTokens.gap("xs") / 2
                    radius: height / 2
                    color: root.ink
                    opacity: root.highlighted === row.index ? root.style.hover + root.style.hover : 0

                    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
                }

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    x: VitrailTokens.gap("md")
                    width: parent.width - 2 * VitrailTokens.gap("md")
                    spacing: VitrailTokens.gap("sm")

                    VitrailIcon {
                        visible: !!row.modelData.icon
                        pixelSize: root.iconPx
                        icon: row.modelData.icon || ""
                        color: row.chosen ? root.accent : root.ink
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: row.chosen ? root.accent : root.ink
                        font.weight: row.chosen ? Font.DemiBold : Font.Normal
                        text: row.modelData.label
                    }

                    VitrailIcon {
                        visible: row.chosen
                        pixelSize: root.iconPx
                        icon: "check"
                        color: root.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.highlighted = row.index
                    onClicked: root.pick(row.index)
                }
            }
        }
    }
}
