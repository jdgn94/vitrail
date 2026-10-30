# Notifications

No bell, no history: incoming notifications show as toasts and go away.

## Files

- `bar/notifications/NotificationQueue.qml` — logic only (tested in
  `tests/qml/tst_notification_queue.qml`): `shown` ListModel of `{ nid }`,
  newest first, at most `maximum`; the rest wait in `waiting` (FIFO) and take
  the first freed slot. `closed` on a notification drops it from either.
- `NotificationStack.qml` — ListView over `shown`; `atBottom` flips it
  (`BottomToTop`) so the newest sits nearest the edge.
- `NotificationToast.qml` — one toast.
- `bar/shell.qml` — `NotificationServer.onNotification` sets `tracked` and
  pushes; a full-screen Overlay layer (`vitrail-notifications`, mask = stack,
  `keyboardFocus: OnDemand` for replies) places the stack with
  `Frame.stackRect()`. It opens and closes with `stackLiquid` like a popup
  (see popups.md): a liquid tab in glass, a smooth fade in solid; floating, an
  island with a neck to the bar when the bar is on its edge.

## Look

- Position pref `notificationPosition` = `top|bottom` + `-left|-center|-right`
  (default `top-right`); `notificationMax` from `tokens.ranges.notifications`.
- One container holds the cards: a frame tab when docked, a `VitrailSurface`
  island when floating. Cards: `surfaceHigh` at the surface variant's `raised` alpha
  (`raisedHover` hovered; opaque cards take a tint), radius
  0.85 × token, app icon in a 10 % foreground circle (`info` glyph fallback).
- Collapsed: title • age (`now`, `%1 min`, `%1 h`, ticking every 30 s) and one
  body line; expanded: app • age, title, body up to 6 lines (StyledText),
  actions as `text` buttons (app actions, reply, mark as read).
- The newest card is expanded; the chevron sets `userExpanded`, which wins.

## Which monitor

- `shell.notificationScreen`: the focused monitor, unless its active workspace
  has a fullscreen window; then the primary screen, any other screen without
  one, and only if all are fullscreen the focused one anyway. The layer and
  the frame tab of the stack both follow it. Docked on an islands bar the
  stack hangs from `layout.dock` (below the islands) where it overlaps an island,
  and from the thin frame where it does not (`Frame.stackRect(..., islands)`).

## Behaviour

- Click → the `default` action (focus the app); middle click or a sideways
  flick past a third of the width → `dismiss()` (mark read).
- Expires (`expire()`) after 5 s; hover, a swipe in progress or a reply
  hold it, and the countdown restarts from zero when released.
