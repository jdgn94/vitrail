# Notifications

Incoming notifications show as toasts and go away (the panel below keeps the
history the queue still holds). A bell beside the launcher opens the centre.

## Files

- `bar/notifications/NotificationQueue.qml` — logic only (tested in
  `tests/qml/tst_notification_queue.qml`): `shown` ListModel of `{ nid }`,
  newest first, at most `maximum`; the rest wait in `waiting` (FIFO) and take
  the first freed slot. `closed` on a notification drops it from either.
- `NotificationStack.qml` — ListView over `shown`; `atBottom` flips it
  (`BottomToTop`) so the newest sits nearest the edge.
- `NotificationToast.qml` — one toast, built on `NotificationCard`.
- `bar/shell.qml` — `NotificationServer.onNotification` sets `tracked` and
  pushes; a full-screen Overlay layer (`vitrail-notifications`, mask = stack,
  `keyboardFocus: OnDemand` for replies) places the stack with
  `Frame.stackRect()`. It opens and closes with `stackLiquid` like a popup
  (see popups.md): a liquid tab in glass, a smooth fade in solid; floating, an
  island with a neck to the bar when the bar is on its edge.

## Panel

- `bar/notifications/NotificationLayer.qml` (one per monitor, content in
  `NotificationPanel.qml`): full height on the notification side
  (`Notifications.sideFor`: never the bar's side; the OSD takes the opposite),
  `VitrailTokens.panel` wide, with a `widgets` slot.
- Opens from its hot zone after the dwell (`motion.dwell`), by the bell, or by
  IPC `notifications toggle|close`. Closes `osd.hide` ms after the pointer
  leaves the zone and the panel (edge-triggered: an opening from the bell or
  IPC stays until the pointer has been in and left, or IPC closes it).
- Built like the OSD: `VitrailLiquid`; docked, a frame tab (`NotificationLayer.tabs`
  into `VitrailBar.tabs`); floating, a `VitrailLiquidSkin` island. The tab's
  rect is the **whole holder**, not `Frame.liquidRect`: the panel comes out of
  the entire lateral edge (its depth reveals, its length does not grow from a
  point in the middle). The content slides in from that side (`enter` =
  `liquid.look.content`) and the groups appear one after the other (`index *
  35 ms`, fading and rising `gap(md)` from the edge).
- **Clear all** runs the list out towards the panel's side first (translate
  `0.55 * width`, fade, `duration("base")`), then clears the queue; the empty
  card fades in on the same beat. No search field: the header holds the muted
  list, the stats, Do Not Disturb, Clear all and close.
- Grouped by app (`groups.js`, tested in `tst_notification_groups.qml`): groups
  by their newest arrival, rows newest first. Two nested levels: the outer
  card is the application (ONE raised background with `root.pad`, hover lift,
  holding a header: app icon, app name, count when > 1, clear-group button,
  chevron) and, inside it, one `NotificationEntry` per notification (a smaller
  raised card with a foreground tint so it reads apart from the group, also on
  an opaque surface). The entries are ONE never-reset Repeater; a group starts
  closed and shows only its newest entry, the chevron or a click anywhere on
  the outer card that is not an entry or a button opens it (the group's
  MouseArea sits under the content, the entries' own MouseArea and buttons take
  their clicks first). Open shows all in a Flickable capped at `Groups.BODY_MAX`
  (400 px, design spec, scrolls past it), its height gliding with
  `duration("base")`. A new entry fades and slides in from the delegate; the
  panel is `settled` shortly after first shown so opening does not animate the
  whole list. No ListView `displaced` transition: with bodies that change
  height it leaves groups overlapping. `ListModel.move` needs the third
  argument (`move(from, to, 1)`).
- `NotificationEntry` (panel only; the toast keeps `NotificationCard`): avatar
  circle, summary (medium, elided), age, x button (`removeRequested` ->
  `queue.dismiss(nid)`: dismisses a live one, forgets an expired one), the body
  (StyledText, 6 lines, links open externally) and the picture. Click = default
  action, middle click = remove. App actions and the inline reply are always
  shown on a live entry; "mark as read" is the x. An expired entry keeps its
  place and loses only the live actions.
- Image rule (`Groups.imageSlot(image, width, height)`): an image shows in
  exactly one place. No image: `none`. Size unknown (not loaded yet) or aspect
  `max/min <= Groups.AVATAR_ASPECT` (1.25, design spec; exactly 1.25 still is
  one): `avatar`, the circle (chat and contact avatars are square). Otherwise
  `picture`: under the text, full inner width, aspect kept
  (`Groups.pictureHeight`), at most `Groups.PICTURE_MAX` (240 px, design spec),
  rounded with `radius * 0.6`; the circle then shows the app icon. The size
  comes from the one `Image` that is the picture (always loaded, hidden unless
  the slot is `picture`, `asynchronous`); a failed avatar falls back to the app
  icon. Rounded clipping is `ClippingRectangle` (GPU only: it renders nothing
  under `QT_QPA_PLATFORM=offscreen`).
- Hidden on a fullscreen workspace and on every monitor but `notificationScreen`.

## Look

- Position pref `notificationPosition` = `top|bottom` + `-left|-center|-right`
  (default `top-right`); `notificationMax` from `tokens.ranges.notifications`.
- One container holds the cards: a frame tab when docked, a `VitrailSurface`
  island when floating. Cards: `surfaceHigh` at the surface variant's `raised` alpha
  (`raisedHover` hovered; opaque cards take a tint), radius
  0.85 × token, app icon in a 10 % foreground circle (`info` glyph fallback).
- Toast card (`NotificationCard`): collapsed: title • age (`now`, `%1 min`,
  `%1 h`, ticking every 30 s) and one body line; expanded: app • age, title,
  body up to 6 lines (StyledText), actions as `text` buttons (app actions,
  reply, mark as read).
- The newest toast is expanded; the chevron sets `userExpanded`, which wins.

## Which monitor

- `shell.notificationScreen`: the focused monitor, unless its active workspace
  has a fullscreen window; then the primary screen, any other screen without
  one, and only if all are fullscreen the focused one anyway. The panel and
  the frame tab follow it.
- `shell.toastScreen`: the screen the toasts appeared on. It is set when the
  first toast arrives and cleared when the last one closes, so a stack never
  moves to another monitor mid-flight: a new notification joins the ones
  already on screen. Docked on an islands bar the
  stack hangs from `layout.dock` (below the islands) where it overlaps an island,
  and from the thin frame where it does not (`Frame.stackRect(..., islands)`).

## Behaviour

- Click → the `default` action (focus the app); middle click or a sideways
  flick past a third of the width → `dismiss()` (mark read).
- Expires (`expire()`) after 5 s; hover, a swipe in progress or a reply
  hold it, and the countdown restarts from zero when released.

## Do Not Disturb

- **The bell** (`bar/notifications/NotificationButton.qml`) sits beside the
  launcher in the bar's start group, in the bar's flow (below it on a vertical
  bar). Left click opens/closes this monitor's panel
  (`shell.toggleNotifications`). Right click silences everything for an hour:
  `notificationDnd = true` plus `notificationMuteUntil` (epoch ms) in
  `bar.ini`; a second right click turns it back on. A 30 s timer ends the hour
  by itself, and the panel's own Do Not Disturb button clears the expiry (a
  manual answer wins). Its tooltip names the state and the two clicks.
- A button in the panel's header, next to `Clear all`: `notifications_off`,
  primary tone while it is on.
- `notificationDnd` in `bar.ini`. While it is on, arrivals join the panel's
  history and are never raised as a toast. An urgent notification with
  `notificationUrgentBypass` still toasts.
- The bar reads preferences with its own line-based parser (`bar/prefs.js`)
  and cannot write them, so the button writes through `vitrail config set`.

## Widgets slot

`NotificationPanel`'s default property is the column under the list. Two
widgets today:

- `bar/session/SessionRow.qml`: lock, log out, reboot and power off, taken from
  `bar/session/actions.js`; the commands stay in the shell (`runSession`).
- `bar/notes/QuickNotes.qml`: a field that appends a note and the last three,
  newest first. The value is one JSON array on a single line (`misc.ini`),
  because the bar's preference reader is line based.

The panel window takes the keyboard on demand, so the notes field can be typed
into.
