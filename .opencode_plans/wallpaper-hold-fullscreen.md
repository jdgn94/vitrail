# Wallpaper holds still under a fullscreen window

Requested in chat (2026-11-19): a fullscreen app or a game should not compete
with the wallpaper — the video wallpaper pauses, the automatic rotation waits,
and nothing else in the background keeps working while the screen is covered.

Decisions taken while designing (mine, said out loud in chat):

- The trigger is the one the bar already uses for hiding: the active
  workspace's `hasFullscreen` on that monitor (Quickshell/Hyprland). A merely
  maximised window does not count.
- The rotation is global (one selection for every output), so it waits when
  *any* screen is fullscreen; the video pauses only on the screen that is
  covered.
- The change animation is skipped too: it would run under the game for nobody
  to see.
- The cava visualiser stops as well — it is the biggest CPU cost of the
  background and it is invisible under a fullscreen window.
- One switch in Settings → Wallpaper (`wallpaperPauseFullscreen`, on by
  default) turns the whole behaviour off.
- The `mpvpaper` path (`vitrail wallpaper show`, used outside the bar) gets
  mpvpaper's own `-p -a FULL`, but only while the switch is on.

## Tasks

- [x] 1. `kit/wallpaper.js`: `hold(switch, fullscreen)`, the one decision.
- [x] 2. `kit/base/VitrailWallpaper.qml`: `paused` — the video pauses instead
      of playing into a covered screen.
- [x] 3. `bar/shell.qml`: `screenFullscreen()`, `fullscreenAnywhere`,
      `wallpaperHeld`; the rotation timer, the visualiser process and the
      per-monitor wallpaper use them; the notification screen reuses the
      helper.
- [x] 4. `shell/Prefs.qml`, `vitrail/prefs.map`, the row in
      `shell/pages/WallpaperPage.qml`.
- [x] 5. `kit/i18n/*.json` (six languages): the switch and its help.
- [x] 6. `vitrail/wallpaperd.py` + `vitrail/cli.py`: mpvpaper pauses too.
- [x] 7. Tests: the QML decision, the mpvpaper flags, the pref map, i18n.
- [x] 8. Docs: README preference table, README wallpaper section, CHANGELOG.
- [x] 9. Verify: python suite, `tests/qml_smoke.sh`, `ruff check`.
