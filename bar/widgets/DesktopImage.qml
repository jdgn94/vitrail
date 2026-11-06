import QtQuick
import "../kit"
import "../kit/base"

// The wallpaper-library picture as a desktop widget. Three frames:
//
//   cover    the picture fills the card;
//   contain  the whole picture, letterboxed on the card's surface;
//   frame    a mat around the picture, like a mounted print.
//
// A video wallpaper cannot be an Image: the widget stays a placeholder until
// the library holds a picture.
Item {
    id: root

    objectName: "desktopImage"

    property string source: ""
    property string size: "md"
    property string variant: ""
    property var strings: ({})

    readonly property bool video: /\.(mp4|webm|mkv|mov|m4v|avi|gif)$/i.test(root.source)
    readonly property url url: root.source === "" || root.video ? "" : "file://" + root.source
    readonly property bool ready: loader.status === Image.Ready
    readonly property real pad: root.variant === "contain" ? VitrailTokens.gap("sm")
                              : (root.variant === "frame" ? VitrailTokens.gap("md") : 0)

    implicitWidth: 0
    implicitHeight: Math.round((root.width > 0 ? root.width : 340)
                               * (root.variant === "contain" ? 0.56 : 0.62))

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailSurface {
        anchors.fill: parent
        radius: VitrailTokens.radius
        tint: VitrailTokens.color("surfaceHigh", "#282a2f")

        Item {
            id: mat

            anchors.fill: parent
            anchors.margins: root.pad
            clip: true

            Image {
                id: loader

                anchors.fill: parent
                source: root.url
                asynchronous: true
                fillMode: root.variant === "contain" ? Image.PreserveAspectFit
                                                     : Image.PreserveAspectCrop
                visible: root.ready
            }

            Column {
                anchors.centerIn: parent
                visible: !root.ready
                spacing: VitrailTokens.gap("xs")

                VitrailIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "image"
                    size: root.size === "lg" ? "xl" : "lg"
                    tone: "muted"
                }

                VitrailText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "label"
                    text: root.t("panel.widget.image")
                }
            }
        }
    }
}
