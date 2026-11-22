# Monitors rework

Approved in chat (2026-11-14). Scope: Monitors page + the two kit controls it
needs + the two pages that receive the moved settings.

- [x] 1. `kit/VitrailSegmented`: per-option `rotation` applied to the icon only
      (`tests/qml/tst_segmented.qml`).
- [x] 2. `kit/VitrailSelect`: popup born on the field, current option at the
      field's height, width from the longest option, clamped to the window
      (`tests/qml/tst_select.qml`).
- [x] 3. `bar/MonitorEditLayer`: no accent frame; badge on every output at the
      top centre; the chosen one says "Configuring". Tokens cleaned.
- [x] 4. `shell/pages/MonitorsPage.qml`: one scroll for the whole page; frozen
      canvas frame while dragging (no re-fit until drop); rotation as a
      segmented control with the monitor icon turned; wallpaper and bar rows
      removed.
- [x] 5. `shell/pages/WallpaperPage.qml`: per-monitor picture and effect moved
      here (`monitors` injected by `shell/main.qml`).
- [x] 6. `shell/pages/BarPage.qml`: per-monitor bar position and style moved
      here (`monitors` injected by `shell/main.qml`).
- [x] 7. Tests updated (`tst_monitors_page.qml`) and all suites green.
- [x] 8. `bar/MonitorEditLayer.qml`: the panel's own `screen` is bound to the
      output (a `screen` property shadowed `PanelWindow.screen`, so every
      badge stayed on the default output); the card is the output's name on
      every screen, as in the reference.
- [x] 9. `kit/VitrailSlider.qml`: `snap` (values on the `stepSize` grid) and
      `decimals` (readout digits); the monitor scale uses both.
