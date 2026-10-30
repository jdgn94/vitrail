# Vitrail — project rules

When styling any Vitrail UI (frame, bar, popups, panels, variants, visual
references), load the `vitrail-design` skill and record new patterns in it.

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

### Enforcement

- `tests/test_design_system.py` fails if `kit/composed/` contains raw visual
  primitives, if a `kit/` file hardcodes a color or duration, or if a variant
  used in QML is missing from `VitrailVariants`.
- `bin/vitrail-gallery` renders the full matrix. It is the visual contract: a
  component that is not in the gallery is not part of the system.
