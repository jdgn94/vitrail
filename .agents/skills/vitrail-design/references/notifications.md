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
  `Frame.stackRect()`.

## Look

- Position pref `notificationPosition` = `top|bottom` + `-left|-center|-right`
  (default `top-right`); `notificationMax` from `tokens.ranges.notifications`.
- Docked bar: the stack is one tab of the frame (flush with the hole, takes
  the corner it touches); toasts are separated by a 1 px divider.
- Floating bar: each toast is its own `VitrailSurface` island, a `gap(md)`
  clear of the bar and the frame.
- Toast: app icon (`appIcon` / `desktopEntry` via `Quickshell.iconPath`, then
  `image`, then the app initial on a tinted disc), bold summary, app name,
  body `StyledText` (HTML subset) with `maximumLineCount: 2` + elide.

## Behaviour

- Click anywhere → the `default` action (focus the app). The ⋮ button sits
  above and opens chips: mark as read (`dismiss`), reply (if
  `hasInlineReply`; inline field, Enter sends), the app's other actions.
- Expires (`expire()`) after 5 s; hover, open menu or a reply in progress
  hold it, and the countdown restarts from zero when released.
