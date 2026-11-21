pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "editor.js" as Editor

// The options of the chosen tool, one row per tool (a stack, so the bar is as
// tall as the tallest and does not jump when the tool changes). It only
// reports `optionChanged(tool, key, value)`; the owner keeps the values.
Item {
    id: root

    property var t: function (key) {
        return key
    }
    property string tool: "pencil"
    // The options of every tool (editor.js `options`), `custom` included.
    property var values: ({})

    signal optionChanged(string tool, string key, var value)
    signal customRequested()

    readonly property var editor: VitrailTokens.capture.editor

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    // A caption over the control it names.
    component Group: ColumnLayout {
        id: group

        property string caption: ""
        default property alias body: holder.data

        spacing: VitrailTokens.gap("xs")
        Layout.alignment: Qt.AlignVCenter

        VitrailText {
            variant: "label"
            text: group.caption
        }

        RowLayout {
            id: holder

            spacing: VitrailTokens.gap("xs")
        }
    }

    component ColorGroup: Group {
        id: group

        property string toolName: ""

        caption: root.t("capture.editor.color")

        EditorSwatches {
            t: root.t
            current: root.values[group.toolName].color
            custom: root.values.custom
            onPicked: function (hex) { root.optionChanged(group.toolName, "color", hex) }
            onCustomRequested: root.customRequested()
        }
    }

    component WidthSlider: VitrailSlider {
        id: slider

        property string toolName: ""
        property var range: ({ min: 1, max: 10, step: 1 })

        Layout.preferredWidth: root.editor.slider
        Layout.maximumWidth: root.editor.slider
        Layout.alignment: Qt.AlignVCenter
        size: "sm"
        label: root.t("capture.editor.width")
        from: slider.range.min
        to: slider.range.max
        stepSize: slider.range.step
        snap: true
        value: root.values[slider.toolName].width
        onMoved: function (value) { root.optionChanged(slider.toolName, "width", value) }
    }

    StackLayout {
        id: stack

        anchors.fill: parent
        currentIndex: Math.max(0, Editor.tools.map(function (one) { return one.key }).indexOf(root.tool))

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            ColorGroup {
                toolName: "pencil"
            }

            WidthSlider {
                toolName: "pencil"
                range: root.editor.pen.width
            }

            VitrailSlider {
                Layout.preferredWidth: root.editor.slider
                Layout.maximumWidth: root.editor.slider
                Layout.alignment: Qt.AlignVCenter
                size: "sm"
                label: root.t("capture.editor.opacity")
                suffix: "%"
                from: root.editor.pen.opacity.min * 100
                to: root.editor.pen.opacity.max * 100
                stepSize: root.editor.pen.opacity.step * 100
                snap: true
                value: root.values.pencil.opacity * 100
                onMoved: function (value) { root.optionChanged("pencil", "opacity", value / 100) }
            }

            Group {
                caption: root.t("capture.editor.mode")

                VitrailSegmented {
                    options: [
                        { key: "normal", label: root.t("capture.editor.mode.normal") },
                        { key: "highlighter", label: root.t("capture.editor.mode.highlighter") }
                    ]
                    current: root.values.pencil.mode
                    onSelected: function (key) { root.optionChanged("pencil", "mode", key) }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            ColorGroup {
                toolName: "text"
            }

            Group {
                caption: root.t("capture.editor.size")

                EditorAction {
                    icon: "remove"
                    tooltip: root.t("capture.editor.size.smaller")
                    onClicked: root.optionChanged("text", "size",
                                                  Math.max(root.editor.text.size.min,
                                                           root.values.text.size - root.editor.text.size.step))
                }

                VitrailText {
                    Layout.preferredWidth: VitrailTokens.size("display")
                    horizontalAlignment: Text.AlignHCenter
                    variant: "body"
                    text: String(root.values.text.size)
                }

                EditorAction {
                    icon: "add"
                    tooltip: root.t("capture.editor.size.larger")
                    onClicked: root.optionChanged("text", "size",
                                                  Math.min(root.editor.text.size.max,
                                                           root.values.text.size + root.editor.text.size.step))
                }
            }

            Group {
                caption: root.t("capture.editor.style")

                EditorAction {
                    icon: "format_bold"
                    text: root.t("capture.editor.bold")
                    highlighted: root.values.text.bold
                    tooltip: root.t("capture.editor.bold")
                    tooltipDetail: root.t("capture.editor.bold.detail")
                    onClicked: root.optionChanged("text", "bold", !root.values.text.bold)
                }
            }

            Group {
                caption: root.t("capture.editor.background")

                VitrailSegmented {
                    options: [
                        { key: "none", label: root.t("capture.editor.none") },
                        { key: "solid", label: root.t("capture.editor.solid") }
                    ]
                    current: root.values.text.background
                    onSelected: function (key) { root.optionChanged("text", "background", key) }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            Group {
                caption: root.t("capture.editor.shape")

                VitrailSegmented {
                    options: [
                        { key: "rect", label: root.t("capture.editor.shape.rect"), icon: "crop_square" },
                        { key: "ellipse", label: root.t("capture.editor.shape.ellipse"), icon: "circle" }
                    ]
                    current: root.values.shape.kind
                    onSelected: function (key) { root.optionChanged("shape", "kind", key) }
                }
            }

            ColorGroup {
                toolName: "shape"
            }

            WidthSlider {
                toolName: "shape"
                range: root.editor.shape.width
            }

            Group {
                caption: root.t("capture.editor.fill")

                VitrailSegmented {
                    options: [
                        { key: "none", label: root.t("capture.editor.none") },
                        { key: "solid", label: root.t("capture.editor.solid") },
                        { key: "translucent", label: root.t("capture.editor.translucent") }
                    ]
                    current: root.values.shape.fill
                    onSelected: function (key) { root.optionChanged("shape", "fill", key) }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: VitrailTokens.gap("lg")

            ColorGroup {
                toolName: "arrow"
            }

            WidthSlider {
                toolName: "arrow"
                range: root.editor.arrow.width
            }

            Group {
                caption: root.t("capture.editor.heads")

                VitrailSegmented {
                    options: [
                        { key: "one", icon: "arrow_right_alt" },
                        { key: "both", icon: "arrow_range" }
                    ]
                    current: root.values.arrow.heads
                    onSelected: function (key) { root.optionChanged("arrow", "heads", key) }
                }
            }

            Group {
                caption: root.t("capture.editor.line")

                VitrailSegmented {
                    options: [
                        { key: "solid", label: root.t("capture.editor.line.solid") },
                        { key: "dashed", label: root.t("capture.editor.line.dashed") }
                    ]
                    current: root.values.arrow.line
                    onSelected: function (key) { root.optionChanged("arrow", "line", key) }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
}
