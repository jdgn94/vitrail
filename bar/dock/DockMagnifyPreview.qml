import QtQuick
import "../kit"
import "../kit/base"
import "dock.js" as Dock

// A live strip of dock icons for the Dock settings: the pointer over one icon
// shows exactly the falloff the real dock will draw. The strip is not part of
// the bar; it exists to make the two magnification styles legible.
Item {
    id: root

    property string style: "planet"
    property int range: VitrailTokens.dock.magnify.range
    property real factor: VitrailTokens.dock.magnify.scale
    property int hoveredIndex: -1

    readonly property var glyphs: ["apps", "terminal", "folder", "image", "language"]
    readonly property real cell: VitrailTokens.size("title") + VitrailTokens.gap("sm")

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        spacing: VitrailTokens.gap("xs")

        Repeater {
            model: root.glyphs.length

            delegate: Item {
                id: preview

                required property int index

                readonly property var effect: Dock.magnify(root.style,
                                                            Math.abs(preview.index - root.hoveredIndex),
                                                            { range: root.range, scale: root.factor })

                width: root.cell
                height: root.cell

                HoverHandler {
                    id: hover

                    onHoveredChanged: {
                        if (hover.hovered)
                            root.hoveredIndex = preview.index
                        else if (root.hoveredIndex === preview.index)
                            root.hoveredIndex = -1
                    }
                }

                VitrailIcon {
                    anchors.centerIn: parent
                    icon: root.glyphs[preview.index]
                    pixelSize: root.cell * 0.62
                    color: VitrailTokens.color("primary", "#a8c7fa")
                    scale: preview.effect.scale

                    Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
