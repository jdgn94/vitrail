# Keyboard

Every popup is operable without the pointer: Tab reaches each control, Enter
or Space does what a click does, Escape closes, and focus never leaves the open
popup.

## The popup host

`popupCard` in `bar/shell.qml` holds the keyboard while its popup is up. The
layer stays `WlrKeyboardFocus.OnDemand` (an exclusive layer would swallow the
pointer and no bar button could be hovered): it is exclusive for a beat when it
opens, then on demand, which keeps the keyboard until another surface takes it.
The card calls `forceActiveFocus()` when `popupOpen` or `popupKind` changes, so
keys land in it without a click, and releases the focus when the popup closes.

Escape closes the popup. A tray app's menu closes first and leaves the tray card
up. The popup window contains only the card (and the menu card), so Tab cycles
inside it with wrap and never reaches the bar.

## The focus ring

Every focusable control shows the ring while it has active focus: a transparent
rectangle filling the control, `border.width: 2` when focused and `0` otherwise,
`border.color` the primary (or the control's own ink), same radius as the
control. It is drawn last so the content never covers it and it never shifts the
layout. `kit/base/VitrailButton.qml` is the reference.

## What takes focus

- `VitrailButton`, `VitrailField`, `VitrailSelect`: already focusable.
- `VitrailSwitch`: Tab, Enter or Space flips it.
- `VitrailSegmented`: one stop for the group; Left / Right move the choice.
- `VitrailSlider`: Tab, then the arrows, Page Up / Down and Home / End (the
  control handles them).
- Rows that are a choice (a network entry without a button, a session action, a
  clipboard entry, a notification card): `activeFocusOnTab` on the row, Enter or
  Space triggers it.
- A grid (the tray icons, the emoji browser): the arrows move through it, Enter
  or Space picks; the tray's menu key (or Shift+F10) opens the app's menu.

Nothing decorative takes focus. A popup's first Tab stop is the list or the
first control, never a dead card.

## Full-screen overlays (launcher, session)

- Bind `WlrLayershell.keyboardFocus` (Exclusive) to the window's `visible`, not
  to the delayed `shown` / `open`; otherwise the compositor never hands it the
  keyboard.
- Focus given in `Component.onCompleted` (the launcher's `field.forceActiveFocus()`,
  the session's `focusMenu()` on `open`) survives until the window activates: Qt
  restores it as the active focus item. No callLater / Timer re-focus needed
  (measured: the field had `activeFocus` and was `Window.activeFocusItem` when
  `Window.active` turned true).
- Known limit: the first open after the bar starts can take about 2 s to map the
  layer; keys typed before that go to the previously focused window. That is
  first-frame latency, not focus.
- Testing: `wtype -M shift -k Tab` sends `Key_Tab` with Shift, not `Key_Backtab`
  (a real keyboard sends ISO_Left_Tab). Test backwards Tab with
  `wtype -k ISO_Left_Tab`.
