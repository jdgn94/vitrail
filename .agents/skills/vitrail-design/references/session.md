# Session menu

- Power button (`bar/session/PowerButton.qml`), last of the end group
  (`BarItems`). Left click: full-screen menu on that monitor
  (`shell.toggleSession(screen)`); right click: popout kind `power`
  (`SessionPopout`: icon + label rows, pill hover, destructive in `error`).
- `bar/session/actions.js` is the one table: key, i18n label (`session.*`),
  icon, tone, shortcut letter, command. `hibernate` is offered only when
  `systemctl --dry-run hibernate` exits 0 (checked once at startup).
- `SessionMenu.qml`: backdrop `VitrailSurface` (glass: translucent for the
  compositor blur; the `vitrail-session` namespace is in the glass layer
  rule), greeting + time, a row of `xl` tonal round buttons with labels.
  Arrows / Tab move the ring, Enter / Space run, a letter (l o s h r p) runs
  its action, Escape or a backdrop click dismisses. Opening fades and scales
  in; the window stays up while it fades out.
- Running an action closes the menu and popout first, then
  `Process.startDetached`. IPC: `vitrail-bar ipc call session toggle` opens it
  on the focused monitor. Tests: `tests/qml/tst_session.qml`.
