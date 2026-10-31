import QtQuick
import QtQuick.Shapes
import ".."
import "../shapes.js" as Shapes

// Text field primitive. `variant` picks the look (outline: the label floats
// into a notch of the outline; filled: a fill with a bottom indicator), `size`
// the box and font. In `type: "password"` the characters are drawn as random
// Material 3 Expressive shapes, one per character, and an eye button reveals
// the text. The real TextInput underneath keeps the text and the focus.
FocusScope {
    id: root

    property string variant: ""
    // sm / md / lg: box height and font size.
    property string size: "md"
    property string label: ""
    property string placeholder: ""
    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    // "text" or "password".
    property string type: "text"
    // Optional Material Symbol name, before the text.
    property string leadingIcon: ""
    property string supportingText: ""
    property bool error: false
    // Replaces the supporting text while `error` is set.
    property string errorText: ""
    property bool readOnly: false
    // Password only: show the characters instead of the shapes.
    property bool revealed: false

    signal accepted()
    signal escaped()
    // Every key, before the text takes it: a caller that wants some keys for
    // itself (Tab, Ctrl+E, the arrows) sets `event.accepted`.
    signal keyPressed(var event)

    readonly property int shapeCount: shapes.count
    readonly property var style: VitrailStyle.resolve("field", root.variant)
    readonly property bool password: root.type === "password"
    readonly property bool hidden: root.password && !root.revealed
    readonly property bool hasLabel: root.label !== ""
    readonly property bool focused: input.activeFocus
    readonly property bool active: root.focused || root.error
    // The label sits in the field until there is something to label.
    readonly property bool floated: root.hasLabel && (root.focused || input.length > 0)
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property string fontToken: ({ sm: "content", md: "body", lg: "subtitle" })[root.size] || "body"
    readonly property real inputPx: VitrailTokens.size(root.fontToken)
    readonly property real padX: VitrailTokens.gap("md")
    readonly property real boxHeight: Math.max(VitrailTokens.field.height[root.size] || VitrailTokens.field.height.md,
                                               input.implicitHeight + labelMetrics.height + VitrailTokens.gap("xs"))
    readonly property real radius: Math.min(VitrailTokens.radius, root.boxHeight / 2)
    readonly property real iconPx: VitrailTokens.size("subtitle")
    readonly property real contentX: root.padX + (root.leadingIcon !== "" ? root.iconPx + VitrailTokens.gap("sm") : 0)
    readonly property real contentWidth: Math.max(0, box.width - root.contentX
                                                  - (root.password ? eye.width + 2 * VitrailTokens.gap("xs") : root.padX))
    // Where the text line sits: under the label when it rides inside.
    readonly property bool labelInside: root.hasLabel && !root.style.notch
    readonly property real textY: root.labelInside ? (root.boxHeight - labelMetrics.height - input.implicitHeight) / 2 + labelMetrics.height
                                                   : (root.boxHeight - input.implicitHeight) / 2
    readonly property real shapePx: Math.round(root.inputPx * VitrailTokens.field.shape)
    readonly property real stride: root.shapePx + VitrailTokens.gap("xs")
    readonly property color accent: VitrailTokens.color(root.error ? "error" : (root.focused ? "primary" : "muted"))
    readonly property color ink: VitrailTokens.color(root.style.text)

    // 0 = label resting in the field, 1 = floating on the border.
    property real labelLift: root.floated ? 1 : 0
    property real shakeX: 0
    property bool caretOn: true
    // Set once the field is built; initial text is synced by then.
    property bool ready: false

    // The shape names in order, as drawn.
    function shapeKinds() {
        var kinds = []
        for (var i = 0; i < shapes.count; i++)
            kinds.push(shapes.get(i).kind)
        return kinds
    }

    function shake() {
        shaking.restart()
    }

    // Keeps one shape per character: new characters get a random shape at
    // the cursor, deleted ones leave from the cursor.
    function sync() {
        if (!root.password) {
            shapes.clear()
            return
        }
        var have = shapes.count, want = input.length
        if (want > have) {
            var added = want - have
            var at = Math.max(0, Math.min(have, input.cursorPosition - added))
            for (var i = 0; i < added; i++)
                shapes.insert(at + i, { kind: Shapes.random(at + i > 0 ? shapes.get(at + i - 1).kind : "", Shapes.distinct) })
        } else if (want < have) {
            var removed = have - want
            shapes.remove(Math.max(0, Math.min(have - removed, input.cursorPosition)), removed)
        }
    }

    implicitWidth: VitrailTokens.size("display") * 10
    implicitHeight: box.height + (note.visible ? VitrailTokens.gap("xs") + note.implicitHeight : 0)
    opacity: root.enabled ? 1 : 0.45
    onPasswordChanged: if (root.ready) root.sync()
    Component.onCompleted: {
        root.ready = true
        root.sync()
    }

    Behavior on labelLift { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

    SequentialAnimation {
        id: shaking

        readonly property real reach: VitrailTokens.gap("xs")
        readonly property int step: VitrailTokens.duration("fast") / 2

        NumberAnimation { target: root; property: "shakeX"; to: -shaking.reach; duration: shaking.step }
        NumberAnimation { target: root; property: "shakeX"; to: shaking.reach; duration: shaking.step }
        NumberAnimation { target: root; property: "shakeX"; to: -shaking.reach * 0.6; duration: shaking.step }
        NumberAnimation { target: root; property: "shakeX"; to: shaking.reach * 0.6; duration: shaking.step }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: shaking.step }
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
        transform: Translate { x: root.shakeX }

        // Fill, and the state layer under the pointer.
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

        Rectangle {
            anchors.fill: parent
            topLeftRadius: fill.topLeftRadius
            topRightRadius: fill.topRightRadius
            bottomLeftRadius: fill.bottomLeftRadius
            bottomRightRadius: fill.bottomRightRadius
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, hover.hovered && !root.focused ? root.style.hover : 0)

            Behavior on color { ColorAnimation { duration: VitrailTokens.duration("fast") } }
        }

        // Outline variants: the border, open behind the floating label.
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
                strokeColor: root.error || root.focused ? root.accent
                             : hover.hovered ? root.ink : VitrailTokens.color("muted")

                Behavior on strokeColor { ColorAnimation { duration: root.duration } }

                PathSvg {
                    path: Shapes.outlinePath(outline.width, outline.height, root.radius - outline.inset,
                                             floatingLabel.x - outline.notchPad - outline.inset,
                                             root.hasLabel && root.style.notch
                                             ? (floatingLabel.width + 2 * outline.notchPad) * root.labelLift : 0)
                }
            }
        }

        // Filled variants: a line along the bottom, and the accent growing
        // from the centre on focus.
        Rectangle {
            visible: root.style.indicator
            x: 0
            y: box.height - root.style.border
            width: box.width
            height: root.style.border
            color: VitrailTokens.color("muted")
        }

        Rectangle {
            id: indicator

            visible: root.style.indicator
            width: box.width * (root.active ? 1 : 0)
            height: root.style.focus
            x: (box.width - width) / 2
            y: box.height - height
            color: root.accent

            Behavior on width { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: root.duration } }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            onTapped: input.forceActiveFocus()
        }

        VitrailText {
            visible: root.leadingIcon !== ""
            x: root.padX
            anchors.verticalCenter: parent.verticalCenter
            variant: "icon"
            font.pixelSize: root.iconPx
            text: root.leadingIcon
            color: root.error ? root.accent : VitrailTokens.color("muted")
        }

        VitrailText {
            visible: root.placeholder !== "" && input.length === 0
            x: root.contentX
            y: root.textY
            font.pixelSize: root.inputPx
            color: VitrailTokens.color("muted")
            opacity: root.hasLabel ? root.labelLift * 0.7 : 0.7
            text: root.placeholder
        }

        TextInput {
            id: input

            x: root.contentX
            y: root.textY
            width: root.contentWidth
            focus: true
            clip: true
            readOnly: root.readOnly
            color: root.ink
            selectionColor: VitrailTokens.color("primary")
            selectedTextColor: VitrailTokens.color("accentForeground")
            font.pixelSize: root.inputPx
            font.family: VitrailTokens.fontFamily
            // The text stays real; hidden it only fades out, and turns into
            // dots (that nobody sees) once it is gone.
            opacity: root.hidden ? 0 : 1
            echoMode: root.hidden && input.opacity === 0 ? TextInput.Password : TextInput.Normal
            inputMethodHints: root.password ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
            cursorDelegate: root.hidden ? noCaret : null
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function (event) { root.keyPressed(event) }
            Keys.onEscapePressed: root.escaped()
            onAccepted: root.accepted()
            onTextChanged: if (root.ready) root.sync()

            Behavior on opacity { NumberAnimation { duration: root.duration } }
        }

        Component {
            id: noCaret

            Item {}
        }

        // Password: one shape per character over the (invisible) input.
        Item {
            id: shapesRow

            readonly property real scroll: Math.max(0, input.cursorPosition * root.stride + caret.width - shapesRow.width)

            visible: root.password && opacity > 0
            x: root.contentX
            y: root.textY
            width: root.contentWidth
            height: input.implicitHeight
            clip: true
            opacity: root.hidden ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: root.duration } }

            ListView {
                id: list

                x: -shapesRow.scroll
                width: Math.max(shapesRow.width, shapes.count * root.stride)
                height: parent.height
                orientation: ListView.Horizontal
                interactive: false
                model: shapes

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; to: 0; duration: root.duration; easing.type: Easing.InBack }
                        NumberAnimation { property: "rotation"; to: 45; duration: root.duration; easing.type: Easing.InCubic }
                    }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x"; duration: root.duration; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: cell

                    required property string kind
                    required property int index

                    width: root.stride
                    height: list.height
                    scale: 0
                    rotation: -45

                    ParallelAnimation {
                        id: pop

                        NumberAnimation { target: cell; property: "scale"; to: 1; duration: root.duration * 1.5; easing.type: Easing.OutBack }
                        NumberAnimation { target: cell; property: "rotation"; to: 0; duration: root.duration * 1.5; easing.type: Easing.OutCubic }
                    }

                    Component.onCompleted: pop.start()

                    Rectangle {
                        anchors.centerIn: glyph
                        width: root.stride
                        height: glyph.height + VitrailTokens.gap("xs")
                        radius: height / 2
                        visible: cell.index >= input.selectionStart && cell.index < input.selectionEnd
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)
                    }

                    VitrailShape {
                        id: glyph

                        anchors.centerIn: parent
                        width: root.shapePx
                        height: root.shapePx
                        kind: cell.kind
                        fill: root.ink
                    }
                }
            }

            Rectangle {
                id: caret

                visible: root.focused && root.caretOn
                x: Math.max(0, input.cursorPosition * root.stride - VitrailTokens.gap("xs") / 2 - width / 2) - shapesRow.scroll
                y: (parent.height - height) / 2
                width: root.style.focus
                height: root.shapePx * 1.3
                radius: width / 2
                color: VitrailTokens.color("primary")

                Behavior on x { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }
            }

            TapHandler {
                enabled: root.hidden
                onTapped: function (point) {
                    var at = Math.round((point.position.x + shapesRow.scroll) / root.stride)
                    input.cursorPosition = Math.max(0, Math.min(shapes.count, at))
                    input.forceActiveFocus()
                }
            }
        }

        VitrailText {
            id: floatingLabel

            readonly property real restY: (root.boxHeight - input.implicitHeight) / 2
            readonly property real floatY: root.style.notch ? -labelMetrics.height / 2
                                                            : (root.boxHeight - labelMetrics.height - input.implicitHeight) / 2

            visible: root.hasLabel
            x: root.contentX + (root.style.notch ? Math.max(root.padX, root.radius + outline.notchPad) - root.contentX : 0) * root.labelLift
            y: restY + (floatY - restY) * root.labelLift
            width: Math.min(implicitWidth, box.width - x - root.padX)
            elide: Text.ElideRight
            font.pixelSize: Math.round(root.inputPx + (VitrailTokens.size("label") - root.inputPx) * root.labelLift)
            color: root.error || root.focused ? root.accent : VitrailTokens.color("muted")
            opacity: 1
            text: root.label

            Behavior on color { ColorAnimation { duration: root.duration } }
        }

        VitrailButton {
            id: eye

            objectName: "eye"
            visible: root.password
            anchors.right: parent.right
            anchors.rightMargin: VitrailTokens.gap("xs")
            anchors.verticalCenter: parent.verticalCenter
            variant: "plain"
            tone: "secondary"
            size: root.size
            icon: root.revealed ? "visibility_off" : "visibility"
            onClicked: {
                root.revealed = !root.revealed
                input.forceActiveFocus()
            }
        }
    }

    VitrailText {
        id: note

        visible: text !== ""
        x: root.padX
        y: box.height + VitrailTokens.gap("xs")
        width: root.width - 2 * root.padX
        variant: "label"
        wrapMode: Text.Wrap
        color: root.error ? VitrailTokens.color("error") : VitrailTokens.color("muted")
        text: root.error && root.errorText !== "" ? root.errorText : root.supportingText
    }

    ListModel {
        id: shapes
    }

    // Blinks the drawn caret; any edit or move shows it solid again.
    Timer {
        id: blink

        interval: VitrailTokens.duration("blink")
        repeat: true
        running: root.focused && shapesRow.visible
        onTriggered: root.caretOn = !root.caretOn
    }

    Connections {
        target: input

        function onCursorPositionChanged() {
            root.caretOn = true
            blink.restart()
        }
    }
}
