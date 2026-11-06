import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// One presentation of the launcher (`variant`: popout or fullscreen), drawn
// with the real tokens and kit components but made-up apps, because the real
// content needs the shell's desktop entries. Shown at `zoom` of its size.
Item {
    id: root

    property string variant: "popout"
    property real zoom: 0.5
    readonly property var style: VitrailStyle.resolve("launcher", root.variant)
    readonly property var metrics: VitrailTokens.launcher[root.style.metrics]
    readonly property bool fullscreen: root.style.fill
    readonly property size full: root.fullscreen ? Qt.size(1280, 720) : Qt.size(root.metrics.width, root.metrics.height)
    readonly property real edge: VitrailTokens.gap(root.style.gap) * root.metrics.margin
    readonly property real contentWidth: root.fullscreen ? Math.min(root.full.width - 2 * root.edge, root.metrics.content) : root.full.width
    readonly property int columns: Math.max(root.metrics.columns, Math.floor(root.contentWidth / root.metrics.tileMin))
    readonly property var apps: [
        { name: "Firefox", icon: "language" }, { name: "Terminal emulator", icon: "terminal" },
        { name: "Files", icon: "folder" }, { name: "Image editor", icon: "brush" },
        { name: "Music player", icon: "music_note" }, { name: "Settings", icon: "settings" },
        { name: "Calculator", icon: "calculate" }, { name: "Text editor", icon: "edit_note" },
        { name: "Video player", icon: "movie" }, { name: "Mail", icon: "mail" },
        { name: "Calendar", icon: "calendar_month" }, { name: "System monitor", icon: "monitoring" }
    ]

    implicitWidth: root.full.width * root.zoom
    implicitHeight: root.full.height * root.zoom

    Item {
        width: root.full.width
        height: root.full.height
        scale: root.zoom
        transformOrigin: Item.TopLeft

        VitrailSurface {
            anchors.fill: parent
            radius: root.fullscreen ? 0 : VitrailTokens.radius
            tint: VitrailTokens.color("surface")
            opacityLevel: VitrailTokens.opacity
        }

        ColumnLayout {
            x: (parent.width - root.contentWidth) / 2
            y: root.edge + (root.fullscreen ? 0 : VitrailTokens.gap("md"))
            width: root.contentWidth - (root.fullscreen ? 0 : 2 * VitrailTokens.gap("md"))
            spacing: VitrailTokens.gap(root.style.gap)

            VitrailField {
                Layout.fillWidth: true
                Layout.maximumWidth: root.metrics.narrow > 0 ? root.metrics.narrow : 100000
                Layout.alignment: Qt.AlignHCenter
                size: root.style.field
                leadingIcon: "search"
                placeholder: "Search apps"
            }

            VitrailTabs {
                Layout.fillWidth: true
                tabs: [{ key: "all", label: "All" }, { key: "dev", label: "Development" }, { key: "net", label: "Internet" }, { key: "sys", label: "System" }]
                current: "all"
            }

            Flow {
                Layout.fillWidth: true

                Repeater {
                    model: root.apps

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        width: Math.floor(root.contentWidth / root.columns) - (root.fullscreen ? 0 : 0)
                        height: art.height + label.implicitHeight + 3 * VitrailTokens.gap("sm")

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: VitrailTokens.gap("xs") / 2
                            radius: VitrailTokens.radius / 2
                            color: VitrailTokens.color("primary")
                            opacity: cell.index === 0 ? 0.16 : 0
                        }

                        Rectangle {
                            id: art

                            anchors.top: parent.top
                            anchors.topMargin: VitrailTokens.gap("sm")
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.metrics.tileIcon
                            height: width
                            radius: width / 4
                            color: VitrailTokens.color("primary")
                            opacity: 0.25

                            VitrailText {
                                anchors.centerIn: parent
                                variant: "icon"
                                font.pixelSize: art.width * 0.6
                                icon: cell.modelData.icon
                                color: VitrailTokens.color("primary")
                            }
                        }

                        VitrailText {
                            id: label

                            anchors.top: art.bottom
                            anchors.topMargin: VitrailTokens.gap("sm")
                            anchors.left: parent.left
                            anchors.right: parent.right
                            horizontalAlignment: Text.AlignHCenter
                            variant: root.style.label
                            color: VitrailTokens.color("foreground")
                            opacity: 1
                            wrapMode: root.style.lines > 1 ? Text.Wrap : Text.NoWrap
                            maximumLineCount: root.style.lines
                            elide: Text.ElideRight
                            text: cell.modelData.name
                        }
                    }
                }
            }
        }
    }
}
