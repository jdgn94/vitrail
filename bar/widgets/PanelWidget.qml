import QtQuick
import "../capture"
import "../media"
import "../notes"
import "../session"
import "../toggles"

// One widget of the notification panel, chosen by id from the shared registry
// (bar/widgets.js). The panel document says which ids to draw, in which order,
// with which size and style (bar/layouts.js); this host resolves those to the
// real widget and hands it its live state. No widget is duplicated here.
Item {
    id: root

    property string widgetId: ""
    // sm / md / lg, as the registry lists for the widget; "md" is today's look.
    property string size: "md"
    // The widget's look; empty means the widget's own default (the player uses
    // the bar's mediaStyle preference).
    property string style: ""
    // The widget's own typography (bar/layouts.js); empty values inherit.
    property string fontFamily: ""
    property string fontWeight: ""
    property bool italic: false
    property var strings: ({})

    // The player.
    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0

    // The quick toggles' state.
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool airplaneOn: false
    property bool dnd: false

    // The notes and the capture row.
    property string notes: ""
    property bool recording: false

    signal playerChosen(int index)
    signal quickToggled(string key)
    signal shotRequested(string mode)
    signal recordRequested()
    signal noteAdded(string note)
    signal noteRemoved(int index)
    signal sessionRequested(string key)

    // The player has nothing to say when nothing is playing: the panel leaves
    // its slot out, like today's fixed widget.
    visible: root.widgetId !== "media" || root.mediaPlayer !== null

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader

        width: root.width
        height: root.height
        sourceComponent: root.widgetId === "media" ? mediaWidget
                       : root.widgetId === "toggles" ? togglesWidget
                       : root.widgetId === "capture" ? captureWidget
                       : root.widgetId === "notes" ? notesWidget
                       : root.widgetId === "session" ? sessionWidget
                       : null
    }

    Component {
        id: mediaWidget

        MediaPanel {
            width: loader.width
            height: loader.height
            size: root.size
            fontFamily: root.fontFamily
            fontWeight: root.fontWeight
            italic: root.italic
            style: root.style
            player: root.mediaPlayer
            players: root.mediaPlayers
            index: root.mediaIndex
            strings: root.strings
            onPlayerChosen: function (index) { root.playerChosen(index) }
        }
    }

    Component {
        id: togglesWidget

        QuickToggles {
            width: loader.width
            height: loader.height
            size: root.size
            fontFamily: root.fontFamily
            fontWeight: root.fontWeight
            italic: root.italic
            wifiOn: root.wifiOn
            bluetoothOn: root.bluetoothOn
            bluetoothPresent: root.bluetoothPresent
            micMuted: root.micMuted
            airplaneOn: root.airplaneOn
            dnd: root.dnd
            onToggled: function (key) { root.quickToggled(key) }
        }
    }

    Component {
        id: captureWidget

        CaptureRow {
            width: loader.width
            height: loader.height
            size: root.size
            recording: root.recording
            onShotRequested: function (mode) { root.shotRequested(mode) }
            onRecordRequested: root.recordRequested()
        }
    }

    Component {
        id: notesWidget

        QuickNotes {
            width: loader.width
            height: loader.height
            size: root.size
            fontFamily: root.fontFamily
            fontWeight: root.fontWeight
            italic: root.italic
            strings: root.strings
            text: root.notes
            onNoteAdded: function (note) { root.noteAdded(note) }
            onNoteRemoved: function (index) { root.noteRemoved(index) }
        }
    }

    Component {
        id: sessionWidget

        SessionRow {
            width: loader.width
            height: loader.height
            size: root.size
            onChosen: function (key) { root.sessionRequested(key) }
        }
    }
}
