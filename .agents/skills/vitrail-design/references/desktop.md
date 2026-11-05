# Desktop widgets

Widgets on the wallpaper, placed per monitor from **Bar → Elements → Desktop**.
They share the registry and the components of the bar and the notification
panel; the lock screen is not part of this surface yet.

## Where it lives

- `bar/widgets.js` — the shared `WIDGETS` registry. A desktop entry has
  `surfaces: ["desktop"]`, `sizes` (`sm` / `md` / `lg`), `styles` (`full` /
  `compact`, `card` / `plain`, or the player's `disc` / `cassette`) and
  `interactive`.
- `bar/widgets/DashboardClock.qml`, `DashboardCalendar.qml`,
  `DashboardWeather.qml`, `DashboardResources.qml`, `DashboardFocus.qml` — the
  dashboard's pieces, extracted with the common `size` / `variant` API so the
  popup and the desktop draw the same thing. `FocusWidget.qml` is their common
  card. The player, toggles and notes reuse `PanelWidget`.
- `bar/widgets/DesktopWidget.qml` — one host: id → the right component, with
  the registry's width (`widthOf(id, size)`) and the content's height.
- `bar/desktop/DesktopData.qml` — weather/resources services, started once
  while any desktop widget exists.
- `bar/desktop/DesktopLayer.qml` — one `Scope` per monitor. Each placed widget
  is a small `PanelWindow` on the Background layer (`vitrail-wallpaper`
  namespace, so the existing background stack and its blur rule are reused);
  a non-interactive widget has an empty mask, an interactive one takes the
  pointer only inside itself. `hiddenFullscreen` follows the bar's
  `hideFullscreen` switch.
- `bar/layouts.js` — the `desktop` surface: `sanitize`, `effective`,
  `desktopAdd/Remove/Move/Configure`, `desktopCount`, `write`.

## Document

`bar.ini` `desktopLayout`; coordinates are **0..1 from the monitor's top-left**
and are clamped by `sanitize`:

```json
{"monitors": {"DP-1": {"widgets": [
  {"id": "clock", "x": 0.35, "y": 0.30, "size": "lg", "style": "full"}
]}}}
```

An empty document draws nothing. Each monitor has its own list; one widget per
id, unknown ids and duplicates dropped, size/style checked against the
registry.

## Editor canvas

Bar → Elements → Desktop shows the selected output's aspect ratio as a
`VitrailSurface` canvas. A card per placed widget is dragged with a
`DragHandler` (`target` the card, clamped to the canvas); the release writes
the normalised point. Adding is a row of kit buttons for the registry entries
not placed; the rows below the canvas set size, style or removal. The canvas
is the source of truth: the desktop itself is not edited in place.

## Adding a widget

1. Add the entry to `WIDGETS` with `surfaces: ["desktop"]`, its sizes/styles
   and whether it is interactive; add its `DESKTOP_WIDTH` entry if its content
   has no useful implicit width.
2. Build it from kit primitives with `size` / `variant` (or reuse an existing
   component).
3. Add a `Component` to `DesktopWidget.qml`; the registry and the editor pick
   it up automatically.
4. Keep the six `kit/i18n/*.json` files in sync (`panel.widget.<id>`, style
   names) and extend `tests/qml/tst_widgets.qml`.
