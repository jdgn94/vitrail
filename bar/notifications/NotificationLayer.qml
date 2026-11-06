import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../kit/composed"
import "../osd"
import "../osd/osd.js" as Osd
import "../layouts.js" as Layouts
import "../widgets"

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
// - The widget slot is drawn from the shared registry (bar/widgets.js) and the
//   panel's document (bar.ini `panelLayout`): today's five widgets in today's
//   order when the document is empty.
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
    // What a notification's buttons ask the shell to do, and the settings they
    // follow (snooze offered, muted apps, per-app counts today).
    property var act: null
    property bool recording: false
    property bool snoozeEnabled: true
    property string mutedApps: ""
    property var stats: ({})
    // The shell's: which of the two lists is open.
    property bool mutedShown: false
    property bool statsShown: false
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
    // The panel's widget document (bar.ini `panelLayout`); empty is today's
    // panel. It changes rarely, so the document is built from the text only.
    property string layoutText: ""
    readonly property var panelDocument: Layouts.effective(root.layoutText, "", Layouts.defaults("panel"), "panel")
    property real opacityLevel: VitrailTokens.opacity
    // Previews pin a state without timers or hover.
    property bool animated: true

    // An empty style means the widget's own default; the player follows the
    // bar's `mediaStyle` preference, as it did before the panel had a document.
    function widgetStyle(id, style) {
        if (style !== "")
            return style
        return id === "media" ? root.mediaStyle : ""
    }

    signal openRequested()
    signal closeRequested()
    signal dndToggled()
    signal mutedToggled()
    signal statsToggled()
    signal sessionRequested(string key)
    signal noteAdded(string note)
    signal noteRemoved(int index)
    signal quickToggled(string key)
    signal shotRequested(string mode)
    signal recordRequested()

    readonly property var bounds: root.docked ? root.layout.dock : root.layout.reserve
    readonly property bool touching: stripHover.hovered || panelHover.hovered
    readonly property real gap: root.docked ? 0 : VitrailTokens.gap("md")

    // The frame tab of the panel, for a docked bar's VitrailBar.tabs. Its
    // length is the whole edge from the first frame: the panel comes out of
    // the entire side, not from a point in the middle of it.
    readonly property var tab: root.docked && root.active && root.pinned && liquid.shown && holder.width > 0 ? {
        edge: root.side,
        reveal: liquid.look.reveal,
        swell: liquid.look.swell,
        rect: Qt.rect(holder.x, holder.y, holder.width, holder.height)
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
                enter: liquid.look.content
                queue: root.queue
                active: root.open || liquid.shown
                strings: root.strings
                side: root.side
                dnd: root.dnd
                act: root.act
                snoozeEnabled: root.snoozeEnabled
                mutedApps: root.mutedApps
                stats: root.stats
                mutedShown: root.mutedShown
                statsShown: root.statsShown
                onCloseRequested: root.closeRequested()
                onDndToggled: root.dndToggled()
                onMutedToggled: root.mutedToggled()
                onStatsToggled: root.statsToggled()

                // The widget slot, from the shared registry: the document's
                // visible ids, in its order, each through the same host.
                Repeater {
                    model: Layouts.visible(root.panelDocument.order, root.panelDocument.hidden)

                    delegate: PanelWidget {
                        required property string modelData

                        readonly property var setting: Layouts.setting(root.panelDocument, modelData, "panel")

                        Layout.fillWidth: true
                        widgetId: modelData
                        size: setting.size
                        style: root.widgetStyle(modelData, setting.style)
                        fontFamily: setting.font
                        fontWeight: setting.weight
                        italic: setting.italic
                        strings: root.strings
                        mediaPlayer: root.mediaPlayer
                        mediaPlayers: root.mediaPlayers
                        mediaIndex: root.mediaIndex
                        wifiOn: root.wifiOn
                        bluetoothOn: root.bluetoothOn
                        bluetoothPresent: root.bluetoothPresent
                        micMuted: root.micMuted
                        airplaneOn: root.airplaneOn
                        dnd: root.dnd
                        notes: root.notes
                        recording: root.recording
                        onPlayerChosen: function (index) { root.mediaIndex = index }
                        onQuickToggled: function (key) { root.quickToggled(key) }
                        onShotRequested: function (mode) { root.shotRequested(mode) }
                        onRecordRequested: root.recordRequested()
                        onNoteAdded: function (note) { root.noteAdded(note) }
                        onNoteRemoved: function (index) { root.noteRemoved(index) }
                        onSessionRequested: function (key) { root.sessionRequested(key) }
                    }
                }
            }
        }
    }
}
