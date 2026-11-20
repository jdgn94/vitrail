import QtQuick
import "../kit"
import "../kit/base"
import "rich.js" as Rich

// The hover card of a clipboard entry: the copied text with the style of its
// source (rich text, reduced to what Qt draws), the plain text, or the image.
// It is drawn beside the panel, on the same glass surface, and fades in and
// out like a tooltip. Text copied for a light page (dark ink) sits on a light
// patch of the theme and the other way round, so a source's colours stay
// readable on the dark card.
Item {
    id: root

    // { kind: "text", text, html } or { kind: "image" }; null shows nothing.
    property var preview: null
    // The image's file (kind "image").
    property string image: ""
    property bool shown: false

    readonly property var look: VitrailTokens.clipboard.preview
    readonly property bool rich: root.preview !== null && root.preview.kind === "text" && !!root.preview.html
    readonly property string markup: root.rich ? Rich.fit(root.preview.html, root.look.maxFont) : ""
    readonly property string paper: root.rich ? Rich.backdrop(root.preview.html) : ""
    readonly property bool isImage: root.preview !== null && root.preview.kind === "image"
    readonly property real pad: VitrailTokens.gap("md")
    // The theme's two ends: the lighter of foreground and surface is the light page.
    readonly property color bright: VitrailTokens.color("foreground", "#ffffff")
    readonly property color deep: VitrailTokens.color("surface", "#000000")
    readonly property color lightPaper: root.bright.hslLightness > root.deep.hslLightness ? root.bright : root.deep
    readonly property color darkPaper: root.bright.hslLightness > root.deep.hslLightness ? root.deep : root.bright

    // The colour of text that sets none: the ink of the page it was written for.
    readonly property color ink: root.paper === "light" ? root.darkPaper
        : (root.paper === "dark" ? root.lightPaper : root.bright)

    implicitWidth: root.look.width
    implicitHeight: Math.min(root.look.height, body.implicitHeight + 2 * root.pad)
    width: implicitWidth
    height: implicitHeight
    opacity: root.shown && root.preview !== null ? 1 : 0
    visible: root.opacity > 0
    scale: root.shown ? 1 : VitrailTokens.motion.smooth.scale

    Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    Behavior on scale { NumberAnimation { duration: VitrailTokens.duration("fast"); easing.type: Easing.OutCubic } }

    VitrailSurface {
        anchors.fill: parent
        radius: VitrailTokens.radius
        style: VitrailTokens.surfaceMode
        tint: VitrailTokens.color("surface")
        opacityLevel: VitrailTokens.opacity
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.pad
        clip: true

        Column {
            id: body

            width: parent.width

            // The copy's own page: only when its colours need one.
            Rectangle {
                width: parent.width
                height: rich.implicitHeight + 2 * VitrailTokens.gap("sm")
                visible: root.rich
                radius: VitrailTokens.gap("sm")
                color: root.paper === "light" ? root.lightPaper : (root.paper === "dark" ? root.darkPaper : "transparent")

                VitrailText {
                    id: rich

                    x: VitrailTokens.gap("sm")
                    y: VitrailTokens.gap("sm")
                    width: parent.width - 2 * VitrailTokens.gap("sm")
                    variant: "content"
                    // Text that sets no colour takes the ink of its page.
                    color: root.ink
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.look.lines
                    elide: Text.ElideRight
                    text: root.markup
                }
            }

            VitrailText {
                width: parent.width
                visible: root.preview !== null && root.preview.kind === "text" && !root.rich
                variant: "content"
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                maximumLineCount: root.look.lines
                elide: Text.ElideRight
                text: root.preview && root.preview.kind === "text" ? root.preview.text : ""
            }

            Image {
                width: parent.width
                height: Math.min(root.look.height - 2 * root.pad, implicitHeight * width / Math.max(1, implicitWidth))
                visible: root.isImage && root.image !== ""
                source: root.isImage ? root.image : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: root.look.width * 2
            }
        }
    }
}
