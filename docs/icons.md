# Palette-adaptive application icons

How an icon pack's folders follow the wallpaper palette: which colours move,
what the art must look like, how the layer is built and installed, and what each
part of the session does with it.

The code is `vitrail/icons.py`; the switch is **Icons → Palette tint**;
`scripts/apply-settings.sh` builds it (`python3 -m vitrail.fonts apply`) after
the palette is regenerated.

## A layer, not a copy

A Vitrail icon theme carries **only the folder icons**, recoloured, and
inherits the rest of the pack:

```
~/.local/share/icons/vitrail-icons-<pack>/
├── index.theme                     Name=Vitrail icons · <pack>, Inherits=<pack>
└── <dir>/places folder*.svg        the same relative paths the pack uses
```

Every other icon (applications, mimetypes, devices, actions that are not
folder-shaped) resolves through `Inherits=<pack>`, so the theme stays small and
follows the pack's updates. Folders are the icons a desktop shows most, and the
ones where a fixed blue reads wrong next to a warm wallpaper.

## The hue model

1. **Find the folder body.** Every `fill` and `stop-color` in the SVG is read;
   the saturated colours (saturation ≥ 0.25, lightness 12–92 %) are counted and
   the most frequent wins — for Papirus `#5294e2`, for Adwaita's gradient
   `#62a0ea`.
2. **Move the hue.** Every colour within **42°** of the body's hue is repainted
   with the palette's `primary` hue, keeping its own **saturation and
   lightness**. The darker flap, the lighter highlight and the gradient stops
   keep their relationships: only the family of colour changes.
3. **Leave the rest.** Paper whites, greys, shadows and any decorative colour
   more than 42° away stay exactly as the pack drew them. A folder with a green
   badge keeps its green badge.
4. **Skip what has no body.** Symbolic icons (`fill:currentColor`) and files
   with no saturated fill are not copied at all: they resolve to the pack's own
   icon, which is already theme-aware.

The result for the Papirus folder with a pink `primary` is the same folder with
the same shading, pink instead of blue.

## What the art needs

- **Vector SVG** in the directories the pack lists in `index.theme`
  (`Directories=`). Raster-only folders are not recoloured.
- **A distinct, saturated body colour.** A grey or near-white folder has no
  body to follow; it is left to the pack.
- **Decorative colours away from the body hue.** Anything within 42° of the
  blue body will follow the palette too — that is usually what you want for the
  folder flaps, and a surprise for a logo drawn in the same blue.
- **The usual icon-theme layout**: `index.theme` with `Directories=` and one
  section per directory, plus the SVGs under `<size>/places/` or
  `places/<size>/`.

## Building one

```sh
# from the repository, with the package importable
PYTHONPATH=. python3 -m vitrail.icons build Papirus
```

The argument is an **installed** icon theme (a folder with `index.theme` under
`/usr/share/icons`, `~/.icons` or `~/.local/share/icons`). The build prints
where it wrote the layer and `--force` rebuilds even when nothing changed; a
stamp per pack and palette skips the work otherwise.

From the window:

1. **Icons → Palette tint** writes `iconTheme = vitrail-icons-<pack>` to
   `fonts.ini`;
2. `scripts/apply-settings.sh` runs `python3 -m vitrail.fonts apply`;
3. `apply` builds the layer (only the active one) and sets
   `org.gnome.desktop.interface icon-theme`, `gtk-icon-theme-name` and qt6ct's
   `icon_theme` to the generated name.

**Off** writes the pack's own name back.

The generated theme is a normal installed theme: it appears in **App icon
pack**, in `vitrail-fonts state`, and in any other program's theme list. Its
previews are its own tinted folders.

## What the session does with it

| Target | How | When it shows |
|---|---|---|
| GTK apps | `gsettings set org.gnome.desktop.interface icon-theme` | new windows; GTK caches icons per app |
| GTK settings file | `~/.config/gtk-3.0/settings.ini` (`gtk-icon-theme-name`) | next app start |
| Qt apps | `~/.config/qt6ct/qt6ct.conf` (`icon_theme`) | next app start |
| The shell's own icons | untouched: the bar draws Material Symbols, not the pack | — |

Unlike the cursor, an icon theme is not re-read live: running applications keep
the icons they already loaded, and windows created after the change use the new
theme. That is how GTK and Qt work; no env or XSETTINGS key forces a running
process to reload its icon cache.

## Adding a pack

1. Install it as an icon theme: `index.theme` plus the directory tree.
2. Check the licence allows redistribution before bundling it (the same rule as
   the cursor packs).
3. Run `PYTHONPATH=. python3 -m vitrail.icons build <pack> --force` and look at
   `48x48/places/folder.svg` in the generated theme (or open a file manager).
4. If the folders stay blue, the body was not found: the art is grey, symbolic,
   or the saturated colour is spread over too many values — fix the art rather
   than widening the window.

The six cursor designs from the roadmap are unrelated to this layer; the icon
theme always starts from an installed pack.

## Limits

- Only folder-shaped icons (`folder*`, `user-home`, `user-desktop`,
  `user-trash`). Application icons, mimetypes and devices are the pack's.
- SVG only; a pack with raster-only folders is inherited unchanged.
- One palette at a time: the layer is rebuilt when the active palette changes,
  and only for the pack in use.
