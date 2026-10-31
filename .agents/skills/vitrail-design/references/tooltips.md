# Bar tooltips

Every bar element names itself on hover. Rule: **an element without a
tooltip is not finished** (`tests/test_tooltips.py` enforces it for
`*Button.qml`, anything with `signal clicked(`, and `TrayItems.qml`).

## Contract

- The element declares `property string tooltip` (title, required) and
  `tooltipDetail` (second line, optional), bound to live data, plus
  `hovered` (HoverHandler) and `pressed` (MouseArea / button alias). A
  popout element also has `opened`: its tooltip stays quiet while its popout
  is open.
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
  only while the pill is. `hover(item, on)` sets the target; the text is read
  live from it; pressing the target hides it until the pointer leaves.
  Moving to the next element keeps it up and glides.
- `Frame.tooltipAt(edge, target, w, h, offset, gap, width, height)`: a gap
  past the bar (`offset` = `layout.dock[edge]` docked, `layout.reserve[edge]`
  floating), on the side away from the bar, centred on the element, kept a
  gap inside the screen (`tst_frame.qml`).

## Contents

| element | title | detail |
|---|---|---|
| launcher | Applications | Click / Super: full screen · Right click: compact |
| clock | full localized date | none |
| tray icon | `tooltipTitle` (else title, id) | `tooltipDescription` |
| tray chevron | Show / Hide background apps (N) | none |
| network | SSID, or `eno1 · Wired`; offline: Disconnected | IPv4 of that interface (`ip -j -4 addr show dev`, refreshed every 30 s and on link change) |
| vpn | provider (`ProtonVPN`); none: No VPN | server and region (`us-free-26 · US`) from `hypraether-vpn list --json` |
| power | Power | Click: menu · Right click: quick menu |

Hyprland glass blur for the pill needs the usual layer rule for the
`vitrail-tooltip` namespace, like the other bar layers.
