import QtQuick
import QtQuick.Effects
import ".."

// Button primitive. `variant` sets the emphasis (elevated, flat, inset,
// tonal, outlined, text, plain: see VitrailVariants.button for when to use
// each), `tone` the colour family (primary, secondary, info, error).
// Icon-only buttons are circles; disabled ones fade. A busy button swaps its
// icon (or starts its label) with a busy indicator and ignores clicks.
Item {
    id: root

    property string variant: ""
    property string tone: "primary"
    property string text: ""
    // Optional Material Symbol name, before the label.
    property string icon: ""
    // sm / md / lg / xl: label size and padding grow together.
    property string size: "md"
    // Waiting for something: shows the busy indicator, takes no clicks.
    property bool busy: false

    signal clicked()

    readonly property var style: VitrailStyle.resolve("button", root.variant)
    readonly property var family: VitrailVariants.tone[root.tone] || VitrailVariants.tone.primary
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    readonly property bool iconOnly: root.text === ""
    readonly property color tint: VitrailTokens.color(root.family.role, "#a8c7fa")
    readonly property color ink: root.style.ink === "on" ? VitrailTokens.color(root.family.on, "#002f65") : root.tint
    readonly property int duration: VitrailTokens.duration(root.style.motion)
    readonly property var scaleBySize: ({
        sm: { label: "label", icon: "body", pad: "xs" },
        md: { label: "label", icon: "subtitle", pad: "sm" },
        lg: { label: "body", icon: "title", pad: "md" },
        xl: { label: "body", icon: "display", pad: "xl" }
    })[root.size] || ({ label: "label", icon: "subtitle", pad: "sm" })
    readonly property real lift: root.style.shadow * (root.hovered && !root.pressed ? 2 : 1)

    implicitHeight: label.implicitHeight + 2 * VitrailTokens.gap(root.scaleBySize.pad)
    implicitWidth: root.iconOnly ? implicitHeight : row.implicitWidth + 2 * VitrailTokens.gap("md")
    opacity: root.enabled ? 1 : 0.45

    // Elevation: a soft shadow that grows a level under the pointer.
    RectangularShadow {
        anchors.fill: fill
        visible: root.style.shadow > 0
        radius: fill.radius
        blur: root.lift * 2
        offset.y: root.lift / 2
        color: Qt.rgba(0, 0, 0, 0.4)

        Behavior on blur { NumberAnimation { duration: root.duration } }
    }

    Rectangle {
        id: fill

        width: parent.width
        height: parent.height
        y: root.style.shadow && root.hovered && !root.pressed ? -1 : 0
        radius: height / 2
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b,
                       root.hovered || root.pressed ? root.style.hover : root.style.fill)
        border.width: root.style.border
        border.color: root.tint
        scale: root.pressed ? 0.97 : 1

        Behavior on color { ColorAnimation { duration: root.duration } }
        Behavior on scale { NumberAnimation { duration: root.duration; easing.type: Easing.OutCubic } }

        // Inset: the top edge falls into shadow, as if pressed into the plane.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.style.inset
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.32) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: VitrailTokens.gap("xs")
        opacity: root.hovered ? 1 : root.style.rest

        Behavior on opacity { NumberAnimation { duration: root.duration } }

        VitrailBusy {
            anchors.verticalCenter: parent.verticalCenter
            running: root.busy
            size: VitrailTokens.size(root.scaleBySize.icon)
            color: root.ink
        }

        VitrailIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== "" && !root.busy
            icon: root.icon
            pixelSize: VitrailTokens.size(root.scaleBySize.icon)
            color: root.ink
        }

        VitrailText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: !root.iconOnly
            variant: root.scaleBySize.label
            font.weight: Font.DemiBold
            text: root.iconOnly ? " " : root.text
            color: root.ink
            opacity: 1
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.busy
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    // Keyboard: Tab reaches it, Enter or Space presses it, and the ring shows
    // where the keyboard is.
    activeFocusOnTab: root.enabled && !root.busy
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: root.tint
        visible: root.activeFocus
    }
}
