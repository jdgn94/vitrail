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
- Running an action closes the menu and popout first. A lock runs at once;
  every action that would cut work goes through the guard first
  (`vitrail/session.py`: a download the watcher knows, a package manager, a
  job registered by `vitrail/jobs.py`). With something running,
  `SessionConfirm.qml` lists it and offers Cancel / Go ahead; after that —
  except for log out — a 30 s countdown shows Cancel / Do it now and runs the
  action by itself at zero. Same `SessionConfirm` draws the countdown: icon,
  the action's label and the seconds, a bar that empties, Escape cancels (and
  returns to the menu), Enter confirms. The check, the countdown and the
  command live in the shell (`runSession`, `sessionChecked`, `beginSession`,
  the timer); the menu only reports the key.
- IPC: `vitrail-bar ipc call session toggle` opens it on the focused monitor.
  Tests: `tests/qml/tst_session.qml`,
  `tests/qml/tst_session_confirm.qml`, `tests/test_session.py`.
