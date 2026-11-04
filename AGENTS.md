# Vitrail — project rules

When styling any Vitrail UI (frame, bar, popups, panels, variants, visual
references), load the `vitrail-design` skill and record new patterns in it.

## Knowledge graph

Every finished task refreshes the graph in the background, without delaying the
answer: `scripts/graphify-refresh.sh &` (the post-commit hook runs the same
script; one build at a time, logged in `.git/graphify-hook.log`). `graphify-out/`
is derived and git-ignored, so the graph is never committed. Read it with
`graphify query "..."`, `graphify path "A" "B"` or `graphify explain "X"`.

## Design system (mandatory)

Every visual element in a Vitrail UI comes from `kit/`. Nothing else.

### Layers, from the bottom up

```
kit/tokens.js          raw values: colors, spacing, radius, type, motion
kit/VitrailTokens.qml  singleton: resolves tokens for the active theme
kit/VitrailVariants.qml singleton: variant tables per component family
kit/VitrailStyle.qml   singleton: global defaults + resolve(kind, variant)
kit/base/              primitives: Text, Button, Field, Surface, Icon
kit/composed/          components built ONLY from kit/base
gallery/               every component × every variant × every theme
```

1. **Tokens** are the only place with literal values. A component never writes
   `#a8c7fa`, `14` or `160` — it asks the tokens.
2. **Variants** map a name (`filled`, `ghost`, `outline`, `glass`…) to a style
   object built from tokens.
3. **Base components** expose `variant`, `size` and internal state
   (`hovered`, `pressed`, `focused`, `disabled`) and render the resolved style.
4. **Composed components** are assembled from base components. They may not
   contain raw `Text`, `Rectangle` or `MouseArea` for anything visual.

### Global style and inheritance

`VitrailStyle.defaults` holds the variant each family uses when nothing is
specified:

```qml
defaults: { text: "body", button: "filled", field: "outline", surface: "glass" }
```

A component without an explicit `variant` inherits the default, so changing one
entry restyles every use in the application. Base components also take a
`size` (`sm` / `md` / `lg`); complex components inherit the size they receive
and pass it down.

Adding a variant to `VitrailVariants` makes it available everywhere. No
component file needs to change.

### Themes

Variants never reference raw colors: they reference tokens. Tokens are bound to
the wallpaper palette (matugen, light/dark) and to the surface style
(solid/glass). A new variant therefore works in every theme automatically.

Each variant declares its own motion profile (`fast` / `base` / `slow` and an
easing), so animations travel with the style rather than with the component.

### Bar elements

Every bar element declares an informative tooltip (`tooltip` for the title,
`tooltipDetail` for the optional second line), kept live from real data, and
reports hover to the monitor's one tooltip host (`bar/TooltipLayer.qml`, which
shows a `kit/base/VitrailTooltip`). A new element without a tooltip is
incomplete; see `.agents/skills/vitrail-design/references/tooltips.md`.

### Preferences

Preferences live in one INI file per area under `~/.config/vitrail/`;
`vitrail/prefs.map` says which file holds each key. A new key is added there
first, then in `shell/Prefs.qml`; callers read and write it by key. See the
README's "Preference files".

### Settings keep up with the features

Every user-facing feature ships with its settings in the **same change**: a
preference, a toggle, a mode, an action or a value the user may want to change
gets a place in the settings window (`shell/pages/`, wired in
`shell/main.qml`), its key in `vitrail/prefs.map` and `shell/Prefs.qml`, and
its words in **all six** `kit/i18n/*.json`.

A feature whose settings live only in a config file, only in a bar popup or
only in a script is not finished. When a feature lands without them, add them
before the next one — and say so in the report.

### Dependencies

Every external program or library Vitrail calls at runtime (a `Process`
command, `subprocess`, a shell script, a Hyprland `exec_cmd`) must be declared
in the installer's package manifest (`packages/*.txt`, installed by
`install.sh`) and documented in the README's "Runtime dependencies" table. A
program that is not packaged by Vitrail (`vitrail-vpn`) is allowlisted with
a comment in `tests/test_dependencies.py`.

### Enforcement

- `tests/test_tooltips.py` fails if a clickable bar element (`*Button.qml`,
  anything emitting `clicked`, the tray's delegates) sets no `tooltip`.
- `tests/test_prefs_map.py` fails if a key used in Python, QML or the apply
  script is not in `vitrail/prefs.map`, if `shell/Prefs.qml` declares a key in
  another file, or if the path unit does not watch exactly the map's files.
- `tests/test_dependencies.py` scans `bar/`, `kit/`, `shell/`, `scripts/`,
  `vitrail/`, `bin/` and the Hyprland config for invoked programs and fails on
  any that is neither in the base system, allowlisted, nor provided by a
  package in the manifest.
- `tests/test_design_system.py` fails if `kit/composed/` contains raw visual
  primitives, if a `kit/` file hardcodes a color or duration, or if a variant
  used in QML is missing from `VitrailVariants`.
- `bin/vitrail-gallery` renders the full matrix. It is the visual contract: a
  component that is not in the gallery is not part of the system.
