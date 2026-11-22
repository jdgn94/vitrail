# Wallpaper effects and colours in the settings dialog

Requested in chat (2026-11-14):

- The system-colour selector gains Material's main colours (one per hue, no
  tonal steps) and a custom colour, laid out as an ordered grid.
- Each effect shows a preview of the picture the output displays now, in the
  dialog only. Videos take no effect.
- Effects work globally and per output.
- Bug: effects did not apply and left a white monitor.

Causes found:

1. `vitrail/wallpaper.py` stamps `wallpaper.applied` without
   `wallpaperMonitors`, so a per-output effect never regenerates its stable
   `wallpaper-effect-<output>.png`; the bar points at a file that never
   exists.
2. QML never retries a picture that failed to load, so even when the copy is
   written the layer stays blank until a restart.

## Tasks

- [x] 1. `vitrail/effects.py`: `preview()`, `publish()` (one 320 px copy per
      recipe under `previews/<slot>/`), `slot()`; `previews` folder.
- [x] 2. `vitrail/wallpaper.py`: stamp includes `wallpaperMonitors`; the early
      return also requires the shown copies and the previews to exist; publish
      previews for the global slot and every output with its own picture.
- [x] 3. `bar/effects.js`: `slot()` mirroring the Python sanitiser.
- [x] 4. `bar/shell.qml`: watch `wallpaper.applied` and bump a revision the
      effect URL carries, so the layer reloads the copy once it is on disk.
- [x] 5. `shell/pages/WallpaperPage.qml`: Material colours + custom colour
      (`ColorDialog`), effect preview grid (global and per output), settings
      reordered; `shell/main.qml` passes `cacheDir`.
- [x] 6. `kit/i18n/*.json` (six languages): custom colour, preview help.
- [x] 7. Tests: per-output effect regenerates, a missing copy is rebuilt,
      previews for every recipe and slot; `effects.js` slot parity.
- [x] 8. Docs: design reference `wallpapers.md`, CHANGELOG.
- [x] 9. Verify: python suite, `tests/qml_smoke.sh`, settings selftest grab of
      the wallpaper page, live effect on both outputs.

## Result

- `effects.py`: `preview()`, `publish()`, `slot()`; `sunken` raised upside down
  (ImageMagick 7 refuses `-raise -10x-10`); `apply()` raises when magick writes
  nothing, and `wallpaper.apply` then copies the plain picture, so the layer
  never points at a missing file.
- `wallpaper.py`: the stamp carries `wallpaperMonitors`; the early return also
  asks for the shown copies and one preview per slot; previews are published
  for the whole screen and every output with its own picture.
- `bar/shell.qml`: the stamp is watched and `wallpaperRevision` rides in the
  picture URL (`?v=N`) — QML never retries a failed load.
- `WallpaperPage`: Material 500 colours + `ColorDialog` custom chip in a
  wrapping `Flow`, preview grids (global and per output), settings reordered
  (fit, order, interval, strip, colour, effect, monitors, library).
- i18n in six languages, docs, CHANGELOG. 967 Python tests, 1138 QML tests and
  the 93 smoke checks pass; the dialog and the bar verified live.

## Follow-up (same day)

- The effect is one global choice again (no per-output effect): it applies to
  whichever picture each output shows, and `wallpaperMonitors` keeps only the
  picture. `parse_monitors`, `wallpapermonitors.js`, the daemon and the bar were
  simplified with it.
- The page keeps the compact row style: the effect row opens a modal picker
  (five previews per row); the inline grid is gone.
- Automatic is a chip like the presets, carrying the first letter of its name.
- The system colour sits under the animation length; that slider is stepped and
  reaches 10 s (`snap`, 0.2–10 s).

## Follow-up 2 (same day)

- `VitrailPicker` is now the one picker for every choice made by sight, with
  two triggers kept as variants: the `large` card (icon and cursor pages, their
  style untouched) and the select field with a chevron (fonts, effects). Cells
  gain `cellArtWidth`/`cellArtHeight` for one wide, rounded picture.
- The wallpaper effect row is that picker (`triggerPreview: false`), so the
  inline grid and its own popup are gone; the dialog lays the 18 recipes five
  per row.
- The automatic colour is a chip with the first letter; the system colour sits
  under the animation length; that slider snaps and reaches ten seconds.
