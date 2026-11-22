# Toasts take the panel's exit: the notification side, under a top bar

- [x] Confirm the reading with the user (side exit, not the panel's card layout)
- [x] Add `Notifications.stackEdge` + tests (`tests/qml/tst_notifications.qml`)
- [x] Wire the stack's exit edge, tab and origin in `bar/shell.qml`
- [x] Record the rule in `.agents/skills/vitrail-design/references/notifications.md`
- [x] Verify: qmltests, Python suite, `tests/qml_smoke.sh`, offscreen frame render

## Request

Incoming toasts should have the notification panel's style when the bar sits
on the edge they come out of (a bar at the top, the toasts also at the top).
The toast used to be a tab of the top edge, so its frame tongue fused with the
bar's end island. The user chose: it comes out of the notification side
instead, below the bar, like the panel. Size and position (top-right) stay.

## Change

- `Notifications.stackPosition(side)` takes the resolved side (pure); the shell
  feeds it `monitor.notificationSide`, so both the stack and the panel follow a
  monitor's own side override.
- `Notifications.stackEdge(side, barEdge, docked)`: the top, unless the bar is
  docked there; then the notification side.
- `bar/shell.qml`: the stack's frame tab uses `stackHolder.edge`; out of the
  side it is the whole rect (only the depth reveals, like the panel) rather
  than a liquid rect growing from a drop, and `origin` is null. A floating bar
  keeps the old behaviour (the island grows out of the bar).
- The corner where the bar's island meets the side tab is the same hand-off
  fixed in `notification-panel-corner.md`; the frame path stays simple at every
  reveal step.

## Not changed (user's choice)

The toast's card layout (`NotificationCard`: app · age, title, body, actions)
stays; only the frame/exits style follows the panel.
