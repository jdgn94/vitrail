---
name: vitrail-design
description: Use when styling Vitrail UI: frame, bar, popups, panels, variants, tokens, or matching a visual reference.
---

# Vitrail Design

## Overview

Every visual comes from `kit/` (tokens → variants → base → composed). This skill
records the shapes and rules Vitrail surfaces follow; `AGENTS.md` holds the
layer contract.

## When to Use

- Changing how the frame, bar, popups or side panels look or sit.
- Adding a variant or porting a reference screenshot into the kit.
- Not for i18n strings or settings-window page logic.

## Procedure

1. Read the relevant reference before editing:
   - `references/frame-and-bar.md` — frame hole, docked vs floating bar, panels.
   - `references/popups.md` — bar popup placement and the docked tab shape.
   - `references/notifications.md` — toast stack, queue, positions, actions.
   - `references/components.md` — type, icons, button variants, indicators,
     slider, settings window layout, popup rows.
   - `references/wallpapers.md` — library, adaptive SVG, colour pipeline.
   - `references/dialogs.md` — polkit and Hyprland dialogs in the bar.
   - `references/datetime.md` — time zone world map, NTP, system language.
   - `references/session.md` — power button, session menu and popout.
   - `references/tooltips.md` — bar tooltips: contract, host, contents.
   - `references/osd.md` — volume / microphone / brightness OSD: edge, hot zone,
     sliders, device cards, keys, IPC.
   - `references/launcher.md` — application launcher: modes, files, data flow.
2. Geometry goes in `kit/frame.js` (pure, tested in `tests/qml/tst_frame.qml`);
   QML only binds to it. Write the test first.
3. Literal values only in `kit/tokens.js`; new looks become a variant in
   `kit/VitrailVariants.qml`, never a flag on one component.
4. When a reference image introduces a new pattern, add or update a
   `references/<topic>.md` entry here in the same change.

## Pitfalls & Gotchas

- Overlapping two translucent fills leaves a darker seam and the frame's glass
  edge still crosses the join. Anything that must look fused with the frame is
  drawn **inside the frame's own path** (see the popup tab), not on top of it.
- `PathRectangle` hole sharing an edge with the outer rect breaks the curve
  renderer; the outer rect stays 1 px past the screen.
- SVG `H`/`V` do not survive the edge rotation in `frame.js`; emit `L`.
- Popup cards size from `implicitWidth/Height` of the content **plus** the
  inner margin on both sides.
- Default bar edge is `bar.layout.edge`; never re-derive it from prefs with a
  different fallback.
- Quickshell `ObjectModel`s (`Networking.devices`, `networks`) are read with
  `.values`; `.length` / `[i]` on the model are silently undefined.
- `Item` already has FINAL `top` / `bottom` / `left` / `right`: name custom
  properties otherwise (`atBottom`, `begin`, `stop`).
- A `Behavior` cannot target a `readonly` property.
- `qml6` swallows load errors here: run with `QT_FORCE_STDERR_LOGGING=1`.
- Icons are Material Symbols ligature names; no Nerd Font code points.
  `tests/test_icons.py` checks every `icon:` / `glyph:` value renders.
- `pkill -f <pattern>` inside a Bash call matches the call itself: anchor
  it (`pkill -f "^qml6 -I .*main[.]qml"`).
- ListView `add` transitions cut short by the next insert leave the item
  half transparent; fade in from the delegate (`Component.onCompleted`).
- Fills on glass must be opaque: `VitrailTokens.solid(...)`, not `Qt.alpha` /
  `opacity` (they smear into a dark inner edge over the blur); see
  `references/components.md`. The sunk look (`inset`) only when asked.
- `clip: true` ignores `radius` (it cuts to the bounding box): round images
  and covers use a `MultiEffect` with `maskSource` (see `bar/media/DiscArt.qml`).
  Not `ClippingRectangle`: `Quickshell.Widgets` does not load in `qml6`, and
  the settings window reuses those components.
- A `ColumnLayout` / `RowLayout` overwrites an assigned `implicitWidth` /
  `implicitHeight` with its children's: give the children `Layout.preferredWidth`
  (a popout's card sizes from the root's implicit size). A hidden item
  (`visible: false`, e.g. the `IconImage` under a `MultiEffect`) is skipped by
  layouts and gets no size: put it in an `Item` cell and anchor the effect to it.
- A QML function named like a JS global (`escape`) fails to load ("Illegal
  method name") and `qmllint` stays quiet: the smoke test's window load is
  what catches it. Settings drill-in views, inline confirmations and secrets:
  `references/components.md`.
- Variant colour roles must exist in `VitrailPalette` (`accentForeground`,
  not `onPrimary`).

## Verification

```sh
bash tests/qml_smoke.sh                       # qmllint + qml unit tests + gallery
uv run python -m unittest discover -s tests   # design-system enforcement
qs ipc --path bar/shell.qml call network toggle && grim -g "0,0 900x600" shot.png
notify-send -a Discord "Title" "Body with <b>markup</b>"   # live toast
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen bin/vitrail-gallery --grab gallery.png
XDG_CONFIG_HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen bin/vitrail-settings --selftest --category bar
  # → $XDG_CONFIG_HOME/vitrail/selftest.png
```

Components that import `Quickshell` cannot load in `qml6`: preview them in a
throwaway `ShellRoot { FloatingWindow { … } }` run with `quickshell --path`,
symlinking `bar/kit` and the component folder next to it, and
`grabToImage` an inner Item (not the window).
