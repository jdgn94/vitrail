# Bar popups

Reference: macOS-like tray menu that grows out of a docked bar
(card flush with the frame edge, concave fillets into the frame, rounded
outer corners, same tint as the frame, no seam or edge line at the base).

## Docked bar → tab of the frame

- `VitrailBar.popup` (rect) + `popupOpen` → one entry of `VitrailFrame.tabs`.
  Other docked cards (the notification stack) go in `VitrailBar.tabs`.
- `Frame.holePath(w, h, hole, radius, tabs)`, tabs = `[{ edge, rect, reveal }]`
  on any edges: fillet radius `min(R, depth)`, outer corners
  `min(R, depth/2, length/2)`. Each edge is walked in a frame turned so it is
  the left side (`turn` / `unturn`); left, top, right, bottom is clockwise.
- Tab entries are `{ edge, rect, reveal, base, swell }`: `reveal` scales the
  depth past `base` (px; an islands bar starts the popup at the island's
  depth, so it grows out of the island), `swell` multiplies the fillet radius.
  `VitrailBar.popupLook` (a `VitrailLiquid.look`, null while closed) drives the
  popup tab; callers own the look of their own tabs.
- The popup layer draws only the content; its `VitrailSurface` is hidden.
- Placement (`bar/shell.qml`, `popupCard`): cross-axis flush at
  `hole[edge]`; along the bar `Frame.popupAlong()`: centred on the anchor;
  within `2 * radius` (hole corner + fillet) of a hole end it snaps flush.
- Corner case (reference: popup near the top of a left bar): a tab flush with
  a hole end takes that corner — no rounded hole corner there, the tab's free
  side joins the perpendicular frame edge with a concave fillet instead.

- Islands bar: the card hangs from `layout.dock[edge]` (the bar thickness), so
  it rises out of the island; the overlap merges in `holePath`. The tab's
  `base` is the island's depth, so the reveal starts there.

## Open / close motion (`VitrailLiquid`, `Frame.liquid` / `Frame.smooth`)

One linear timeline `progress` (0 closed .. 1 open, `motion.liquid` / `smooth`
durations) feeds pure curves in frame.js; closing runs them backwards. Per
monitor: `popupLiquid` and `stackLiquid` in bar/shell.qml; their windows stay
up while `shown`. Tokens: `motion.liquid` (overshoot, fractions of the
timeline, ratios), `motion.smooth`.

- Glass, docked / islands: the tab's length grows from the button's width to
  the card's (`Frame.liquidRect`, spread), its depth springs with a small
  overshoot (`reveal`), fillets swell while it moves (`swell`), the content
  fades in after `contentAt` and out first when closing. Gliding to another
  button stretches the tab ahead of the motion (`popupLag * stretch`).
- Glass, floating / floatingIslands: `VitrailLiquidSkin` draws an island
  (`Frame.floatRect`) leaving the bar face (it detaches further than at rest
  by `pull`, then settles), joined to the bar or island under the anchor
  (`Frame.nearestRect`) by `VitrailNeck`: an hourglass (`Frame.neck`) whose
  waist thins with `bond` and which is gone once it snaps (`snapAt`).
- Solid: no overshoot, stretch or neck. Docked: the tab grows with an out-cubic
  and the content fades; floating: the island fades, scales from 0.96 and
  slides in from the bar.
- Glass / solid and the opacity come from `VitrailTokens.surfaceMode` /
  `shell.barOpacity`; `VitrailSurface` reads alpha and edge from
  `VitrailVariants.surface`, which also defines the `raised` / `raisedHover`
  alpha of cards inside a container. Never pass a literal `opacityLevel`.

## Per monitor

- Every monitor has its own bar. `shell.openPopup(kind, item, screen)` stores
  `shell.popupScreen`; only that screen's popup layer and frame tab show.
  Bar elements pass `monitor.modelData`; IPC (`network toggle`) passes none and
  gets the focused monitor (`shell.focusedScreen`, via
  `Hyprland.monitorFor(screen) === Hyprland.focusedMonitor`).

- Input: the popup window (`vitrail-popup`, Overlay, full screen) has
  `mask: Region { item: popupCard }` while shown, so only the card takes input;
  the bar buttons (layer Top) and the apps stay clickable, and a click on the
  same button closes, on another one switches. There is no click-catcher: a
  full-screen one eats every click. An app taking the focus
  (`Hyprland.activeToplevel` changes) closes the popup, except the launcher
  popout (it holds the keyboard until dismissed).

## Floating bar → island

- Own `VitrailSurface`, cross-axis at `reserve[edge] + gap(md)` (a gap past
  the bar), along the bar `Frame.popupAlong()` clamps to `hole + gap(md)` so
  it never touches the frame lines.

## Bar slots

- start: `LauncherButton` (tonal `apps`): left click → the full-screen
  launcher, right click → popout kind `launcher` (`references/launcher.md`).
  Through `vitrail-bar ipc call launcher toggle` (full screen), `open <mode>`
  or `popout`. Super alone (release bind `SUPER + SUPER_L`) is the only
  launcher key, in hyprland.lua.
- center: `ClockButton` (SystemClock; "HH\nMM" on a vertical bar) → popup
  kind `clock` → `ClockPanel` (time, localized date, MonthGrid calendar with
  month paging and a "today" button).
- end: `BarItems` (tray, network, vpn, power). Clicking another bar button
  while a popup is open moves the popup to it (`togglePopup` → `openPopup`);
  hovering never switches (the bar gets hover while a popup is open, so a
  hover switch would also close it again on the click).

## Popouts (after caelestia-dots/shell)

- Every element with a popout reports `(kind, item)`; `shell.openPopup` anchors
  (`shell.popupAnchor`, the item's rect) on that exact item; without one (IPC)
  on that popup's own button on the target screen (`monitor.anchorFor`).
  Kinds: `network`, `vpn`, `media`, `clock`, `power`, `launcher`, `tray:<id>`.
- `bar/Popout.qml`: one named `Loader` per kind. Becoming current: load at
  once (the card needs its size), wait `handover`, then fade in (`slow`);
  leaving: fade out (`fast`), then unload. Closing the popup clears the
  current name, so menus reload fresh on the next open.
- Switching (click on another button, `popupOpen` stays true, so the liquid
  timeline does not move): the old content fades out (`fast`), the card glides
  to the new button and size, then the new content fades in. `handover` is
  `fast` when switching, 0 when opening from closed. Never two popouts visible
  at once.
- The card (`popupCard`) is sized to the current popout + margin and animates
  x / y / width / height with `slow` + `Easing.OutQuint`, and clips its
  content so nothing draws outside it while it resizes. `targetX/Y` are
  computed from the TARGET size (`targetWidth/Height`), never the animated
  one: otherwise on a right / bottom bar or a centred card x / y chase a moving
  target and the card drifts off the frame edge. The frame tab (`popup` rect)
  and the floating skin (`rect`) are fed the animated x / y / width / height;
  the neck's source island (`sourceX..sourceHeight`) glides with the same
  curve. The liquid `origin` (the button) only matters while the shape opens
  (`spread` < 1), so it jumps to the new button without desync.
- Opening from closed sets `shell.popupOpening` for a `fast` beat: the
  Behaviors are off, so the card appears at its button instead of gliding
  from wherever the last popout was.
- The idle close timer (`popupLeave`, 3 s after the pointer leaves the card) is
  cancelled when the popup kind changes.

## Tray (bar/tray)

- `TrayItems`: collapsed by default; app icons are tinted with the theme
  foreground (primary on hover / open menu) by a `MultiEffect` colorization,
  the NeedsAttention dot stays `error`. A `plain` chevron folds the icons (animated implicit size;
  an `error` dot on the chevron when a folded app needs attention);
  `SystemTray.items` minus Passive; left = activate (or menu
  when `onlyMenu`), right = menu popout, middle = secondaryActivate, wheel =
  scroll; NeedsAttention shows an `error` dot.
- The chevron comes after the icons (between them and the network button), so
  folding moves only the icons; its glyph points to where the icons come from
  (collapsed) or go to (expanded).
- `TrayMenu`: StackView of `MenuLevel`s over `QsMenuOpener`; plain rows
  (pill hover), 1 px separators, disabled at 45 %, check / radio glyphs,
  `chevron_right` pushes a submenu with a tonal "Back" row; DBusMenu
  mnemonics (`_`) are stripped. Triggering closes the popout.
