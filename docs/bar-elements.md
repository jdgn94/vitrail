# Bar elements

A bar element is its button, its popup and its data. `bar/BarElementBase.qml`
draws the button, `bar/BarSnapshot.qml` brings the data from Python, and
`bar/elements.js` holds the shared logic. `bar/sample/` is the reference: copy
it, then rename. Names below use `<id>` for the element's id (`sample`).

## The pieces

| Piece | File | What it owns |
|-------|------|--------------|
| Button | `bar/<id>/<Id>Button.qml` | root `BarElementBase`; binds `tooltip`, `tooltipDetail`, `active` to live data |
| Popup | `bar/<id>/<Id>Panel.qml` | the body only (the card is shared); `VitrailPopupGear` last in its first row, `signal settingsRequested()` |
| Data | `vitrail/<id>.py` + `BarSnapshot` | `python3 -m vitrail.<id> state` → one JSON object, polled while the element is in a bar |
| Settings | `shell/pages/BarElementsPage.qml` | one `BarElementSection` per element; its gear lands there |

### `BarElementBase`

| Member | Use |
|--------|-----|
| `icon`, `text`, `tone`, `size` | the button's face (`text` empty: icon only; `size` defaults to `sm`) |
| `tooltip`, `tooltipDetail` | live, from real data. Both are required (`tests/test_tooltips.py`) |
| `showMode`, `active`, `shown` | `shown` is true unless `showMode` is `"active"` and `active` is false. The shell binds `showMode`; the element binds `active` |
| `opened` | this element's popup is open (the button turns tonal) |
| `clicked`, `middleClicked`, `rightClicked`, `wheeled(int delta)` | the four inputs; `delta` is `angleDelta.y` (120 per notch, up positive). Wire the ones the element uses |
| `content` | a `Component` that replaces the button (a dot, a pair of bars); the root sizes from it and a left click still emits `clicked` |
| `strings`, `t(key)` | the translations; do not copy `t()` into the element |

Do not name a property `data` in an element: `Item.data` is the children list.
Call it `snapshot`.

### "Only while active"

Every element offers two modes: **always** (the default) and **only while
active** (hidden whenever its `active` is false: no data, nothing to report).
The choice is the `barActiveOnly` preference, one JSON array of element ids in
`bar.ini`; `BarElementSection` writes it and the shell reads it with
`Elements.showMode(shell.activeOnlyIds, "<id>")`. An element decides what
"active" means: the dot of the privacy indicator is `active: anyUse`, the
sample's is "the last snapshot has no error".

### Snapshots

`vitrail/<id>.py` follows `vitrail/sample.py`:

- `state()` returns a dict of numbers, booleans and short codes, no words (words
  are translated in QML). Cache it on disk so a poll is cheap.
- A failure is data: `{"error": "<code>"}`, or a normal snapshot with `error`
  when part of it is usable. `main()` always prints one JSON object and never a
  traceback; exit 0 for a usable snapshot, 1 with an `error`, 2 for usage.
- `BarSnapshot { module: "<id>"; interval: ...; active: shell.barShows("<id>") }`
  runs it one at a time while the element is in a bar, and turns anything that
  is not a JSON object into `{"error": "unreadable"}`.

An element with no Python side (the volume reads Quickshell's own services)
skips this part and keeps the rest.

## Adding an element

1. `bar/widgets.js`: `{ id: "<id>", surfaces: ["bar"], group: "end",
   labelKey: "bar.widget.<id>", icon, sizes: [], styles: [] }`, placed where it
   belongs by default (an old saved layout appends it to the end of its group).
2. `bar/layouts.js`: add `"<id>"` to `DEFAULT_HIDDEN.bar`.
3. Button and panel in `bar/<id>/`, from `kit/` only: no literal colour, radius,
   duration or spacing. Add `import "<id>"` to `bar/shell.qml`.
4. `bar/shell.qml`: a `BarSnapshot` if it has data; a `Component { id:
   <id>Widget }` next to `sampleWidget` (click → `togglePopup`, hover →
   `tooltips.hover` + `hoverPopup`, `showMode`); `case "<id>"` in
   `widgetComponent` and in the anchor function; a `Popout { name: "<id>" }` and
   its `Component`; `onSettingsRequested: shell.openSettingsAt("bar-elements",
   "<id>")`. Popup kinds must agree (`tests/test_bar_popup_kinds.py`).
5. Preferences of its own: `vitrail/prefs.map` first, then `shell/Prefs.qml`,
   and the README's "Preference files" table. Name them for the area
   (`volumeStep`), not for the element's file.
6. Settings: a `BarElementSection { elementId: "<id>" }` in
   `shell/pages/BarElementsPage.qml` with its own rows inside; an entry in
   `shell/search.js`; the gear in `tests/test_popup_gear.py` (`POPUPS`).
7. Words in all six `kit/i18n/*.json`: `bar.widget.<id>` (the label, also the
   section's title) and the tooltip's. Placeholders (`%1`) must match.
8. Programs it runs: `packages/*.txt`, `tests/test_dependencies.py`, the
   README's "Runtime dependencies" table.
9. Gallery: its button and panel in `gallery/Main.qml`.
10. Tests: QML (`tests/qml/tst_<id>.qml`: the logic and the button's states),
    Python for its module, and `tests/test_bar_elements.py` already checks the
    wiring above for every `BarElementBase` button.
11. Docs: a line in `docs/features.md`, a checklist in `docs/manual-checks.md`.

Run `uv run python -m unittest discover -s tests` and `bash tests/qml_smoke.sh`.

## The sample

Hidden by default. Show it in the bar's editor, or turn it on from Settings →
Bar elements. Its popup shows the snapshot's run number and time, and the gear
opens its block in Settings → Bar elements. Its snapshot changes every five
minutes, which is enough to see "only while active" work: break the cache folder
and the element disappears.
