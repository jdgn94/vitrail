import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../layouts.js" as Layouts

// The panel tab of the in-place editor. One flat list in the document's order:
// show or hide each widget, move it, and set its size, style and typography.
// It edits bar.ini `panelLayout`; every edit is one whole write, emitted as
// `committed`.
Item {
    id: root

    property var strings: ({})
    property var fonts: []
    property string layoutText: ""

    signal committed(string text)

    readonly property var doc: Layouts.effective(root.layoutText, "", null, "panel")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function meta(id) {
        return Layouts.find(id, "panel")
    }

    function labelOf(id) {
        var widget = root.meta(id)
        return root.t(widget ? widget.labelKey : id)
    }

    function setting(id) {
        return Layouts.setting(root.doc, id, "panel")
    }

    function commit(patch) {
        var text = Layouts.write(root.layoutText, "", patch, "panel")
        if (text !== null)
            root.committed(text)
    }

    function setVisible(id, visible) {
        if (visible === (root.doc.hidden.indexOf(id) < 0))
            return
        root.commit({ hidden: Layouts.toggle(root.doc.hidden, id) })
    }

    function moveWidget(id, delta) {
        root.commit({ order: Layouts.move(root.doc.order, id, delta) })
    }

    function setSize(id, size) {
        root.commit({ widgets: Layouts.configure(root.doc.widgets, id, { size: size }, "panel") })
    }

    function setStyle(id, style) {
        root.commit({ widgets: Layouts.configure(root.doc.widgets, id, { style: style }, "panel") })
    }

    function setFont(id, font) {
        root.commit({ widgets: Layouts.configure(root.doc.widgets, id, { font: font }, "panel") })
    }

    function setWeight(id, weight) {
        root.commit({ widgets: Layouts.configure(root.doc.widgets, id, { weight: weight }, "panel") })
    }

    function setItalic(id, italic) {
        root.commit({ widgets: Layouts.configure(root.doc.widgets, id, { italic: italic }, "panel") })
    }

    function fontOptions() {
        return [{ key: "", label: root.t("desktop.editor.font.inherit") }].concat(
            (root.fonts || []).map(function (family) {
                return { key: family, label: family }
            }))
    }

    function weightOptions() {
        return ["", "regular", "medium", "bold"].map(function (weight) {
            return { key: weight,
                     label: root.t("desktop.editor.weight."
                                   + (weight === "" ? "inherit" : weight)) }
        })
    }

    function sizeOptions(id) {
        var widget = root.meta(id)
        return widget ? widget.sizes.map(function (size) {
            return { key: size, label: root.t("panel.editor.size." + size) }
        }) : []
    }

    function styleOptions(id) {
        var widget = root.meta(id)
        if (!widget)
            return []
        return [{ key: "", label: root.t("panel.editor.style.default") }].concat(
            widget.styles.map(function (style) {
                return { key: style, label: root.t("panel.editor.style." + style) }
            }))
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("md")

            VitrailSurface {
                Layout.fillWidth: true
                implicitHeight: intro.implicitHeight + 2 * VitrailTokens.gap("md")
                radius: VitrailTokens.radius
                tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                opacityLevel: VitrailTokens.opacity * 0.83

                ColumnLayout {
                    id: intro

                    anchors.fill: parent
                    anchors.margins: VitrailTokens.gap("md")
                    spacing: VitrailTokens.gap("xs")

                    VitrailText {
                        variant: "subtitle"
                        text: root.t("desktop.edit.panel.widgets")
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        variant: "label"
                        color: VitrailTokens.color("muted", "#9aa0a6")
                        wrapMode: Text.WordWrap
                        text: root.t("panel.editor.help")
                    }
                }
            }

            Repeater {
                model: root.doc.order

                delegate: VitrailSurface {
                    id: card

                    required property string modelData
                    required property int index

                    readonly property var widget: root.meta(card.modelData)
                    readonly property bool shown: root.doc.hidden.indexOf(card.modelData) < 0
                    readonly property var values: root.setting(card.modelData)

                    objectName: "editorPanelCard." + card.modelData
                    Layout.fillWidth: true
                    implicitHeight: body.implicitHeight + 2 * VitrailTokens.gap("md")
                    radius: VitrailTokens.radius
                    tint: VitrailTokens.color("surfaceHigh", "#282a2f")
                    opacityLevel: VitrailTokens.opacity * 0.83

                    ColumnLayout {
                        id: body

                        anchors.fill: parent
                        anchors.margins: VitrailTokens.gap("md")
                        spacing: VitrailTokens.gap("sm")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailIcon {
                                icon: card.widget ? card.widget.icon : "widgets"
                                size: "sm"
                                tone: "secondary"
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: root.labelOf(card.modelData)
                            }

                            VitrailSwitch {
                                objectName: "editorPanelVisible." + card.modelData

                                checked: card.shown
                                onToggled: root.setVisible(card.modelData, value)
                            }

                            VitrailButton {
                                objectName: "editorPanelUp." + card.modelData

                                variant: "text"
                                icon: "arrow_upward"
                                enabled: card.index > 0
                                onClicked: root.moveWidget(card.modelData, -1)
                            }

                            VitrailButton {
                                objectName: "editorPanelDown." + card.modelData

                                variant: "text"
                                icon: "arrow_downward"
                                enabled: card.index < root.doc.order.length - 1
                                onClicked: root.moveWidget(card.modelData, 1)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                variant: "label"
                                text: root.t("panel.editor.size")
                            }

                            VitrailSegmented {
                                objectName: "editorPanelSize." + card.modelData

                                options: root.sizeOptions(card.modelData)
                                current: card.values.size
                                onSelected: root.setSize(card.modelData, key)
                            }

                            VitrailText {
                                visible: card.widget && card.widget.styles.length > 0
                                variant: "label"
                                text: root.t("panel.editor.style")
                            }

                            VitrailSegmented {
                                objectName: "editorPanelStyle." + card.modelData

                                visible: card.widget && card.widget.styles.length > 0
                                options: root.styleOptions(card.modelData)
                                current: card.values.style
                                onSelected: root.setStyle(card.modelData, key)
                            }

                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            VitrailText {
                                variant: "label"
                                text: root.t("desktop.edit.panel.typography")
                            }

                            VitrailPicker {
                                objectName: "editorPanelFont." + card.modelData

                                Layout.preferredWidth: 220
                                label: root.t("desktop.editor.font")
                                searchHint: root.t("desktop.editor.font.search")
                                current: card.values.font
                                options: root.fontOptions()
                                onSelected: root.setFont(card.modelData, key)
                            }

                            VitrailSegmented {
                                objectName: "editorPanelWeight." + card.modelData

                                options: root.weightOptions()
                                current: card.values.weight
                                onSelected: root.setWeight(card.modelData, key)
                            }

                            VitrailSwitch {
                                objectName: "editorPanelItalic." + card.modelData

                                checked: card.values.italic
                                onToggled: root.setItalic(card.modelData, value)
                            }

                            VitrailText {
                                variant: "label"
                                color: VitrailTokens.color("muted", "#9aa0a6")
                                text: root.t("desktop.editor.italic")
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
