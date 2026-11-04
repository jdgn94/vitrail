# Audio visualiser

The desktop's audio spectrum in the background layer, under the wallpaper and
the windows. Source: `screenshots/inspired/visualiser-{a,b,c}.png` (review
captures, not tracked).

## Layers

```
vitrail/visualiser.py              cava supervisor -> $XDG_RUNTIME_DIR/vitrail/cava.json
kit/tokens.js                      visualiser.* + ranges.visualiserHeight
kit/VitrailVariants.qml            visualiser: bars | reflection | panel
kit/base/VitrailBars.qml           one rounded bar per level, optional mirror
kit/composed/VitrailVisualiser.qml VitrailSurface (panel) + VitrailBars
bar/shell.qml                      background PanelWindow, per monitor
```

`circle` and `waves` are planned looks: add them to `VitrailVariants.visualiser`
and the gallery when they are drawn; do not add a flag to the component.

## The three looks

- `bars`: the bars stand on the bottom edge. No container.
- `reflection`: the bars stand at `visualiser.reflection.baseline` and a
  mirrored copy fades below them (`fade`, `reach`, `gap`).
- `panel`: the bars sit inside `VitrailSurface` with `panel.padding` of room
  and `panel.radius` times the shell radius. Same bars, a container.

The component keeps `variant`/`values`/`bars`/`tint`/`opacityLevel`; the
resolved `look` comes from `VitrailStyle.resolve("visualiser", variant)`, so an
unknown name falls back to `bars` and a new variant needs no component change.

## Rules

- Only tokens for sizes, gaps, radii, opacity and motion; the bar colour is
  `VitrailTokens.color("primary")` (never a literal).
- `bars` and its `reflection` variant are two `Repeater`s in the base
  component: the composed layer owns no `Rectangle`.
- The strip width is a fraction of the screen (`visualiser.width`, or
  `visualiser.panel.width` for the panel), capped by `visualiser.maxWidth`;
  `visualiserHeight` comes from the settings and its token range.
- The supervisor runs only while the preference is on and an audio stream is
  playing; the QML hides the strip when `visualiserActive` is false, even if a
  stale JSON file remains.

## Verification

```sh
uv run python -m unittest tests.test_visualiser
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml
QT_QPA_PLATFORM=offscreen bin/vitrail-gallery --theme dark --grab /tmp/gallery.png
```
