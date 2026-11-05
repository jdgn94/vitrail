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
  `mask: Region { item: popupCard }` while shown, so only the card takes input.
  The bar window (layer Top) expands its mask to the whole screen while a popup
  is open and keeps a full-screen `MouseArea` behind its own UI: a click
  outside the card (bar background, another monitor, an app, the desktop)
  lands there and closes the popup. The bar buttons are above that area and the
  card is an Overlay above the bar, so both keep their clicks: the same button
  closes (toggle), another one switches. The outside click is consumed by the
  close (it does not reach the app below), as with a menu.
- Closing is one rule (`shell.pointerInsidePopup`, pure point/rect helper in
  `bar/popup.js`): the pointer must have left the card, the tray app's menu
  card and the button the popup grew from, with `popupCard.margin` of grace.
  Two `HoverHandler`s feed it the last pointer position in screen coordinates:
  one on the popup layer (card and menu, children included) and one on the bar
  (where the invoking button is checked against `shell.popupAnchor`). Over an
  app the pointer is on neither surface, which counts as outside.
- An app taking the focus (`Hyprland.activeToplevel` changes) closes the popup
  only when that rule says the pointer is outside; the launcher popout follows
  the same rule. A focus change while the pointer reads the popup never closes
  it. Focus is a fallback, not the outside-click mechanism: the click catcher
  above closes even when the app under the pointer does not take the focus.
- Hover switching: with a popup open, hovering another bar element that has
  one opens it (`shell.hoverPopup`; every element emits `hovered(kind, item)`
  next to `clicked`). It never opens from closed. `shell.popupByHover` marks a
  popup the pointer brought there: the first click on its button confirms it
  (clears the flag), the next one closes it; any other open clears it.
  Otherwise the click would toggle the popup the hover just moved. Both signals
  carry the same kind (`tests/test_bar_popup_kinds.py`): when they differ, the
  enter event the compositor repeats as a popup opens moves the popup the click
  just opened to the other kind, so the next click reopens instead of closing.
- Launcher popout: same rules as the others (hover, glide, close on focus
  loss and idle once the pointer is outside). It takes the keyboard exclusively
  for 150 ms when it opens
  (the only way to be focused without a click), then `OnDemand`: an exclusive
  layer keeps the pointer and the focus to itself, so no bar button could be
  hovered and no window clicked while it is open. Opened with the pointer over
  a window (IPC), `follow_mouse` can hand the keyboard back to that window.
  The left click on its button opens the full-screen launcher (modal, layer
  `vitrail-launcher`) unless the popout is already open, then it confirms /
  closes the popout.

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
  kind `dashboard` → `DashboardPopout`, whose header is the big clock and the
  localized date, then the calendar tab (MonthGrid with month paging and a
  "today" button), weather, performance and media. The card sizes to the tab
  on screen: `Dashboard.qml`'s `StackLayout` sets
  `Layout.preferredHeight` from `pageFor[currentIndex]` (its default is the
  tallest child, which padded the shorter tabs); switching tabs or
  losing/regaining media re-sizes the card.
- end: tray, the connection chip (`network`, `bluetooth`, `vpn`, `profile`,
  one pill while they are neighbours), battery, keyboard layout and power.
  Each button has its own popup: `NetworkPanel`, `VpnPanel` and
  `PowerProfilePanel` (the settings window's Connection page is where the link,
  Bluetooth and power profile are configured together). The order is the
  layout document's (see `frame-and-bar.md`). Clicking another bar button while
  a popup is open moves the popup to it (`togglePopup` → `openPopup`);
  hovering one does the same (see Hover switching).

## Popouts (after caelestia-dots/shell)

- Every element with a popout reports `(kind, item)`; `shell.openPopup` anchors
  (`shell.popupAnchor`, the item's rect) on that exact item; without one (IPC)
  on that popup's own button on the target screen (`monitor.anchorFor`).
  Kinds: `network` (the chip's network panel), `vpn`, `powerprofile`, `media`,
  `dashboard`, `power`, `launcher`, `tray:<id>`.
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
- The tab's stretch (`lag`, `popupLag * stretch`) is measured on the anchor
  along the bar (`popupCard.glideAlong` follows `anchorAlong` with the card's
  curve), not on the card's x / y: those also move when the card only grows (a
  bottom-flush card rises as it gets taller), which is no glide and made the
  tab reach ahead of the card.
- `VitrailFrame`'s Shape is `asynchronous`: with a synchronous Shape the bar
  window stopped being repainted while the popup card (another window) kept
  resizing (VPN list loading), so the frame tab stayed at its old size until a
  hover repainted the bar (Qt 6.11; seen as `beforeSynchronizing` stopping
  while `holePath` kept changing).
- Opening from closed sets `shell.popupOpening` for a `fast` beat: the
  Behaviors are off, so the card appears at its button instead of gliding
  from wherever the last popout was.
- A popout kind that always floats (`tray:<id>`, `popupCard.floating`) is an
  island like the OSD's device card even on a docked bar: `popupCard.docked`
  is false, so `popupLook` stays null (the frame draws no tab), the card sits
  `layout.dock[edge] + margin` from the screen edge (past the frame / islands;
  `reserve` for a floating bar) and has no neck (`sourceTarget` is null while
  the bar is docked).
- The idle close timer (`popupLeave`, 3 s after the pointer leaves the card and
  the tray menu card) is cancelled when the popup kind changes; it closes only
  if the pointer is outside the popup's rule above, otherwise it waits another
  3 s. The 10 s idle timer (`popupIdle`) follows the same rule: while the
  pointer is inside, it restarts instead of closing.

## Tray (bar/tray)

- `TrayItems`: collapsed by default; app icons are tinted with the theme
  foreground (primary on hover / open menu) by a `MultiEffect` colorization,
  the NeedsAttention dot stays `error`. A `plain` chevron folds the icons (animated implicit size;
  an `error` dot on the chevron when a folded app needs attention);
  `SystemTray.items` minus Passive; left = activate (or menu
  when `onlyMenu`), right = menu popout, middle = secondaryActivate, wheel =
  scroll; NeedsAttention shows an `error` dot.
- The chevron comes after the icons (between them and the network button), so
  folding moves only the icons. One `chevron_right` glyph, `rotation` =
  `heading` + 180 while expanded (icons out, or the popup list open), animated
  by a `Behavior`. Inline: `heading` points where the icons come from (left on a
  horizontal bar, up on a vertical one). Popup: away from the bar's edge
  (`barEdge`: top down, bottom up, left right, right left).
- `TrayPanel` (popup style): icons only, in a `GridLayout` of
  `min(visible apps, tray.columns)` columns (one row when few, then wrapping).
  Each cell is the bar's inline icon (title + `sm` gap, colourised, round
  primary 8 % highlight on hover); Passive apps are hidden, so the grid
  reserves nothing for them. Left activates, right opens the menu. Its
  tooltip (`tipHovered`) is a `VitrailTooltip` in `popupLayer`, beside
  `popupCard` (the card clips), placed with `Frame.tooltipAt` past the card on
  the side away from the bar.
- The grid's app menu does not swap the popout: `popupKind` stays `tray` (the
  chevron stays open) and `menuRequested` sets `shell.trayMenuItem` plus
  `popupLayer.menuCell`, the icon. `menuCard` is a second card in the same
  `popupLayer` window (a second window would need its own input and focus), a
  plain `VitrailSurface` (`shell.barOpacity`) over one `Popout` per app with a
  `TrayMenu`, so replacing the menu fades the old one out and loads the new
  fresh. Placement `Frame.besideAt`: a `gap(md)` past `popupCard` away from the
  bar, along the bar centred on the icon within the hole like `popupAlong`.
  The mask is `popupCard` plus a child `Region` for `menuCard` while shown.
- Closing the menu: picking an entry (`done`), Escape (`menuCard` takes focus
  when it opens), right click on the same icon again (toggle). The tray card
  stays. `closePopup`, a change of `popupKind` or `popupScreen` clear
  `trayMenuItem`; an app taking the focus or the idle timers close both, but
  only while the pointer is outside the card, the menu and the invoking button
  (the menu and the tray card are two rects of the same rule). The pointer on
  `menuCard` counts as on the popup (`popupLeave`), opening a menu restarts
  `popupIdle`, and the icon tooltip is off while a menu is open.
- `TrayMenu`: StackView of `MenuLevel`s over `QsMenuOpener`; rows like
  `network/Entry` (`tray.menu` wide, `radius / 2`, foreground 6 % hover,
  checked check / radio entries tinted primary 14 % with a primary glyph),
  `xs` spacing, 1 px separators, disabled at 45 %, check / radio glyphs,
  `chevron_right` pushes a submenu with a tonal "Back" row; DBusMenu
  mnemonics (`_`) are stripped. Triggering closes the popout.
