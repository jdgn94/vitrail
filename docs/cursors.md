# Palette-adaptive cursors

How a cursor pack becomes a Vitrail cursor: which colours a pack must have to
take the wallpaper's palette, how the build works, where the files land, and
what each part of the session picks up and when.

The code is `vitrail/cursor.py`; the window offers a **Vitrail · pack** row in
each of the light and dark cursor pickers; `scripts/apply-settings.sh` runs the
build (`python3 -m vitrail.fonts apply`) after the palette is regenerated.

## The two inks

A Vitrail cursor is not a coloured copy of a pack. The pack supplies the
**shape** and the **alpha**; the palette supplies two inks and an accent:

| Part of the art | Role | Example in the dark theme |
|---|---|---|
| Body (the larger colour area) | `on_surface` | light warm grey |
| Rim / outline (the smaller colour area) | `surface` | near-black |
| Active shapes: hand, resize, move, grab, crosshair | `primary` | the wallpaper's accent |

The body always contrasts with `surface`, and the rim takes the surface colour,
so the pointer reads on both a dark and a light background: light body on dark,
dark body on light. Active shapes take the accent so they stand out from the
arrow. The text beam (`xterm`/`text`) uses the body ink.

## What a pack needs to tint well

- **Two tones.** A monochrome or two-tone pack (white body with a dark rim, or
  black body with a light rim) is ideal. The tint finds the two dominant
  luminances and paints the bigger cluster as the body.
- **Contrast between body and rim.** If both are mid-grey they land in the same
  cluster and the pointer becomes one flat colour (still usable, less legible).
- **Alpha, not a background.** The cursor must have a transparent background;
  the alpha is preserved and a premultiplied pixel stays premultiplied.
- **Correct hotspots.** The tint copies `xhot`/`yhot` per size; an arrow with a
  hotspot at 0,0 will still point from its corner.
- **Several sizes.** 24, 32 and 48 px are the useful ones. Every image the pack
  has is copied; none is synthesised.
- **Animation delays.** Animated cursors (`wait`, `progress`, `watch`) keep
  their frame delays exactly.

A pack whose art is a single colour (for example a pure black arrow) becomes a
single flat body-coloured shape: the guard that treats a flat image as "body"
exists so such a pack never disappears into the background.

## Building one

```sh
# from the repository, with the package importable
PYTHONPATH=. python3 -m vitrail.cursor build Bibata-Modern-Classic
```

The argument is the name of an **installed** cursor theme (a folder with
`index.theme` and `cursors/` under `/usr/share/icons`, `~/.icons` or
`~/.local/share/icons`). The command prints the design it wrote:

```
vitrail-Bibata-Modern-Classic: rebuilt at /home/you/.local/share/icons/vitrail-Bibata-Modern-Classic
```

`--force` rebuilds even when the palette and the pack did not change. Without
it, a stamp in `~/.cache/vitrail/fonts/themes/stamp` skips the work.

The same build runs by itself:

1. the light or dark picker in the settings window writes
   `cursorThemeLight` / `cursorThemeDark = vitrail-<pack>` to `fonts.ini`
   (the shared `cursorTheme` row stays for machines that never set either);
2. the path unit runs `scripts/apply-settings.sh`, which runs
   `python3 -m vitrail.fonts apply`;
3. `apply` builds the design for the active mode and applies it, so each mode
   can carry its own tinted layer.

Choosing **Same as the shared pack** writes an empty value, so that mode
follows `cursorTheme` again.

## What the build writes

```
~/.local/share/icons/vitrail-<pack>/
├── index.theme          Name=Vitrail · <pack>, Inherits=<pack>
└── cursors/<name>       one Xcursor file per cursor, every image tinted
```

The generated theme is an ordinary installed cursor theme: `vitrail-fonts
state` lists it, the **Cursor theme** picker offers it with its real previews,
and any other program can select it. `Inherits=<pack>` means a cursor the pack
does not have falls back to the pack itself.

`index.theme` is also what makes the theme visible: `vitrail/fonts.py` only
lists folders that carry one.

## The format

Xcursor is read and written with the standard library (`struct` + `zlib`), so
the pipeline needs no `xorg-xcursorgen`:

- magic `Xcur`, a table of contents, and one image chunk per size/frame;
- each image chunk carries `subtype` (nominal size), `width`, `height`,
  `xhot`, `yhot`, `delay` and premultiplied ARGB words;
- writing is symmetric: same sizes, same order, same delays, new pixels.

hyprcursor (`.hlc`) is not produced: Hyprland reads Xcursor themes directly.
The conversion is optional and would add a dependency for no visible gain
today.

## A pack per theme

**Use a cursor per theme** (`appearance.ini` `cursorThemeSplit`, off by
default) switches between one shared picker and two large light/dark pickers
(`fonts.ini` `cursorThemeLight` / `cursorThemeDark`). An empty per-theme value
follows the shared `cursorTheme`, so a machine that never uses the split keeps
one pack for both modes; while split on, a picker's first row is exactly that:
**Same as the shared pack**, with the shared pack's name in the label. The
cursor dialog has the same **Normal** / **Adaptive** tabs as the icon picker:
only `vitrail-*` layers are adaptive.

`fonts apply` resolves the mode from `appearance` (falling back to the clock
between 07:00 and 19:00), picks that mode's pack, and builds the generated
`vitrail-<pack>` layer for that pack when the choice is adaptive. The automatic
07:00 / 19:00 switch runs `vitrail theme apply --mode …`, which re-runs the
font/cursor half so the pointer changes with the rest of the theme.

## Live propagation

When the cursor changes, `vitrail.fonts apply` writes and runs, in this order:

| Target | How | When it shows |
|---|---|---|
| This session's environment | `~/.config/environment.d/20-vitrail-cursor.conf` (`XCURSOR_THEME`, `XCURSOR_SIZE`) | new processes, next login |
| GTK and the settings portal | `gsettings set org.gnome.desktop.interface cursor-theme/cursor-size` | live in GTK 3/4 apps that follow settings |
| Hyprland and Wayland clients | `hyprctl setcursor <theme> <size>` | immediately |
| X11 / XWayland, X server cursors | `~/.config/X11/vitrail-cursor.Xresources` (`Xcursor.theme`, `Xcursor.size`) merged with `xrdb -merge` | the X server's cursor and cursors created after the merge |
| GTK apps on X11 | `~/.config/gtk-3.0/settings.ini` (`gtk-cursor-theme-name`, `gtk-cursor-theme-size`) | next window/restart |
| GTK apps on X11, live | `~/.config/xsettingsd/xsettingsd.conf` (the two `Gtk/Cursor*` keys, merged into the user's file) + `pkill -HUP -x xsettingsd` | immediately, when `xsettingsd` runs |
| Qt 6 apps | `XCURSOR_THEME`/`XCURSOR_SIZE` from `environment.d` for new windows, and `gsettings`/XSETTINGS while running. `qt6ct.conf` carries the icon theme; Qt has no separate cursor key there. | next window/restart |

Limits worth knowing:

- **Qt and other X11 apps that read `XCURSOR_THEME` at startup** keep the old
  pointer until they are restarted; the environment is correct for new ones.
- Xlib caches a cursor once an app has loaded it; `xrdb -merge` changes what
  the next `XcursorLibraryLoadCursor` sees, not what is already on screen.
- `xsettingsd` is only signalled if it is running (`pkill` is a no-op
  otherwise). GTK apps that read dconf directly follow `gsettings` instead.
- Cursor size and theme are applied together; changing only the size still goes
  through the same five steps.

## Adding a new pack

1. Install it as an Xcursor theme: `<theme>/index.theme` plus
   `<theme>/cursors/<name>` files.
2. Check the licence allows redistribution **before** adding it to the repo or
   the installer manifest. A pack that only allows personal use can be used
   locally but not bundled.
3. Run `python3 -m vitrail.cursor build <theme> --force` and look at the arrow
   in both themes (`Palette tint`, or the PNG previews under
   `~/.cache/vitrail/fonts/`).
4. If the art is flat or mostly mid-grey, fix the art (a body and a rim) rather
   than the tint.

The six designs from the roadmap (`white`, `black`, `oreo`, `minimal-v5`,
`simplify-dot-2`, `outlier`) are waiting for their source archives and a
licence check; `outlier` is the special case that must not tint (it keeps its
own two colours, switches light/dark and gets a contrast ring).

## The busy cursor

`wait`, `progress` and `left_ptr_watch` come from the pack, tinted, like every
other pointer. **Cursor → Own busy spinner** is hidden for now while the design
is planned: `fonts apply` always builds with `spinner=False`, and the
`cursorSpinner` preference stays at its `false` default without affecting the
generated theme.

`vitrail/spinner.py` and its tests are untouched. `cursor.build(..., spinner=True)`
still writes the twelve `clover4` frames, so a later opt-in can bring the row
back without rebuilding the pipeline.
