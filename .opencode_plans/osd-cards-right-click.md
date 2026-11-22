# OSD: cards on right click, gear inside the card

Requested in chat (2026-11-15), with the full panel (volume / mic / brightness)
as the reference:

- The cards beside each slider no longer open on hover: a right click on the
  slider opens its card (the same slider again closes it).
- The settings gear moves from the end of each slider into the card, at its
  top right; hovering a slider only explains it.
- The brightness card opens with a single monitor and says `osd.displays.one`
  there, the gear in the same place.

Done:

- [x] `bar/osd/OsdCell.qml`: gear removed, `cardRequested` on a right click.
- [x] `bar/osd/osd.js`: the cell no longer reserves a gear row.
- [x] `bar/osd/OsdLayer.qml`: `toggleCard()`, no hover-opened cards, card header
      with the title and the gear, `extAvailable("brightness")` from one display.
- [x] `bar/osd/DeviceCard.qml` / `BrightnessCard.qml`: own titles removed; the
      single-monitor message added.
- [x] `kit/i18n/*.json` (six): `osd.displays.one`; `osd.settings*` dropped.
- [x] `tests/qml/tst_osd.qml`: cell sizes, right-click signal, no gear test.
- [x] Docs (`references/osd.md`) and CHANGELOG.
- [x] 1154 QML tests, 97 smoke checks, 995 Python tests; layout checked live
      with the panel forced open.
