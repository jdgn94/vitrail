import Quickshell
import Quickshell.Wayland
import QtQuick
import "../layouts.js" as Layouts
import "../widgets"

// The desktop's widget layer of one monitor. Every placed widget is its own
// small background window: the desktop itself stays transparent and takes no
// clicks, while an interactive widget (the player, the clock widgets, the
// toggles, the notes, the calendar) accepts input only inside its own rect.
//
// The document (bar.ini `desktopLayout`, bar → Editor) stores a point per
// widget from 0 to 1 of the monitor. An empty document draws nothing.
Scope {
    id: root

    required property var screen
    property string monitor: ""
    property string layoutText: ""
    // The bar's fullscreen switch (`hideFullscreen`) may take the widgets away
    // with the bar and the frame.
    property bool hiddenFullscreen: false
    property var strings: ({})
    property string language: "en"

    property var weather: ({})
    property var resources: ({})
    property var timerEngine: null

    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0
    property string mediaStyle: "disc"

    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool airplaneOn: false
    property bool dnd: false
    property string notes: ""
    // The image widget's picture: the wallpaper the library chose.
    property string imageSource: ""

    property date now: new Date()

    signal playerChosen(int index)
    signal quickToggled(string key)
    signal noteAdded(string note)
    signal noteRemoved(int index)

    readonly property var document: Layouts.effective(root.layoutText, root.monitor, null, "desktop")
    readonly property var placed: root.document.widgets

    // The clock and the calendar tick; the services update on their own.
    Timer {
        interval: 1000
        repeat: true
        running: root.placed.length > 0 && !root.hiddenFullscreen
        onTriggered: root.now = new Date()
    }

    Variants {
        model: root.placed

        delegate: Component {
            PanelWindow {
                id: window

                required property var modelData

                readonly property var widget: Layouts.find(window.modelData.id, "desktop")
                readonly property bool interactive: window.widget ? window.widget.interactive === true : false
                readonly property int marginX: Math.max(0, Math.min(root.screen.width - host.implicitWidth,
                                                                    Math.round(window.modelData.x * root.screen.width)))
                readonly property int marginY: Math.max(0, Math.min(root.screen.height - host.implicitHeight,
                                                                    Math.round(window.modelData.y * root.screen.height)))

                screen: root.screen
                visible: root.placed.length > 0 && !root.hiddenFullscreen
                color: "transparent"
                implicitWidth: host.implicitWidth
                implicitHeight: host.implicitHeight
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "vitrail-wallpaper"
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors {
                    top: true
                    left: true
                }
                margins.top: window.marginY
                margins.left: window.marginX
                // Only an interactive widget takes the pointer; every other
                // pixel of the background belongs to the desktop.
                mask: Region { item: window.interactive ? host : null }

                DesktopWidget {
                    id: host

                    width: window.width
                    height: window.height
                    widgetId: window.modelData.id
                    size: window.modelData.size
                    style: window.modelData.style
                    fontFamily: window.modelData.font
                    fontWeight: window.modelData.weight
                    italic: window.modelData.italic
                    strings: root.strings
                    now: root.now
                    language: root.language
                    weather: root.weather
                    readings: root.resources
                    timerEngine: root.timerEngine
                    mediaPlayer: root.mediaPlayer
                    mediaPlayers: root.mediaPlayers
                    mediaIndex: root.mediaIndex
                    mediaStyle: root.mediaStyle
                    wifiOn: root.wifiOn
                    bluetoothOn: root.bluetoothOn
                    bluetoothPresent: root.bluetoothPresent
                    micMuted: root.micMuted
                    airplaneOn: root.airplaneOn
                    dnd: root.dnd
                    notes: root.notes
                    imageSource: root.imageSource
                    onPlayerChosen: function (index) { root.playerChosen(index) }
                    onQuickToggled: function (key) { root.quickToggled(key) }
                    onNoteAdded: function (note) { root.noteAdded(note) }
                    onNoteRemoved: function (index) { root.noteRemoved(index) }
                }
            }
        }
    }
}
