import QtQuick

// The panel's widgets placed on the desktop (the player, the quick toggles and
// the notes). They are the panel's own components, so they pull in the shell's
// services (Quickshell); the desktop host loads this file only for those ids,
// which keeps the rest of the desktop free of that dependency.
Item {
    id: root

    // The DesktopWidget that placed this one: its live state and signals.
    property var host: null

    PanelWidget {
        anchors.fill: parent
        widgetId: root.host ? root.host.widgetId : ""
        size: root.host ? root.host.size : "md"
        // The player falls back to the bar's mediaStyle, as the panel does.
        style: root.host && root.host.widgetId === "media" && root.host.style === ""
               ? root.host.mediaStyle : (root.host ? root.host.style : "")
        fontFamily: root.host ? root.host.fontFamily : ""
        fontWeight: root.host ? root.host.fontWeight : ""
        italic: root.host ? root.host.italic : false
        strings: root.host ? root.host.strings : ({})
        mediaPlayer: root.host ? root.host.mediaPlayer : null
        mediaPlayers: root.host ? root.host.mediaPlayers : []
        mediaIndex: root.host ? root.host.mediaIndex : 0
        wifiOn: root.host ? root.host.wifiOn : false
        bluetoothOn: root.host ? root.host.bluetoothOn : false
        bluetoothPresent: root.host ? root.host.bluetoothPresent : false
        micMuted: root.host ? root.host.micMuted : false
        airplaneOn: root.host ? root.host.airplaneOn : false
        dnd: root.host ? root.host.dnd : false
        notes: root.host ? root.host.notes : ""
        onPlayerChosen: function (index) { if (root.host) root.host.playerChosen(index) }
        onQuickToggled: function (key) { if (root.host) root.host.quickToggled(key) }
        onNoteAdded: function (note) { if (root.host) root.host.noteAdded(note) }
        onNoteRemoved: function (index) { if (root.host) root.host.noteRemoved(index) }
    }
}
