import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../kit/composed"
import "../kit/frame.js" as Frame
import "../osd"
import "../osd/osd.js" as Osd
import "../session"
import "../notes"
import "../media"
import "../toggles"

// The notification panel of one monitor: full height on the notification side,
// built like the OSD. The panel stays on the monitor it was opened on (`pinned`)
// until it is opened on another one; every monitor keeps its hot zone, so the
// pointer can move it.
//
// - An invisible hot zone glued to that edge (the frame border + `osd.hot`
//   thick, as long as the panel) opens the panel once the pointer has stayed
//   in it for `motion.dwell` ms (`openRequested`); the panel asks to close
//   `osd.hide` ms after the pointer leaves the zone and the panel
//   (`closeRequested`). An IPC opening stays until the pointer has been in
//   and left, or IPC closes it. Only the zone and the open panel take input.
// - Docked, the panel is a tab of the frame (`tabs`, for VitrailBar.tabs); a
//   floating bar gets an island. Both open like the popups (VitrailLiquid).
// - `widgets` is the slot of the panel for the widgets that come later.
Scope {
    id: root

    required property var screen
    // This monitor's Frame.layout and whether its bar is docked to the frame.
    property var layout: ({ edge: "left", hole: { left: 0, top: 0, right: 0, bottom: 0 },
                            dock: { left: 0, top: 0, right: 0, bottom: 0 },
                            reserve: { left: 0, top: 0, right: 0, bottom: 0 } })
    property bool docked: true
    property string side: "right"
    // Wanted open by the shell, and whether this monitor may show it at all
    // (not a fullscreen workspace: it may not).
    property bool open: false
    property bool active: true
    // The panel belongs to this monitor: the shell pins it where it was opened.
    property bool pinned: true
    property var queue
    property var strings: ({})
    property bool dnd: false
    // The quick-notes widget's text.
    property string notes: ""
    // The player the panel's mini player follows.
    property var mediaPlayer: null
    // The quick toggles' state.
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool bluetoothPresent: false
    property bool micMuted: false
    property bool airplaneOn: false
    property string mediaStyle: "disc"
    property var mediaPlayers: []
    property int mediaIndex: 0
    property real opacityLevel: VitrailTokens.opacity
    // Previews pin a state without timers or hover.
    property bool animated: true

    default property alias widgets: panel.widgets

    signal openRequested()
    signal closeRequested()
    signal dndToggled()
    signal sessionRequested(string key)
    signal noteAdded(string note)
    signal noteRemoved(int index)
    signal quickToggled(string key)

    readonly property var bounds: root.docked ? root.layout.dock : root.layout.reserve
    readonly property bool touching: stripHover.hovered || panelHover.hovered
    readonly property real gap: root.docked ? 0 : VitrailTokens.gap("md")

    // The frame tab of the panel, for a docked bar's VitrailBar.tabs.
    readonly property var tab: root.docked && root.active && root.pinned && liquid.shown && holder.width > 0 ? {
        edge: root.side,
        reveal: liquid.look.reveal,
        swell: liquid.look.swell,
        rect: Frame.liquidRect(Qt.rect(holder.x, holder.y, holder.width, holder.height), root.side, null,
                               liquid.look.spread, 0, 0)
    } : null
    readonly property var tabs: root.tab ? [root.tab] : []

    onTouchingChanged: {
        if (root.touching)
            hideTimer.stop()
        else if (root.open && root.animated)
            hideTimer.restart()
    }

    onOpenChanged: if (!root.open) hideTimer.stop()

    // The panel moved to another monitor: this one stops counting down, so it
    // does not close the panel there.
    onPinnedChanged: if (!root.pinned) hideTimer.stop()

    DwellGate {
        id: dwell

        hovered: stripHover.hovered
        interval: VitrailTokens.motion.dwell
        onReadyChanged: if (dwell.ready) root.openRequested()
    }

    // Leaving the zone and the panel closes it after a grace; the count starts
    // only when the pointer leaves, so an IPC opening stays until the pointer
    // has been in and left (or IPC closes it).
    Timer {
        id: hideTimer

        interval: VitrailTokens.osd.hide
        // A content change can make the hover flicker: never close under the
        // pointer, only once it has really left.
        onTriggered: if (root.pinned && !root.touching) root.closeRequested()
    }

    VitrailLiquid {
        id: liquid

        animated: root.animated
        open: root.open && root.active && root.pinned
    }

    PanelWindow {
        id: window

        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.active
        WlrLayershell.namespace: "vitrail-notification-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        // The quick-notes field is typed into: it takes the keyboard on click.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // Only the hot zone and the open panel take the pointer.
        mask: Region {
            item: strip

            Region { item: liquid.shown ? holder : null }
        }

        // The invisible hot zone on the notification side.
        Item {
            id: strip

            readonly property var zone: Osd.hotZone(root.side, window.width, window.height, holder.rect,
                                                    root.layout.hole[root.side], VitrailTokens.osd.hot)

            x: strip.zone.x
            y: strip.zone.y
            width: strip.zone.width
            height: strip.zone.height

            HoverHandler {
                id: stripHover

                enabled: root.animated
            }
        }

        // A floating bar gets an island; docked, the frame draws the tab.
        VitrailLiquidSkin {
            anchors.fill: parent
            visible: !root.docked
            edge: root.side
            rect: Qt.rect(holder.x, holder.y, holder.width, holder.height)
            origin: null
            source: null
            look: liquid.look
            gap: VitrailTokens.gap("md")
            opacityLevel: root.opacityLevel
        }

        Item {
            id: holder

            // Full height on its side, as deep as the panel token.
            readonly property var rect: Osd.panelRect(root.side, window.width, window.height,
                { width: VitrailTokens.panel,
                  height: window.height - root.bounds.top - root.bounds.bottom - 2 * root.gap },
                root.bounds, root.gap)

            visible: liquid.shown
            x: holder.rect.x
            y: holder.rect.y
            width: holder.rect.width
            height: holder.rect.height
            clip: true

            HoverHandler {
                id: panelHover

                enabled: root.animated
            }

            NotificationPanel {
                id: panel

                x: VitrailTokens.gap("sm")
                y: VitrailTokens.gap("sm")
                width: holder.width - 2 * VitrailTokens.gap("sm")
                height: holder.height - 2 * VitrailTokens.gap("sm")
                opacity: liquid.look.content
                queue: root.queue
                strings: root.strings
                side: root.side
                dnd: root.dnd
                onCloseRequested: root.closeRequested()
                onDndToggled: root.dndToggled()

                // The widgets slot: now playing, quick notes, the session row.
                MediaPanel {
                    Layout.fillWidth: true
                    visible: root.mediaPlayer !== null
                    player: root.mediaPlayer
                    style: root.mediaStyle
                    players: root.mediaPlayers
                    index: root.mediaIndex
                    strings: root.strings
                    onPlayerChosen: function (index) { root.mediaIndex = index }
                }

                QuickToggles {
                    Layout.fillWidth: true
                    wifiOn: root.wifiOn
                    bluetoothOn: root.bluetoothOn
                    bluetoothPresent: root.bluetoothPresent
                    micMuted: root.micMuted
                    airplaneOn: root.airplaneOn
                    dnd: root.dnd
                    onToggled: function (key) { root.quickToggled(key) }
                }

                QuickNotes {
                    Layout.fillWidth: true
                    strings: root.strings
                    text: root.notes
                    onNoteAdded: function (note) { root.noteAdded(note) }
                    onNoteRemoved: function (index) { root.noteRemoved(index) }
                }

                SessionRow {
                    Layout.fillWidth: true
                    onChosen: function (key) { root.sessionRequested(key) }
                }
            }
        }
    }
}
