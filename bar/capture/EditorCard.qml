pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "editor.js" as Editor

// The screenshot editor: a glass card with the tools, the options of the chosen
// tool, the canvas and the footer. It holds the editing state (options and undo
// history) and reports what the user decided; the window around it saves,
// copies or closes. No Quickshell types, so it loads (and is tested) anywhere.
//
//   header   title, the picture's size, close
//   tools    pencil / text / shape / arrow, undo and redo
//   options  what the chosen tool takes (EditorOptions)
//   canvas   the picture fitted on a backdrop (EditorCanvas)
//   footer   discard, view zoom, copy, save
//
// Save and copy draw the picture and its elements at the picture's native size
// into `<image>-final.png` and say so with `rendered(path, mode)`.
FocusScope {
    id: root

    property var t: function (key) {
        return key
    }
    // The picture (a PNG file) and its size in pixels.
    property string image: ""
    property int imageWidth: 1
    property int imageHeight: 1
    // The tool to start with, and the options the last editor left (the JSON
    // text of `snapshot()`, "" for the defaults).
    property string tool: "pencil"
    property string saved: ""
    // The monitor's pixels per logical px, and the screen to size the window to.
    property real pixelRatio: 1
    property var screenSize: ({ w: 1920, h: 1080 })
    // Rendering the picture or waiting for what the window does with it.
    property bool busy: false

    // `mode` is "save" or "copy".
    signal rendered(string path, string mode)
    signal renderFailed(string mode)
    // The user left without saving, with nothing to lose or after confirming.
    signal discarded()

    readonly property var editor: VitrailTokens.capture.editor
    property var opts: Editor.options(VitrailTokens.capture.editor, "")
    property var history: Editor.history()
    property real zoom: 1
    readonly property int count: root.history.done.length
    readonly property bool dialogOpen: confirm.open || custom.open
    readonly property var windowSize: Editor.windowSize(
        { w: root.imageWidth, h: root.imageHeight }, root.pixelRatio, root.screenSize,
        { w: 2 * VitrailTokens.gap("md") + 2 * canvas.pad,
          h: column.implicitHeight + 2 * VitrailTokens.gap("md") + 2 * canvas.pad },
        root.editor.window)
    readonly property var toolRows: [
        { key: "pencil", icon: "edit", label: root.t("capture.editor.pencil"), detail: root.t("capture.editor.pencil.detail") },
        { key: "text", icon: "text_fields", label: root.t("capture.editor.text"), detail: root.t("capture.editor.text.detail") },
        { key: "shape", icon: "crop_square", label: root.t("capture.editor.shape"), detail: root.t("capture.editor.shape.detail") },
        { key: "arrow", icon: "arrow_right_alt", label: root.t("capture.editor.arrow"), detail: root.t("capture.editor.arrow.detail") }
    ]

    readonly property alias view: canvas

    implicitWidth: root.windowSize.w
    implicitHeight: root.windowSize.h
    focus: true

    Component.onCompleted: {
        root.opts = Editor.options(root.editor, root.saved)
        root.tool = Editor.toolOf(root.tool)
    }

    // The text of the options to remember (the next editor starts from them).
    function snapshot() {
        return Editor.serialize(root.opts)
    }

    function setOption(tool, key, value) {
        var next = JSON.parse(JSON.stringify(root.opts))
        next[tool][key] = value
        root.opts = next
    }

    // A colour made in the custom dialog: it joins the row and is used at once.
    function useCustom(hex) {
        var next = JSON.parse(JSON.stringify(root.opts))
        next.custom = hex
        next[root.tool].color = hex
        root.opts = next
    }

    function selectTool(name) {
        root.tool = Editor.toolOf(name)
    }

    function commit(element) {
        root.history = Editor.commit(root.history, element)
    }

    function undo() {
        canvas.finishText()
        root.history = Editor.undo(root.history)
    }

    function redo() {
        canvas.finishText()
        root.history = Editor.redo(root.history)
    }

    function zoomBy(direction) {
        root.zoom = Editor.zoomLevel(root.zoom, direction, root.editor.zoom)
    }

    function deliver(mode) {
        if (root.busy)
            return
        root.busy = true
        canvas.render(root.image.replace(/\.png$/, "") + "-final.png", function (ok) {
            if (ok) {
                root.rendered(root.image.replace(/\.png$/, "") + "-final.png", mode)
            } else {
                root.busy = false
                root.renderFailed(mode)
            }
        })
    }

    // Leaving: nothing to lose closes at once, else the user is asked.
    function requestDiscard() {
        canvas.finishText()
        if (root.count === 0)
            root.discarded()
        else
            confirm.open = true
    }

    function act(action) {
        if (action.indexOf("tool:") === 0)
            root.selectTool(action.slice(5))
        else if (action === "save" || action === "copy")
            root.deliver(action)
        else if (action === "undo")
            root.undo()
        else if (action === "redo")
            root.redo()
        else if (action === "discard")
            root.requestDiscard()
        else if (action === "zoomIn")
            root.zoomBy(1)
        else if (action === "zoomOut")
            root.zoomBy(-1)
        else if (action === "zoomFit")
            root.zoom = 1
    }

    Keys.onPressed: function (event) {
        if (root.dialogOpen)
            return
        if (canvas.editing && event.key === Qt.Key_Escape) {
            canvas.cancelText()
            event.accepted = true
            return
        }
        var action = Editor.shortcut(event.key, event.modifiers, canvas.editing)
        if (action === "")
            return
        event.accepted = true
        root.act(action)
    }

    component Rule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: VitrailTokens.color("outline")
    }

    VitrailSurface {
        anchors.fill: parent
        radius: VitrailTokens.radius
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: VitrailTokens.gap("md")
        spacing: VitrailTokens.gap("sm")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailIcon {
                icon: "edit"
                tone: "primary"
            }

            VitrailText {
                variant: "subtitle"
                text: root.t("capture.editor.title")
            }

            Item {
                Layout.fillWidth: true
            }

            VitrailText {
                variant: "label"
                text: root.imageWidth + " × " + root.imageHeight
            }

            EditorAction {
                icon: "close"
                variant: "plain"
                onClicked: root.requestDiscard()
            }
        }

        Rule {
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: root.toolRows

                delegate: EditorAction {
                    required property var modelData

                    icon: modelData.icon
                    text: modelData.label
                    highlighted: root.tool === modelData.key
                    tooltip: modelData.label
                    tooltipDetail: modelData.detail
                    onClicked: root.selectTool(modelData.key)
                }
            }

            Item {
                Layout.fillWidth: true
            }

            EditorAction {
                icon: "undo"
                available: Editor.canUndo(root.history)
                disabledWhy: root.t("capture.editor.undo.none")
                tooltip: root.t("capture.editor.undo")
                tooltipDetail: root.t("capture.editor.undo.detail")
                align: "end"
                onClicked: root.undo()
            }

            EditorAction {
                icon: "redo"
                available: Editor.canRedo(root.history)
                disabledWhy: root.t("capture.editor.redo.none")
                tooltip: root.t("capture.editor.redo")
                tooltipDetail: root.t("capture.editor.redo.detail")
                align: "end"
                onClicked: root.redo()
            }
        }

        EditorOptions {
            Layout.fillWidth: true
            t: root.t
            tool: root.tool
            values: root.opts
            onOptionChanged: function (tool, key, value) { root.setOption(tool, key, value) }
            onCustomRequested: {
                custom.start = root.opts[root.tool].color
                custom.show()
            }
        }

        EditorCanvas {
            id: canvas

            Layout.fillWidth: true
            Layout.fillHeight: true
            image: root.image
            imageWidth: root.imageWidth
            imageHeight: root.imageHeight
            pixelRatio: root.pixelRatio
            elements: root.history.done
            tool: root.tool
            options: root.opts
            zoom: root.zoom
            onCommitted: function (element) { root.commit(element) }
            onZoomStep: function (direction) { root.zoomBy(direction) }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            EditorAction {
                icon: "delete"
                text: root.t("capture.editor.discard")
                tooltip: root.t("capture.editor.discard")
                tooltipDetail: root.t("capture.editor.discard.detail")
                align: "start"
                onClicked: root.requestDiscard()
            }

            Item {
                Layout.fillWidth: true
            }

            EditorAction {
                icon: "remove"
                available: root.zoom > root.editor.zoom.min
                tooltip: root.t("capture.editor.zoom.out")
                tooltipDetail: root.t("capture.editor.zoom.out.detail")
                onClicked: root.zoomBy(-1)
            }

            VitrailText {
                Layout.preferredWidth: VitrailTokens.size("display") * 1.5
                horizontalAlignment: Text.AlignHCenter
                variant: "content"
                text: Editor.percent(canvas.viewScale, root.pixelRatio) + "%"
            }

            EditorAction {
                icon: "add"
                available: root.zoom < root.editor.zoom.max
                tooltip: root.t("capture.editor.zoom.in")
                tooltipDetail: root.t("capture.editor.zoom.in.detail")
                onClicked: root.zoomBy(1)
            }

            Item {
                Layout.fillWidth: true
            }

            EditorAction {
                icon: "content_copy"
                text: root.t("capture.editor.copy")
                variant: "outlined"
                available: !root.busy
                tooltip: root.t("capture.editor.copy")
                tooltipDetail: root.t("capture.editor.copy.detail")
                onClicked: root.deliver("copy")
            }

            EditorAction {
                icon: "save"
                text: root.t("capture.editor.save")
                variant: "flat"
                tone: "primary"
                busy: root.busy
                available: !root.busy
                tooltip: root.t("capture.editor.save")
                tooltipDetail: root.t("capture.editor.save.detail")
                align: "end"
                onClicked: root.deliver("save")
            }
        }
    }

    EditorDialog {
        id: confirm

        anchors.fill: parent
        title: root.t("capture.editor.discard.title")
        message: root.t(Editor.discardKey(root.count)).replace("%1", root.count)
        accept: root.t("capture.editor.discard")
        cancel: root.t("capture.editor.cancel")
        onAccepted: {
            confirm.open = false
            root.discarded()
        }
        onRejected: {
            confirm.open = false
            canvas.forceActiveFocus()
        }
    }

    EditorColorDialog {
        id: custom

        anchors.fill: parent
        t: root.t
        onChosen: function (hex) { root.useCustom(hex) }
        onOpenChanged: if (!custom.open) canvas.forceActiveFocus()
    }
}
