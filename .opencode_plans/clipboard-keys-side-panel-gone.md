# Clipboard keys, and the empty side panel goes

Asked in chat (2026-11-20):

- Delete the `panel` IPC command and the side panel: it holds nothing, and the
  notification panel will use that surface later.
- `Super+P` opens the clipboard menu on the picker (the Colours tab) and
  `Super+Shift+P` activates the picker (hyprpicker).
- `Super+V` opens the clipboard menu; the command it had (float a window) moves
  to another key.
- `Super+.` opens the clipboard on the emojis.
- Remove `Super+Shift+.` and `Super+Alt+.` / `Super+Ctrl+.`: the combinations
  are being remapped, not aliased.

Calls taken while building:

- Float a window moves to `Super+Shift+V` (free).
- The panel's depth token and the `panelSize` setting stay: the notification
  panel is that wide. The setting moves from the deleted "Side panels" section
  to Bar → Notifications, labelled "Notification panel width".
- The notifications panel itself is untouched: it keeps sliding over the edge.
  Attaching it to the frame is a separate request (and would need its own
  decision about pushing windows, now that `panelPush` is gone).

## Tasks

- [x] 1. `dots/.config/hypr/hyprland.lua`: the four clipboard binds, float on
      `Super+Shift+V`, and the three old clipboard combinations removed.
- [x] 2. `bar/shell.qml`: `panelKind`, `panelOpen`, `panelPush`, the `panel`
      IPC handler and the props passed to the bar.
- [x] 3. `kit/composed/VitrailBar.qml`: the panel surface, its props and the
      `Frame.layout` panel argument.
- [x] 4. `kit/frame.js`: the panel parameter, its geometry and its field.
- [x] 5. `kit/VitrailVariants.qml`, `kit/VitrailStyle.qml`: the `panel` table
      and its default. `kit/tokens.js` and `VitrailTokens.qml` keep `panel`
      (the notification panel's width).
- [x] 6. `shell/Prefs.qml`, `vitrail/prefs.map`, `shell/pages/BarPage.qml`:
      `panelPush` gone, the width slider moved to Notifications.
- [x] 7. `kit/i18n/*.json` (six languages): `bar.panelPush` and
      `bar.section.panels` out, `bar.panelSize` reworded, `wallpaper.fit.help`
      now names the notification panel.
- [x] 8. Gallery, `tests/qml/tst_frame.qml`, `tests/test_design_system.py`,
      `tests/test_editor_bar_panel.py`: drop the removed surface.
- [x] 9. Docs and skills: README (keys, prefs table, Panels section), features,
      manual checks, CHANGELOG, `vitrail-design` references.
- [x] 10. Verify: python suite, `tests/qml_smoke.sh`, gallery grab,
      `hyprctl reload` and the live bind list, and the settings grab of Bar.
