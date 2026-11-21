import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// One editor as a layer surface: centred on the monitor the area came from
// (an unanchored layer is), above the windows, and holding the keyboard while
// it is open. It is not a toplevel because it has to be glass: Hyprland blurs
// layers by namespace (the vitrail-glass rule), not windows, and a window of the
// shell has no class of its own to float and centre by.
//
// The card edits; this window hands what it rendered to `vitrail.capture
// finish`, reports the outcome and closes when it went through. A save that
// failed keeps the window (and the work) open.
PanelWindow {
    id: root

    required property string image
    required property int imageWidth
    required property int imageHeight
    // The monitor's name; "" or unknown: the default output.
    required property string output

    property var t: function (key) {
        return key
    }
    // The tool to start with and the options the last editor left ("" for the defaults).
    property string startTool: "pencil"
    property string lastOptions: ""

    property string mode: "save"

    // `path` of the saved picture, or the size of the copied one.
    signal kept(string path)
    signal copied(string size)
    signal saveFailed()
    signal copyFailed()
    // The options to remember, as the card's JSON text.
    signal remember(string options)
    signal dismissed()

    function screenNamed(name) {
        var all = Quickshell.screens
        for (var index = 0; index < all.length; index++) {
            if (all[index].name === name)
                return all[index]
        }
        return null
    }

    function parse(text) {
        try {
            return JSON.parse(text)
        } catch (error) {
            return ({})
        }
    }

    function finished(text) {
        var document = root.parse(text)
        var ok = root.mode === "copy" ? document.copied === true : !!document.path
        if (!ok) {
            card.busy = false
            if (root.mode === "copy")
                root.copyFailed()
            else
                root.saveFailed()
            return
        }
        if (root.mode === "copy")
            root.copied(root.imageWidth + " × " + root.imageHeight)
        else
            root.kept(document.path)
        root.close()
    }

    function close() {
        root.remember(card.snapshot())
        root.dismissed()
    }

    screen: root.screenNamed(root.output)
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vitrail-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: card.forceActiveFocus()

    Process {
        id: finish

        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.finished(this.text)
        }
    }

    EditorCard {
        id: card

        anchors.fill: parent
        t: root.t
        image: root.image
        imageWidth: root.imageWidth
        imageHeight: root.imageHeight
        tool: root.startTool
        saved: root.lastOptions
        pixelRatio: root.screen ? root.screen.devicePixelRatio : 1
        screenSize: ({ w: root.screen ? root.screen.width : 1920, h: root.screen ? root.screen.height : 1080 })
        onRendered: function (path, mode) {
            root.mode = mode
            finish.exec(["python3", "-m", "vitrail.capture", "finish", path, mode === "copy" ? "--copy" : "--save",
                         "--size", root.imageWidth + "x" + root.imageHeight])
        }
        onRenderFailed: function (mode) {
            if (mode === "copy")
                root.copyFailed()
            else
                root.saveFailed()
        }
        onDiscarded: root.close()
    }
}
