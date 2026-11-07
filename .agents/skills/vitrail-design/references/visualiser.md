# Audio visualiser

The desktop's audio spectrum in the background layer, under the wallpaper and
the windows. Source: `screenshots/inspired/visualiser-{a,b,c}.png` (review
captures, not tracked).

## Layers

```
vitrail/visualiser.py              cava supervisor -> $XDG_RUNTIME_DIR/vitrail/cava.json
kit/tokens.js                      visualiser.* + ranges.visualiserHeight
kit/visualiser.js                  values, levels, radial and wave geometry (pure)
kit/VitrailVariants.qml            visualiser: bars | reflection | panel | circle | waves
kit/base/VitrailBars.qml           one rounded bar per level, optional mirror
kit/base/VitrailRadial.qml         one rounded bar per level, around the centre
kit/base/VitrailWaves.qml          one polyline per line, across the strip
kit/composed/VitrailVisualiser.qml VitrailSurface (panel) + the primitive of the look
bar/shell.qml                      background PanelWindow, per monitor
```

## The five looks

- `bars`: the bars stand on the bottom edge. No container.
- `reflection`: the bars stand at `visualiser.reflection.baseline` and a
  mirrored copy fades below them (`fade`, `reach`, `gap`).
- `panel`: the bars sit inside `VitrailSurface` with `panel.padding` of room
  and `panel.radius` times the shell radius. Same bars, a container.
- `circle`: `visualiser.circle.count` bars around the centre, growing outward
  from `inner` to `radius` (a share of the strip's half height); `coverage` is
  the share of each angular cell a bar keeps.
- `waves`: `visualiser.waves.lines` polylines across the strip, each sampling
  `count` levels; `amplitude`, `spread`, `fade` and `thickness` shape them.

The component keeps `variant`/`values`/`bars`/`tint`/`opacityLevel`; the
resolved `look` comes from `VitrailStyle.resolve("visualiser", variant)`, so an
unknown name falls back to `bars` and a new variant needs no component change.
`look.shape` (`bars` | `circle` | `waves`) picks the primitive; `reflection`
and `panel` decorate the bars look.

## Rules

- Only tokens for sizes, gaps, radii, opacity and motion; the bar colour is
  `VitrailTokens.color("primary")` (never a literal).
- `bars` and its `reflection` variant are two `Repeater`s in the base
  component: the composed layer owns no `Rectangle`.
- The circle and wave geometry is pure (`kit/visualiser.js`, tested in
  `tests/qml/tst_visualiser.qml`): `radial` returns one bar per level with its
  centre, length, thickness and rotation; `wave` returns one point array per
  line.
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
