# A scroll for the tabs and the emoji groups

Asked in chat (2026-11-20), with two screenshots: the settings subcategory row
(`VitrailTabs`) and the emoji group row (`VitrailSegmented`) must scroll when
they do not fit.

What was wrong:

- `VitrailTabs` had no scroll at all: a `RowLayout` squeezed its tabs until the
  labels were cut.
- `VitrailSegmented` had one, but `reveal()` ran before the first layout (the
  control starts at width 0), so opening the emoji tab scrolled the row past its
  own first segment and the selection pill appeared half cut — exactly what the
  screenshot showed.

## Tasks

- [x] 1. `kit/VitrailTabs.qml`: the row lives in a `Flickable` (wheel, drag,
      bounds), the underline and the focus ring travel with it, `contentX` /
      `contentWidth` are readable, and the current tab is revealed.
- [x] 2. `kit/VitrailSegmented.qml`: `reveal()` waits for a width and a width
      change reveals the current option again.
- [x] 3. Tests: wheel scrolls, dragging scrolls without selecting, the chosen
      item is brought into view, a row that fits does not scroll, and a choice
      made before the first layout does not scroll past the first item (both
      components).
- [x] 4. Design reference: `components.md` (row scroll contract) and
      `clipboard.md` (the emoji groups).
- [x] 5. Verify: QML suite, python suite, `tests/qml_smoke.sh`, the emoji tab
      grabbed in a throwaway `ShellRoot` at the panel's width, and the settings
      grab of Bar and Appearance.
