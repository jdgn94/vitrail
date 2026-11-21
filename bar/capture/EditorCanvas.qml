import QtQuick
import QtQuick.Window
import "../kit"
import "editor.js" as Editor

// The editor's canvas: the picture fitted (never cropped) on a neutral
// backdrop, the elements drawn over it, and the pointer that makes new ones.
//
// Everything lives in the picture's own pixels (`scene`): the view only scales
// it, and `render` draws that same scene at the picture's native size, so what
// is exported is exactly what is shown. The pointer is turned into picture
// pixels by the view's scale, clamped to the picture.
//
// Pencil, shape and arrow are made by dragging; a text is placed by a click
// and typed in place (Enter confirms, Shift+Enter breaks the line, Escape
// cancels, a click elsewhere confirms). Each finished element is reported with
// `committed`; the owner keeps the history.
Item {
    id: root

    property string image: ""
    property real imageWidth: 1
    property real imageHeight: 1
    // The monitor's pixels per view px: 2 shows the picture one to one at half size.
    property real pixelRatio: 1
    // The elements already drawn (editor.js), oldest first.
    property var elements: []
    property string tool: "pencil"
    // The options of every tool (editor.js `options`).
    property var options: ({})
    // The view's multiplier of the fit.
    property real zoom: 1

    signal committed(var element)
    // The wheel with Ctrl held asks for a zoom step (1 in, -1 out).
    signal zoomStep(int direction)

    readonly property var editor: VitrailTokens.capture.editor
    readonly property real pad: VitrailTokens.gap("md")
    readonly property real fit: Editor.fitScale({ w: root.width - 2 * root.pad, h: root.height - 2 * root.pad },
                                                { w: root.imageWidth, h: root.imageHeight }, root.pixelRatio)
    readonly property real viewScale: root.fit * root.zoom
    // A label is being typed.
    property bool editing: false
    property var textAt: ({ x: 0, y: 0 })
    // The element being dragged, and the points of a pencil stroke.
    property var live: null
    property var stroke: []
    property var origin: ({ x: 0, y: 0 })

    readonly property var typed: root.editing ? Editor.textElement(root.editor, root.options.text, root.textAt, field.text) : null

    // A point of the picture in this item's coordinates (where to aim the pointer).
    function viewPoint(at) {
        return frame.mapToItem(root, at.x * root.viewScale, at.y * root.viewScale)
    }

    function point(mouse) {
        return Editor.clampPoint(Editor.toImage({ x: mouse.x, y: mouse.y }, root.viewScale),
                                 { w: root.imageWidth, h: root.imageHeight })
    }

    function begin(at) {
        root.origin = at
        if (root.tool === "pencil") {
            root.stroke = [at]
            root.live = Editor.penElement(root.editor, root.options.pencil, root.stroke)
        } else {
            root.live = root.shaped(at, at)
        }
    }

    function shaped(from, to) {
        return root.tool === "arrow" ? Editor.arrowElement(root.editor, root.options.arrow, from, to)
                                     : Editor.shapeElement(root.editor, root.options.shape, from, to)
    }

    function drag(at) {
        if (!root.live)
            return
        if (root.tool === "pencil") {
            root.stroke = Editor.addPoint(root.stroke, at, root.editor.drag.smooth)
            root.live = Editor.penElement(root.editor, root.options.pencil, root.stroke)
        } else {
            root.live = root.shaped(root.origin, at)
        }
    }

    function end() {
        var done = root.live
        root.live = null
        root.stroke = []
        if (done && !Editor.isEmpty(done, root.editor))
            root.committed(done)
    }

    function beginText(at) {
        field.text = ""
        root.textAt = at
        root.editing = true
        field.forceActiveFocus()
    }

    // Confirms the label being typed (an empty one is dropped).
    function finishText() {
        if (!root.editing)
            return
        var label = Editor.textElement(root.editor, root.options.text, root.textAt, field.text)
        root.cancelText()
        if (!Editor.isEmpty(label, root.editor))
            root.committed(label)
    }

    function cancelText() {
        root.editing = false
        field.text = ""
        root.forceActiveFocus()
    }

    // Draws the picture and its elements at the picture's own size into a PNG
    // file, then calls `done(true)` (or `done(false)`). A label still being
    // typed is part of it. A grab is as many pixels as its size times the
    // window's ratio, so the size asked is the picture's divided by it (one to
    // one on a whole scale; a fractional one may be a pixel off, which
    // `vitrail.capture finish --size` settles).
    function render(path, done) {
        root.finishText()
        var ratio = root.Window.window ? root.Window.window.devicePixelRatio : 1
        Qt.callLater(function () {
            var started = scene.grabToImage(function (result) {
                done(result.saveToFile(path))
            }, Qt.size(Math.round(root.imageWidth / ratio), Math.round(root.imageHeight / ratio)))
            if (!started)
                done(false)
        })
    }

    onToolChanged: root.finishText()

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius * 0.6
        color: VitrailTokens.solid("foreground", root.editor.backdrop)
    }

    Flickable {
        id: view

        anchors.fill: parent
        anchors.margins: root.pad
        clip: true
        interactive: false
        contentWidth: Math.max(width, frame.width)
        contentHeight: Math.max(height, frame.height)
        boundsBehavior: Flickable.StopAtBounds

        // The wheel scrolls a picture larger than the view; with Ctrl it zooms.
        WheelHandler {
            onWheel: function (event) {
                if (event.modifiers & Qt.ControlModifier) {
                    root.zoomStep(event.angleDelta.y > 0 ? 1 : -1)
                    return
                }
                view.contentY = Math.max(0, Math.min(view.contentHeight - view.height, view.contentY - event.angleDelta.y))
                view.contentX = Math.max(0, Math.min(view.contentWidth - view.width, view.contentX - event.angleDelta.x))
            }
        }

        Item {
            id: frame

            x: (view.contentWidth - width) / 2
            y: (view.contentHeight - height) / 2
            width: Math.round(root.imageWidth * root.viewScale)
            height: Math.round(root.imageHeight * root.viewScale)

            Item {
                // The picture's pixels, scaled for the view. The scene below is
                // never scaled itself: it is what the export draws.
                width: root.imageWidth
                height: root.imageHeight
                scale: root.viewScale
                transformOrigin: Item.TopLeft

                Item {
                    id: scene

                    anchors.fill: parent
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.image !== "" ? "file://" + root.image : ""
                        fillMode: Image.Stretch
                        smooth: true
                        mipmap: true
                        cache: false
                    }

                    Repeater {
                        model: root.elements

                        delegate: EditorElement {
                            required property var modelData

                            element: modelData
                        }
                    }

                    EditorElement {
                        element: root.live
                    }

                    EditorElement {
                        element: root.typed
                        bare: true
                    }

                    TextEdit {
                        id: field

                        visible: root.editing
                        x: root.textAt.x + Math.round(root.options.text.size * root.editor.text.pad)
                        y: root.textAt.y + Math.round(root.options.text.size * root.editor.text.pad)
                        color: root.options.text.color
                        font.pixelSize: root.options.text.size
                        font.bold: root.options.text.bold
                        font.family: VitrailTokens.fontFamily
                        selectionColor: VitrailTokens.color("primary")
                        selectedTextColor: VitrailTokens.color("accentForeground")
                        wrapMode: TextEdit.NoWrap
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Escape) {
                                root.cancelText()
                                event.accepted = true
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                       && !(event.modifiers & Qt.ShiftModifier)) {
                                root.finishText()
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            MouseArea {
                // A press that placed nothing (it confirmed the label being
                // typed) must not place a new one when released.
                property bool placing: false

                anchors.fill: parent
                cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                onPressed: function (mouse) {
                    placing = false
                    if (root.editing) {
                        root.finishText()
                        return
                    }
                    if (root.tool === "text")
                        placing = true
                    else
                        root.begin(root.point(mouse))
                }
                onPositionChanged: function (mouse) {
                    if (pressed)
                        root.drag(root.point(mouse))
                }
                onReleased: function (mouse) {
                    if (placing)
                        root.beginText(root.point(mouse))
                    else
                        root.end()
                    placing = false
                }
                onCanceled: {
                    placing = false
                    root.end()
                }
            }
        }
    }
}
