# Wallpaper transitions

Approved in chat (2026-11-14). The wallpaper arrives with a short, randomly
chosen animation — the ink dissolve and the outline drawn before the fill, as in
the reference video — and the palette waits for the animation to end. The cards
from the reference video are its picker carousel and stay out.

Decisions already made with the user:

- Same picture on both outputs → the same animation, at the same time. Different
  pictures → each output its own. A deterministic spec from the incoming path
  gives both without shared state.
- The palette still comes from the global picture; with a fixed system colour it
  does not change when the wallpaper rotates (only light/dark and scheme).
- The palette is applied when the animation ends, not when matugen finishes.

Out of scope: per-output rotation and effects over videos.

- [x] 1. `kit/shaders/wallpaper-transition.frag` + baked `.qsb`
      (`qsb --qt6`), `scripts/build-shaders.sh`, `tests/test_shaders.py`
      (bakes the source and compares bytes; skips without qsb).
- [x] 2. `kit/wallpaper.js`: deterministic spec from the incoming path —
      `random|none|fade|ink|outline`, duration ±15 % of the setting, origin,
      seed. `tests/qml/tst_wallpaper_transition.qml`.
- [x] 3. `kit/base/VitrailWallpaper.qml`: keep the leaving picture while the
      transition runs; shader crossfade for image→image (ink, outline, fade),
      instant for videos and for the first load. The clouds/outline come from
      the shader, the palette from the shell as before.
- [x] 4. `bar/shell.qml`: pass the transition prefs to every wallpaper layer;
      hold the new palette until the outgoing spec's duration has passed
      (`paletteHoldUntil`, pending text + timer) instead of applying it as soon
      as `palette.json` changes. Same hold in `shell/main.qml` for the settings
      window's own palette.
- [x] 5. `kit/tokens.js` range, `vitrail/prefs.map`, `shell/Prefs.qml`,
      `shell/pages/WallpaperPage.qml` (transition select + duration slider,
      disabled for "none"), `kit/i18n/*.json` in all six languages.
- [x] 6. Docs: `vitrail-design/references/wallpapers.md` (shader, spec,
      palette hold, limits), README and CHANGELOG.
- [x] 7. Verify: QML test, shader test, `bash tests/qml_smoke.sh`, full Python
      suite, and a real grab of the two animations on the bar.
- [x] 8. Effects: the bar keeps the previous picture until the applied stamp
      (`wallpaper.applied`) names the effect and its stable copy exists, then
      moves to the effect URL and runs the same animation. The stamp also
      rebuilds a lost copy. The palette is held through the effect pass and the
      animation, in the bar and the settings window.
