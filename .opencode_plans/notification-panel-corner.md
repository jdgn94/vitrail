# Fix: chipped frame corner when the notification panel opens with the bar on top

- [x] Reproduce the geometry
- [x] Locate the cause in `kit/frame.js` (`holePath`)
- [x] Add the failing QML tests (`tests/qml/tst_frame.qml`)
- [x] Hand the corner over to the perpendicular edge (`Frame.corners`)
- [x] Record the rule in `.agents/skills/vitrail-design/references/frame-and-bar.md`
- [x] Verify: `qmltestrunner -input tests/qml`, `unittest discover -s tests`,
      `tests/qml_smoke.sh`

## Symptom

Bar docked at the top (`islands` variant): the end island is stretched into the
top-right corner, the notification panel hangs from the right edge starting
exactly at the bar's inner face. At the shared corner the frame showed a
transparent wedge ("beak") ringed by the glass stroke.

## Cause

`holePath` builds a depth profile per edge. The island (tab of the top edge,
flush with the joint corner) and the panel (tab of the right edge, starting at
the island's inner face) both took the same corner: the top edge drew its end
corner arc into the right edge, while the right edge drew the step of its
first segment. The arcs crossed; the even-odd fill turned the overlap into a
hole and the glass stroke outlined it.

## Fix

`Frame.corners()` resolves the hand-off before the profiles are built: a tab
that runs into the end of its edge, while a tab of the perpendicular edge
starts from its inner face (its full depth reaches past the first tab's near
edge), becomes a tab of the perpendicular edge — the corner region between the
two inner faces. The corner then steps from one inner face to the other, at
every frame of the panel's reveal. A tab on the same edge that overlaps it
keeps the corner (it borrows that depth), so same-edge popup/island profiles
are untouched.

## Known limit

A bar popup whose tab overlaps the end island, open at the same time as the
notification panel, keeps the old corner (the popup tab borrows the island's
depth). Not part of the reported case.

## Verification

- `tests/qml/tst_frame.qml`: new near/far corner tests; 75/75.
- Full QML suite: 1119 passed. Python suite: 909 OK. `tests/qml_smoke.sh`:
  93 passed (gallery renders included).
- Offscreen render of the real `VitrailBar` + frame: clean corner, before/after
  compared.
