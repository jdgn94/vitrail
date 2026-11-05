# Bar tooltips

Every bar element names itself on hover. Rule: **an element without a
tooltip is not finished** (`tests/test_tooltips.py` enforces it for
`*Button.qml`, anything with `signal clicked(`, and `TrayItems.qml`).

## Contract

- The element declares `property string tooltip` (title, required) and
  `tooltipDetail` (second line, optional), bound to live data, plus
  `hovered` (HoverHandler). `opened` (popout elements) only paints the
  element; the host does not read it.
- Strings go through the element's `t("tooltip.*")` (`strings` comes from
  the shell); data that is not translatable (SSID, app title, IP) is used as is.
- The container reports hover: `onHoveredChanged: tooltips.hover(item, hovered)`
  (BarItems and TrayItems forward it as `tipHovered(item, on)`).

## Pieces

- `kit/base/VitrailTooltip.qml`: surface pill (glass / solid like every card,
  `opacityLevel` from the shell), title in `label` ink, detail muted, elided
  at 10 display sizes. `active` starts the hover delay (`motion.tooltip`),
  then it fades and scales in (`motion.smooth.scale`) from the bar's side;
  `active: false` hides at once. No input handlers.
- `bar/TooltipLayer.qml`: ONE per monitor (not per item). Full-screen
  overlay (`vitrail-tooltip`), empty `mask` so it never takes input, visible
  only while the pill is (`visible: tip.opacity > 0`). `hover(item, on)` sets
  the target; the text is read live from it. Moving to the next element keeps
  it up and glides.
- Quiet rules (`TooltipLayer`): (1) `popupOpen` (shell: `popupOpen ||
  launcherOpen || sessionOpen`, global, any monitor) means no tooltip at all,
  it is part of the pill's `active`. (2) `dismissed` hides the tooltip of the
  current target until the pointer leaves and comes back: it is set when
  `popupOpen` changes in either direction while a target is hovered (a click
  that opened or closed something) and on the target's `clicked` (a
  `Connections` with `ignoreUnknownSignals: true`, for clicks that open
  nothing); `onTargetChanged` clears it, and leaving sets the target to null,
  so re-entering starts clean. Never connect to `pressed` or other
  per-element signals: most elements lack them and Quickshell warns at startup.
- `Frame.tooltipAt(edge, target, w, h, offset, gap, width, height)`: a gap
  past the bar, on the side away from the bar, centred on the element, kept a
  gap inside the screen (`tst_frame.qml`). `offset` is `layout.face`: the
  bar's inner face from its edge, the same docked, islands or floating.

## Pitfalls

- Never bind a window's `visible` to a child Item's `visible`: that is the
  effective visibility, false while the window is hidden, so the window never
  shows (a deadlock). Bind to something the window does not affect, like
  `tip.opacity > 0`, which still lets the pill fade out before the window hides.
- Map the target with its bounding rect,
  `target.mapToItem(null, Qt.rect(0, 0, w, h))`, not its mapped corner plus
  width / height: a rotated target (the tray chevron) maps the wrong corner.
  The bar and the tooltip windows are full-screen layers on one screen, so
  scene coordinates agree.
- Place again when the pill becomes `shown` (layouts settle during the hover
  delay) and when the target's x, y, width or height change, not only when
  the target or the pill size changes.
- Pass `offset = layout.face`, never `dock` or `reserve`: those grow with an
  open panel and the pill would jump past it, far from the element.

## Contents

| element | title | detail |
|---|---|---|
| launcher | Applications | Click / Super: full screen · Right click: compact |
| clock | full localized date | none |
| tray icon | `tooltipTitle` (else title, id) | `tooltipDescription` |
| tray chevron | Show / Hide background apps (N) | none |
| network | SSID, or `eno1 · Wired`; offline: Disconnected | IPv4 of that interface (`ip -j -4 addr show dev`, refreshed every 30 s and on link change) |
| vpn | provider (`ProtonVPN`); none: No VPN | server and region (`us-free-26 · US`) from `vitrail-vpn list --json` |
| power | Power | Click: menu · Right click: quick menu |
| notifications | Notifications | `bar/notifications/tooltip.js`: Do Not Disturb, silent until HH:MM (X min left), `%1` in the centre, or the click hint |

## Silence-aware tooltips

A state that explains itself (why something is quiet, for how long) keeps its
rule in a `.pragma library` next to the element — `tooltip.js` for the bell —
and takes `now` as an argument, so the wording is testable without a clock.
`reason()` names the state (`none`, `dnd`, `until`) and `describe()` turns it
into the two tooltip lines with the element's strings; a new reason is one
branch, not a string of ternaries in QML. A timed state binds a Timer to
`reason().kind` and refreshes `now`.

Hyprland glass blur for the pill needs the usual layer rule for the
`vitrail-tooltip` namespace, like the other bar layers.
