# Wallpaper styles: dots, ascii, and a charcoal that follows the theme

Requested in chat (2026-11-19):

- A **dots** style: classic pointillism — the picture as round dots of the
  photo's colours on a canvas, with small but visible canvas gaps.
- An **ascii** style: the picture drawn with coloured ASCII characters.
- **charcoal** adapts to the theme: dark mode is a black ground with white
  lines, light mode is the paper with dark lines it has today.
- Both new styles' canvas/background follow the theme too (cream in light,
  black in dark).

Decisions taken while designing:

- `dots` and `ascii` cannot be an argv list handed to `magick`: they need a
  computed cell size and, for ascii, a text grid. They are *styled* effects
  with a renderer function; the plain recipes stay exactly as they are.
- The cache and the `wallpaper.applied` stamp must name the light/dark mode
  and the detail, or switching the theme would keep the old picture.
- The picker's thumbnails use a minimum cell of 6 px, so the style is legible
  at 112 px wide.
- The system palette is taken from the original photo for styled effects: the
  white canvas of dots would otherwise wash the colours out.
- `wallpaperEffectDetail` (fine / normal / bold) is the one value worth a setting; it
  moves the dot size and the ascii column count.

## Tasks

- [x] 1. `vitrail/effects.py`: ordered `NAMES`, `STYLED` renderers for `dots`
      and `ascii`, `mode`/`detail` parameters through `apply`/`derive`/
      `cached`/`preview`/`publish`, theme-aware `charcoal` (`-negate`), cache
      suffix per mode/detail.
- [x] 2. `vitrail/wallpaper.py`: mode and detail in the stamp, forwarded to
      the effect, palette taken from the original for styled effects.
- [x] 3. `vitrail/wallpaperd.py` + `vitrail/cli.py`: forward mode and detail to
      the derivation.
- [x] 4. `bar/effects.js`: the two new names.
- [x] 5. Preferences: `wallpaperEffectDetail` in `vitrail/prefs.map`, `shell/Prefs.qml`;
      the row in `shell/pages/WallpaperPage.qml`.
- [x] 6. `kit/i18n/*.json` (six languages): the two effects, the detail row.
- [x] 7. Tests: mirror list, charcoal in dark mode, cache per mode/detail, the
      stamp, the styled renderers with real magick.
- [x] 8. Docs: README effects paragraph, CHANGELOG.
- [x] 9. Verify: `uv run python -m unittest discover -s tests`,
      `bash tests/qml_smoke.sh`, `uv run ruff check .`.
- [x] 10. Preview fix (asked in chat, 2026-11-19): at the picture's own scale a
      dot is a quarter of a pixel in a 112×64 tile, so the picker showed black
      or washed squares. A preview now pulls back to `PREVIEW_ACROSS` dots or
      characters across, `VERSION` names the drawn styles' cache so the copies
      already on disk are rewritten, and the wallpaper itself is untouched.
- [x] 11. `pointillism` (asked in chat, 2026-11-19): the painters' technique —
      dots of 6/9/13 px at 1920 (fine/normal/bold), one pixel of ground between
      them, each dab the average colour of its cell plus a little saturation.
      `dots` is untouched. The renderer is shared with `_dotted`; names in
      `NAMES`, `DETAILED`, `MODED`, `bar/effects.js`, i18n and README.
- [x] 12. Pure colour per dab (asked in chat, 2026-11-19): `-sample` instead of
      `-resize` for the pointillism grid, so a dab is one pixel's colour and
      never an average; the grid is whole cells rounded up and the overhang is
      cropped, so no dot straddles two colours. `VERSION` 4.
