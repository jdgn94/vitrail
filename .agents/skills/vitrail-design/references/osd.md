# OSD: volume, microphone, brightness

Files: `bar/osd/` (`OsdLayer.qml` per monitor, `OsdController.qml` once,
`OsdCell`, `DeviceCard`, `BrightnessCard`, `BrightnessState`, `DwellGate`; pure `osd.js`,
`icons.js`, `brightness.js`, tested in `tests/qml/tst_osd.qml`), `vitrail/
brightness.py` (ddcutil / brightnessctl, `tests/test_brightness.py`), tokens
`osd` in `kit/tokens.js`.

## Placement

- Edge opposite the notification stack: `*-right` left, `*-left` right,
  `top-center` bottom, `bottom-center` top (`Osd.edgeFor`). The bar's own edge
  is never taken: it falls back to the top (the bottom when the bar is on top).
- One edge and one centring on every monitor. `shell.qml` computes the edge
  once (`shell.osdEdge`) from the notification position and the PRIMARY
  monitor's bar (`shell.primaryBar`, set by a `Binding` in that monitor's
  scope); each `OsdLayer` just gets `edge` and `reference` (the primary's
  `layout.dock` / `reserve`). `Osd.alignBounds` takes the monitor's own frame on
  the docking side and the primary's along the edge, so a monitor without a bar
  (or with other bounds) shows the panel at the same spot. It still docks as a
  frame tab only where that monitor's bar is docked; otherwise it is an island
  at the same spot. Never derive the edge per monitor.
- Centred along that edge in what the frame leaves (`layout.dock` docked,
  `layout.reserve` + a gap floating).
- Hot zone: invisible strip on the screen edge, as long as the full panel,
  frame border + `osd.hot` thick. Hover opens the panel only after the pointer
  stayed in the strip for `motion.dwell` ms (150) without leaving (`DwellGate`:
  leaving cancels, re-entering restarts the count); once open, the strip, the
  panel or the card keep it open, and it hides `osd.hide` ms after the pointer
  leaves (a held slider keeps it). Media keys / `osd peek` skip the dwell. The
  layer's input mask is only strip + panel + card; every other pixel passes
  clicks.
- Docked (docked / islands bar): the panel is a frame tab (`OsdLayer.tabs`
  goes into `VitrailBar.tabs`); floating: a `VitrailLiquidSkin` island. Both
  open with `VitrailLiquid` like the popups (liquid in glass, smooth in solid).

## Contents

- Side edge: a column of vertical `VitrailSlider`s (`orientation: Qt.Vertical`),
  icon above, percentage below. Top / bottom edge: a row of horizontal ones,
  icon first, percentage last. The icon of volume / microphone is a mute
  button; brightness has none. Icons follow state (`icons.js`).
- Mouse wheel over a slider moves it `osd.step` % a notch (up / right more),
  in the panel and in the brightness card: `VitrailSlider.wheelStep` (opt-in;
  0 leaves the wheel to the parent page). Hovering keeps the panel open.
- Hover a slider: a card opens beside it toward the screen interior (liquid
  skin joined to the panel by a neck): output devices (sets the default sink),
  input devices, or one slider per monitor (only with more than one).
- Media key / `osd` IPC / a change from outside (`wpctl`, headset keys): only
  that slider, `osd.key` ms, on the focused monitor (`OsdController.keyed`).
  The panel's own writes are not announced (`quiet`).
- Brightness: `python3 -m vitrail.cli brightness list` (detection cached in
  `~/.cache/vitrail/ddc.json`), written by one debounced `ddcutil setvcp 10`
  / `brightnessctl` process per monitor. Without i2c access, ddcutil or any
  display the slider is dimmed with a tooltip saying why.

## IPC

`vitrail-bar ipc call osd volume up|down|mute`, `mic mute`,
`brightness up|down`, `setBrightness <n>`, `peek volume|mic|brightness`
(only shows the slider). `show` cannot be a function name: `qs ipc` reads it
as its own subcommand. Hyprland binds call these and fall back to
`wpctl` / `brightnessctl` when the bar is not running.

## Gotchas

- A change of the layer's input mask makes Hyprland drop the pointer's hover
  until it moves again: grace timers (`osd.hide`, `osd.extension`) cover it.
- Previews: `OsdLayer { animated: false }` with `mode`, `kinds`, `extKind`
  set by hand (and `edge`), in a ShellRoot beside a `VitrailBar { tabs: osd.tabs }`.
- ddcutil needs `/dev/i2c-*` access: `install.sh` (`setup_display_control`)
  installs `scripts/system/60-ddcutil-i2c.rules`, loads `i2c-dev` at boot and
  adds the user to the `i2c` group; log out and back in afterwards.
- Live checks: `hyprctl dispatch 'hl.dsp.focus({ monitor = "DP-2" })'` (Lua
  syntax) moves the focus (and cursor) to a monitor, then
  `qs ipc --path bar/shell.qml call osd peek volume` and `grim -o DP-2`. A
  pointer resting on the strip makes the full panel open after the dwell.
