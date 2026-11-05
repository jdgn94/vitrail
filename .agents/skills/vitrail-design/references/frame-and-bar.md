# Frame and bar

- `VitrailFrame` = full-screen fill minus the content hole (`OddEvenFill`),
  plus a glass stroke along the hole. Hole outline: `Frame.holePath()`.
- Bar variants (`VitrailVariants.bar`):
  - `docked`: the bar is the thick side of the frame (`hole[edge] = bar`).
    No own surface; slot padding clears the inner corners (`border + radius`).
  - `floating`: own `VitrailSurface` island, inset `border + gap` from the
    screen edge; reserves `border + gap + bar`.
  - `islands` (docked): the frame stays `border` thick (`hole[edge] = border`)
    and rises to the full bar thickness under each slot group (start / centre /
    end, empty ones skipped) as tabs of the frame; start and end islands are
    stretched into the screen corners. `reserve[edge] = bar`, so windows keep
    clear of them. Input mask = the three islands (`bar.startMask` …), not the
    whole strip.
  - `floatingIslands`: like `floating`, but one `VitrailSurface` pill per
    group instead of one long bar.
  - `Frame.islands(groups, edge, w, h, { bar, pad, inset }, merge)` turns the
    group content rects into island rects (pad = bar style gap).
  - `layout.dock[edge]`: where docked cards (popup, notification stack) hang
    from: `hole`, or `bar` past the islands, so they rise out of an island.
- Panels (`VitrailVariants.panel`): `full` grows `hole[edge]` (attached, follows
  the frame's animated insets); `overlay` is a floating island under the bar.
- `holePath` walks each edge as a depth profile: the tabs on one edge are
  merged (max depth per interval, equal neighbours joined) so a popup rising
  out of an island, or any overlap, is one outline. Every step is rounded with
  `min(R, |b - a| / 2, half the flats on both sides)`: the corner at the
  shallower depth bends like a base fillet (sweep 1), the deeper one like a
  tab corner (sweep 0). A profile touching an end of the edge takes that
  corner.
- Insets/corner animate in `VitrailFrame` (`leftInset`…, `corner`); anything
  glued to the frame must follow those animated values.

## Bar layout document

`bar/layouts.js` is the one model of what the bar draws (and, later, the panel,
the desktop and the lock screen). It holds:

- `WIDGETS`: `{ id, surface, group, label }` for every element of each
  surface. `group` is `start`, `center` or `end`; `label` is the i18n key.
- `CLUSTERS`: elements that share one pill while they are neighbours
  (`network`, `bluetooth`, `vpn`, `profile` → `connections`).
- `defaults(surface)`, `sanitize(text, surface)`, `effective(text, monitor,
  base, surface)`, `visible(group, hidden)`, `entries(group, hidden, surface)`,
  `move(order, id, delta)`, `toggle(hidden, id)` and `write(text, monitor,
  patch, surface)`.

The document lives in `bar.ini` (`barLayout`), one JSON object:

```json
{ "order": { "start": ["launcher", "notifications"],
             "center": ["media", "clock"],
             "end": ["recording", "tray", "network", "bluetooth", "vpn",
                     "profile", "battery", "keyboard", "power"] },
  "hidden": ["capture"],
  "density": "comfortable",
  "hideFullscreen": true,
  "monitors": { "DP-1": { "hidden": ["tray"] } } }
```

- Empty or invalid is `defaults()`: today's bar. `capture` (a region
  screenshot button) is the one element hidden by default.
- `sanitize` completes every group, drops unknown and duplicate ids and checks
  the types; it never loses an element.
- A monitor's `order` or `hidden` **replaces** the global field; a monitor
  without one follows the global value. The editor writes the whole field.
- `density` is `comfortable` or `compact`; `VitrailBar` scales its gaps with
  `VitrailTokens.density` and never the font.
- `hideFullscreen` (default true) hides the bar and the frame while the
  monitor's active workspace has a fullscreen window (`Hyprland.monitorFor`).

`bar/shell.qml` renders each group with a `Repeater` over `entries(...)`; a
`Loader` instantiates the element's `Component` (`widgetComponent(id)`) and
registers it in `monitor.loaded`, which `monitor.anchorFor(kind)` uses for
popups opened without a button. The settings window's Bar → Editor tab edits
the document (`shell/pages/BarPage.qml`), with a monitor selector, per-group
switches and arrows, density and the fullscreen switch.
