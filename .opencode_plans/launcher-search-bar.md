# A search-bar look for the launcher's field

Asked in chat (2026-11-21), with a screenshot of the launcher's field: make it
look like a search engine's bar.

The look (Google's bar is the reference): a pill, a filled surface with a
hairline instead of an accent ring, and a soft shadow that lifts a step under
the pointer and another on focus.

## Tasks

- [x] 1. `kit/tokens.js`: `field.lift` — blur, drop and ink alpha at rest.
- [x] 2. `kit/VitrailVariants.qml`: the `search` field variant (pill, lift, a
      quiet hairline on focus).
- [x] 3. `kit/base/VitrailField.qml`: `pill` (radius = the box's half height),
      `lifts` (`RectangularShadow` behind the fill, from `field.lift`), the
      hairline colour rule for a quiet focus.
- [x] 4. `bar/launcher/Launcher.qml`: the field uses `variant: "search"`.
- [x] 5. Tests: the search look is a pill and lifts; outline and filled are
      not pills and do not lift (`tests/qml/tst_field.qml`).
- [x] 6. Also fixed while checking: `VitrailTabs` / `VitrailSegmented` reveal
      their choice with a timer of their own instead of `Qt.callLater`, which
      threw "reveal is not a function" when the bar reloaded.
- [x] 7. Docs: `references/components.md` (the variant and its geometry),
      CHANGELOG.
- [x] 8. Verify: python suite, `tests/qml_smoke.sh`, the launcher rendered in a
      throwaway `ShellRoot` (pill, hairline, magnifier).
