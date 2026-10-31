import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../kit/composed"
import "../kit/frame.js" as Frame
import "osd.js" as Osd
import "icons.js" as Icons
import "brightness.js" as Light

// The OSD of one monitor: volume, microphone and brightness sliders on the
// screen edge opposite the notifications, centred there.
//
// - An invisible hot zone glued to that edge (the frame border + `osd.hot`
//   thick, as long as the panel) reveals the full panel once the pointer has
//   stayed in it for `motion.dwell` ms; the panel goes `osd.hide` ms after the
//   pointer leaves it. Nothing outside the
//   hot zone, the panel and its card takes input.
// - A media key (or a change from outside, see OsdController) shows only that
//   slider for `osd.key` ms, on the focused monitor.
// - Hovering a slider of the full panel opens a card beside it, toward the
//   screen interior: the output devices, the input devices, or one brightness
//   slider per monitor (only when there is more than one).
// - Docked, the panel is a tab of the frame (`tabs`, for VitrailBar.tabs); a
//   floating bar gets an island. Both open like the popups (VitrailLiquid).
Scope {
    id: root

    required property var screen
    required property var controller
    // This monitor's Frame.layout and whether its bar is docked to the frame.
    property var layout: ({ edge: "left", hole: { left: 0, top: 0, right: 0, bottom: 0 },
                            dock: { left: 0, top: 0, right: 0, bottom: 0 },
                            reserve: { left: 0, top: 0, right: 0, bottom: 0 } })
    property bool docked: true
    // One edge for every monitor (the shell computes it from the primary's
    // bar) and the primary's bounds: the panel is centred at the same spot
    // everywhere, docking to this monitor's own frame.
    property string edge: "top"
    property var reference: root.docked ? root.layout.dock : root.layout.reserve
    // Media keys show the OSD on this monitor only.
    property bool focused: false
    property var strings: ({})
    property real opacityLevel: VitrailTokens.opacity
    // Previews pin a state: "key", "full" or "hidden" without timers or hover.
    property bool animated: true

    // hidden, key (one slider, for a moment) or full (all three, hovered).
    property string mode: "hidden"
    property string keyKind: ""
    property var kinds: root.all
    // The kind whose card is open, and the last one (it keeps its content
    // while the card closes).
    property string extKind: ""
    property string shownExt: ""
    property string hoverKind: ""
    property string pressedKind: ""

    readonly property var all: ["volume", "mic", "brightness"]
    readonly property bool side: Osd.vertical(root.edge)
    readonly property var bounds: Osd.alignBounds(root.edge, root.docked ? root.layout.dock : root.layout.reserve,
                                                  root.reference)
    readonly property real gap: root.docked ? 0 : VitrailTokens.gap("md")
    readonly property real thickness: VitrailTokens.slider[VitrailTokens.osd.size] + 4 * VitrailTokens.slider.gap
    readonly property var metrics: ({
        thickness: root.thickness,
        length: VitrailTokens.osd.length,
        icon: root.thickness,
        textWide: Math.round(VitrailTokens.size("label") * 3.2),
        textTall: VitrailTokens.size("label") + VitrailTokens.gap("xs"),
        pad: VitrailTokens.gap("sm"),
        spacing: VitrailTokens.gap("sm"),
        inner: VitrailTokens.gap("xs")
    })
    readonly property var wantSize: Osd.panelSize(root.edge, root.kinds.length, root.metrics)
    // The panel with all three sliders: the hot zone is as long as this one.
    readonly property var fullRect: Osd.panelRect(root.edge, window.width, window.height,
                                                  Osd.panelSize(root.edge, root.all.length, root.metrics),
                                                  root.bounds, root.gap)
    readonly property var panel: ({ x: holder.x, y: holder.y, width: holder.width, height: holder.height })
    // The hot zone counts only after the pointer dwelt on it.
    readonly property bool touching: dwell.ready || panelHover.hovered || cardHover.hovered
                                     || root.pressedKind !== ""
    readonly property bool open: root.mode !== "hidden"

    // The frame tab of the panel, for a docked bar's VitrailBar.tabs.
    readonly property var tab: root.docked && liquid.shown && holder.width > 0 ? {
        edge: root.edge,
        reveal: liquid.look.reveal,
        swell: liquid.look.swell,
        rect: Frame.liquidRect(Qt.rect(holder.x, holder.y, holder.width, holder.height), root.edge, null,
                               liquid.look.spread, 0, 0)
    } : null
    readonly property var tabs: root.tab ? [root.tab] : []

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // What each slider shows, from the controller.
    function specOf(kind) {
        var c = root.controller
        if (kind === "volume")
            return { value: c.volume * 100, icon: Icons.volume(c.volume, c.muted), muteable: true, muted: c.muted,
                     available: c.hasOutput, tooltip: root.t(c.hasOutput ? "osd.volume" : "osd.noOutput"),
                     detail: c.hasOutput ? c.name(c.sink) : "" }
        if (kind === "mic")
            return { value: c.micVolume * 100, icon: Icons.mic(c.micMuted), muteable: true, muted: c.micMuted,
                     available: c.hasInput, tooltip: root.t(c.hasInput ? "osd.mic" : "osd.noInput"),
                     detail: c.hasInput ? c.name(c.source) : "" }
        return { value: c.light.level, icon: Icons.brightness(c.light.level / 100), muteable: false, muted: false,
                 available: c.light.enabled,
                 tooltip: c.light.enabled ? root.t("osd.brightness") : root.t(Light.reason(c.light.status)), detail: "" }
    }

    function extAvailable(kind) {
        var c = root.controller
        return kind === "brightness" ? c.light.enabled && c.light.devices.length > 1
                                     : (kind === "volume" ? c.sinks.length : c.sources.length) > 0
    }

    // A media key: only that slider, then it goes. A full panel stays as is.
    function key(kind) {
        if (root.mode === "full")
            return
        root.keyKind = kind
        root.kinds = [kind]
        root.mode = "key"
        hideTimer.interval = VitrailTokens.osd.key
        hideTimer.restart()
    }

    function full() {
        hideTimer.stop()
        root.kinds = root.all
        root.mode = "full"
        root.controller.light.refresh(false)
    }

    onTouchingChanged: {
        if (root.touching) {
            root.full()
        } else if (root.mode === "full" && root.animated) {
            hideTimer.interval = VitrailTokens.osd.hide
            hideTimer.restart()
        }
    }

    onHoverKindChanged: {
        if (root.hoverKind !== "" && root.mode === "full" && root.extAvailable(root.hoverKind)) {
            root.extKind = root.hoverKind
            root.shownExt = root.hoverKind
            extTimer.stop()
        } else if (root.hoverKind === "") {
            extTimer.restart()
        }
    }

    Connections {
        target: root.controller

        function onKeyed(kind) {
            if (root.focused && root.animated)
                root.key(kind)
        }
    }

    // Hides the panel after the pointer left it (or a key's moment is over).
    Timer {
        id: hideTimer

        onTriggered: {
            root.mode = "hidden"
            root.extKind = ""
            root.hoverKind = ""
        }
    }

    // The card outlives the pointer's walk from its slider to the card.
    Timer {
        id: extTimer

        interval: VitrailTokens.osd.extension
        onTriggered: if (root.hoverKind === "" && !cardHover.hovered) root.extKind = ""
    }

    DwellGate {
        id: dwell

        hovered: stripHover.hovered
        interval: VitrailTokens.motion.dwell
    }

    VitrailLiquid {
        id: liquid

        animated: root.animated
        open: root.open
    }

    VitrailLiquid {
        id: extLiquid

        animated: root.animated
        open: root.extKind !== "" && root.mode === "full"
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
        WlrLayershell.namespace: "vitrail-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        // Only the hot zone, the panel and its card take the pointer.
        mask: Region {
            item: strip

            Region { item: liquid.shown ? holder : null }
            Region { item: extLiquid.shown ? card : null }
        }

        // The invisible hot zone on the screen edge.
        Item {
            id: strip

            readonly property var zone: Osd.hotZone(root.edge, window.width, window.height, root.fullRect,
                                                    root.layout.hole[root.edge], VitrailTokens.osd.hot)

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
            edge: root.edge
            rect: Qt.rect(holder.x, holder.y, holder.width, holder.height)
            origin: null
            source: null
            look: liquid.look
            gap: VitrailTokens.gap("md")
            opacityLevel: root.opacityLevel
        }

        Item {
            id: holder

            readonly property var rect: Osd.panelRect(root.edge, window.width, window.height, root.wantSize,
                                                      root.bounds, root.gap)

            visible: liquid.shown
            x: holder.rect.x
            y: holder.rect.y
            width: holder.rect.width
            height: holder.rect.height
            clip: true

            // Only a panel that is fully open grows or shrinks (key to full).
            Behavior on x { enabled: liquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on y { enabled: liquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on width { enabled: liquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on height { enabled: liquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

            HoverHandler {
                id: panelHover

                enabled: root.animated
            }

            GridLayout {
                x: root.metrics.pad
                y: root.metrics.pad
                opacity: liquid.look.content
                flow: root.side ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: root.metrics.spacing
                columnSpacing: root.metrics.spacing

                Repeater {
                    model: root.kinds

                    delegate: OsdCell {
                        id: cell

                        required property string modelData

                        readonly property var spec: root.specOf(cell.modelData)

                        kind: cell.modelData
                        vertical: root.side
                        metrics: root.metrics
                        value: cell.spec.value
                        icon: cell.spec.icon
                        muteable: cell.spec.muteable
                        muted: cell.spec.muted
                        available: cell.spec.available
                        tooltip: cell.spec.tooltip
                        tooltipDetail: cell.spec.detail
                        onHoveredChanged: {
                            if (cell.hovered)
                                root.hoverKind = cell.modelData
                            else if (root.hoverKind === cell.modelData)
                                root.hoverKind = ""
                        }
                        onPressedChanged: {
                            if (cell.pressed)
                                root.pressedKind = cell.modelData
                            else if (root.pressedKind === cell.modelData)
                                root.pressedKind = ""
                        }
                        onMoved: function (value) { root.move(cell.modelData, value) }
                        onMuteRequested: {
                            if (cell.modelData === "volume")
                                root.controller.toggleMute()
                            else
                                root.controller.toggleMicMute()
                        }
                    }
                }
            }
        }

        // The card of the hovered slider, beside the panel.
        VitrailLiquidSkin {
            anchors.fill: parent
            visible: extLiquid.shown
            edge: root.edge
            rect: Qt.rect(card.x, card.y, card.width, card.height)
            origin: card.origin
            source: root.panel
            look: extLiquid.look
            gap: VitrailTokens.gap("md")
            opacityLevel: root.opacityLevel
        }

        Item {
            id: card

            readonly property real margin: VitrailTokens.gap("md")
            readonly property var size: ({ width: VitrailTokens.osd.card + 2 * card.margin,
                                           height: body.implicitHeight + 2 * card.margin })
            readonly property var cell: Osd.cellRect(root.edge, root.panel, Math.max(0, root.kinds.indexOf(root.shownExt)),
                                                     root.metrics)
            readonly property var origin: Qt.rect(card.cell.x, card.cell.y, card.cell.width, card.cell.height)
            readonly property var rect: Osd.cardRect(root.edge, root.panel, card.cell, card.size, root.bounds,
                                                     VitrailTokens.gap("md"), window.width, window.height)

            visible: extLiquid.shown
            x: card.rect.x
            y: card.rect.y
            width: card.rect.width
            height: card.rect.height

            // Gliding from one slider to the next.
            Behavior on x { enabled: extLiquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }
            Behavior on y { enabled: extLiquid.progress >= 1; NumberAnimation { duration: VitrailTokens.duration("base"); easing.type: Easing.OutCubic } }

            HoverHandler {
                id: cardHover

                enabled: root.animated
                onHoveredChanged: if (!cardHover.hovered) extTimer.restart()
            }

            Loader {
                id: body

                x: card.margin
                y: card.margin
                width: card.width - 2 * card.margin
                opacity: extLiquid.look.content
                sourceComponent: root.shownExt === "brightness" ? lightCard : deviceCard
            }
        }

        // What the pointer reads where there is no card: why a slider is off.
        VitrailTooltip {
            id: tip

            readonly property var target: Osd.cellRect(root.edge, root.panel, Math.max(0, root.kinds.indexOf(root.hoverKind)),
                                                       root.metrics)
            readonly property var at: Frame.tooltipAt(root.edge, Qt.rect(tip.target.x, tip.target.y, tip.target.width, tip.target.height),
                                                      tip.width, tip.height, root.side
                                                      ? (root.edge === "left" ? root.panel.x + root.panel.width : window.width - root.panel.x)
                                                      : (root.edge === "top" ? root.panel.y + root.panel.height : window.height - root.panel.y),
                                                      VitrailTokens.gap("sm"), window.width, window.height)
            property string label: ""
            property string extra: ""

            x: tip.at.x
            y: tip.at.y
            text: tip.label
            detail: tip.extra
            active: root.hoverKind !== "" && root.extKind === "" && root.mode !== "hidden"
            edge: root.edge
            opacityLevel: root.opacityLevel
        }
    }

    Component {
        id: deviceCard

        DeviceCard {
            controller: root.controller
            output: root.shownExt === "volume"
            strings: root.strings
        }
    }

    Component {
        id: lightCard

        BrightnessCard {
            light: root.controller.light
            strings: root.strings
        }
    }

    // The slider's own tooltip text follows the hovered one.
    Binding {
        target: tip
        property: "label"
        value: root.specOf(root.hoverKind).tooltip
        when: root.hoverKind !== ""
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: tip
        property: "extra"
        value: root.specOf(root.hoverKind).detail
        when: root.hoverKind !== ""
        restoreMode: Binding.RestoreNone
    }

    // A slider moved by the pointer.
    function move(kind, value) {
        if (kind === "volume")
            root.controller.setVolume(value / 100)
        else if (kind === "mic")
            root.controller.setMicVolume(value / 100)
        else
            root.controller.setBrightness(value)
    }
}
