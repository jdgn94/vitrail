import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "capture.js" as Capture

// The result card of a capture action that answers in place: a translation,
// the content of a QR code or the palette of the area's main colours. It takes
// the toolbar's seat, shows a busy indicator while it waits, an error when it
// failed, and otherwise the text with buttons to copy it and, for a web link,
// to open it; the palette is a grid of swatches (a click takes one) and its
// copy button takes them all. Escape or the close button return to the toolbar.
Item {
    id: root

    property var t: function (key) {
        return key
    }
    // "translate" | "qr" | "palette"
    property string kind: "translate"
    // "loading" | "done" | "error" (not `state`: Item already has one)
    property string phase: "loading"
    property string text: ""
    // Set for a QR code that is a web link.
    property string url: ""
    // The palette's colours, most used first: [{ hex, share }].
    property var colors: []
    // What went wrong, already in the user's language.
    property string message: ""
    // A line under the title ("Copied" for a code, the language for a translation).
    property string note: ""

    signal copyRequested(string text)
    signal openRequested(string url)
    signal colorRequested(string hex)
    signal colorsRequested()
    signal closed()

    readonly property string icon: root.kind === "qr" ? "qr_code_2" : root.kind === "palette" ? "palette" : "translate"
    readonly property bool done: root.phase === "done"
    readonly property bool swatches: root.kind === "palette"

    implicitWidth: card.width
    implicitHeight: card.height

    component Tip: Item {
        id: tip

        property string icon: ""
        property string tooltip: ""

        signal clicked()

        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight

        VitrailButton {
            id: button

            anchors.fill: parent
            variant: "text"
            tone: "secondary"
            size: "sm"
            icon: tip.icon
            onClicked: tip.clicked()
        }

        VitrailTooltip {
            text: tip.tooltip
            active: button.hovered
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: VitrailTokens.gap("xs")
        }
    }

    VitrailSurface {
        id: card

        anchors.centerIn: parent
        width: VitrailTokens.capture.card.width
        height: body.implicitHeight + 2 * VitrailTokens.gap("sm")
        radius: VitrailTokens.radius

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: VitrailTokens.gap("sm")
            spacing: VitrailTokens.gap("xs")

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("xs")

                VitrailIcon {
                    icon: root.icon
                    size: "md"
                    tone: "primary"
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.note
                }

                Tip {
                    visible: root.done
                    icon: "content_copy"
                    tooltip: root.t(root.swatches ? "capture.palette.copyAll" : "capture.card.copy")
                    onClicked: root.swatches ? root.colorsRequested() : root.copyRequested(root.text)
                }

                Tip {
                    visible: root.done && root.url !== ""
                    icon: "open_in_new"
                    tooltip: root.t("capture.card.open")
                    onClicked: root.openRequested(root.url)
                }

                Tip {
                    icon: "close"
                    tooltip: root.t("capture.card.close")
                    onClicked: root.closed()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.phase === "loading"
                spacing: VitrailTokens.gap("sm")

                VitrailBusy {
                    running: root.phase === "loading"
                    size: VitrailTokens.size("subtitle")
                }

                VitrailText {
                    variant: "body"
                    text: root.message
                }
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.phase === "error"
                variant: "body"
                color: VitrailTokens.color("error")
                wrapMode: Text.WordWrap
                text: root.message
            }

            GridLayout {
                id: grid

                Layout.fillWidth: true
                visible: root.done && root.swatches
                columns: VitrailTokens.capture.card.swatch.columns
                uniformCellWidths: true
                rowSpacing: VitrailTokens.gap("sm")
                columnSpacing: VitrailTokens.gap("xs")

                Repeater {
                    model: root.swatches ? root.colors : []

                    delegate: Item {
                        id: tile

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: column.implicitHeight

                        HoverHandler {
                            id: hover
                        }

                        TapHandler {
                            onTapped: root.colorRequested(tile.modelData.hex)
                        }

                        ColumnLayout {
                            id: column

                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: VitrailTokens.gap("xs")

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: VitrailTokens.capture.card.swatch.height
                                radius: VitrailTokens.gap("sm")
                                color: tile.modelData.hex
                                border.width: hover.hovered ? VitrailTokens.capture.border : 1
                                border.color: hover.hovered ? VitrailTokens.color("primary")
                                    : Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                              VitrailTokens.color("foreground").b, VitrailTokens.capture.card.swatch.edge)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: VitrailTokens.gap("xs")

                                VitrailText {
                                    Layout.fillWidth: true
                                    variant: "label"
                                    elide: Text.ElideRight
                                    text: tile.modelData.hex
                                }

                                VitrailText {
                                    variant: "label"
                                    opacity: 0.7
                                    text: Capture.shareLabel(tile.modelData.share)
                                }
                            }
                        }

                        VitrailTooltip {
                            text: root.t("capture.palette.copy")
                            detail: tile.modelData.hex
                            active: hover.hovered
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: VitrailTokens.gap("xs")
                        }
                    }
                }
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.done && !root.swatches
                variant: "body"
                wrapMode: Text.WordWrap
                maximumLineCount: VitrailTokens.capture.card.lines
                elide: Text.ElideRight
                text: root.text
            }
        }
    }
}
