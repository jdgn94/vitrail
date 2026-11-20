# Palette-adaptive cursors

How a cursor pack becomes a Vitrail cursor: which colours a pack must have to
take the wallpaper's palette, how the build works, where the files land, and
what each part of the session picks up and when.

The code is `vitrail/cursor.py`; the window shows one list of installed packs
in each cursor picker and two switches beside it, **Adaptive** and
**Monochrome**; `scripts/apply-settings.sh` runs the build
(`python3 -m vitrail.fonts apply`) after the palette is regenerated.

Every choice is applied through a single theme name, `vitrail-cursor`. The name
never changes; what it contains does. A name that changed with the pack would
leave the old one in a running process's environment and in X resources.

## The two inks

A Vitrail cursor is not a coloured copy of a pack. The pack supplies the
**shape** and the **alpha**; the palette supplies two inks and an accent:

| Part of the art | Role | Example in the light theme |
|---|---|---|
| Body (the larger interior area) | `primary` | the wallpaper's accent |
| Rim / outline (the smaller colour area) | `surface` | near-white |
| Text beam (`xterm`/`text`) | `primary` | the same accent |

The body takes the accent and the rim takes the surface colour, so every shape
of the pack — arrow, hand, resize, move, text beam — carries the system colour,
not only the "active" ones. The rim keeps the pointer readable on both a dark
and a light background.

**Monochrome** drops the accent: every shape takes `on_surface` instead, with
`surface` for the rim. It is a variation of **Adaptive** and only runs while
Adaptive is on; with Adaptive off the pack is used untouched.

## What a pack needs to tint well

- **Two tones.** A monochrome or two-tone pack (white body with a dark rim, or
  black body with a light rim) is ideal. The tint finds the two dominant
  luminances and paints the bigger **interior** area as the body; the
  anti-aliased rim that touches the transparent background is not counted, so
  a thick dark outline does not become the body of a white pack.
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
vitrail-cursor: rebuilt at /home/you/.local/share/icons/vitrail-cursor
```

`--force` rebuilds even when the palette and the pack did not change. Without
it, a stamp in `~/.cache/vitrail/fonts/themes/stamp` skips the work. The stamp
carries the tint version, so a change to the algorithm rebuilds the themes an
older build wrote.

The same build runs by itself:

1. the picker writes the pack name to `cursorTheme` (or to
   `cursorThemeLight` / `cursorThemeDark` while the split is on) and the
   switches write `cursorAdaptive` / `cursorMonochrome` to `fonts.ini`;
2. the path unit runs `scripts/apply-settings.sh`, which runs
   `python3 -m vitrail.fonts apply`;
3. `apply` builds `vitrail-cursor` for the active mode and applies that name, so
   each mode can carry its own tinted layer.

Choosing **Same as the shared pack** writes an empty value, so that mode
follows `cursorTheme` again.

## What the build writes

```
~/.local/share/icons/vitrail-cursor/
├── index.theme          Name=Vitrail · Cursor, Inherits=<pack>
└── cursors/<name>       one Xcursor file per cursor, every image tinted

~/.icons/vitrail-cursor -> ~/.local/share/icons/vitrail-cursor
```

The second path matters: Hyprland, libwayland-cursor and Xcursor look in
`~/.icons` (and the system data dirs), **not** in `~/.local/share/icons`. A
theme that only exists in the data home is silently replaced by the default
one. `cursor.link_user` creates that symlink; the picker and `vitrail-fonts
state` keep reading the data home.

With **Adaptive** off there is no generation: `vitrail-cursor/cursors` is a
symlink to the pack's own `cursors/` folder, and `index.theme` simply inherits
the pack. Switching from one to the other removes the previous content (or the
symlink) first, so a pack never gets written through the alias.

The generated theme is an ordinary installed cursor theme: `vitrail-fonts
state` lists it, and any other program can select it. `Inherits=<pack>` means a
cursor the pack does not have falls back to the pack itself.

`index.theme` is also what makes the theme visible: `vitrail/fonts.py` only
lists folders that carry one.

Old `vitrail-<pack>` folders from before the stable name are turned into
symlinks to `vitrail-cursor` by `cursor.migrate_aliases`, and mirrored into
`~/.icons` by `cursor.mirror_aliases`. A session started before the change
still has that name in its environment; resolving it to the current theme
keeps new windows right without a logout.

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
**Same as the shared pack**, with the shared pack's name in the label.

`fonts apply` resolves the mode from `appearance` (falling back to the clock
between 07:00 and 19:00), picks that mode's pack, and rewrites
`vitrail-cursor` for that pack when **Adaptive** is on (or points it at the pack
when it is off). The automatic 07:00 / 19:00 switch runs
`vitrail theme apply --mode …`, which re-runs the font/cursor half so the
pointer changes with the rest of the theme.

## Live propagation

When the cursor changes, `vitrail.fonts apply` writes and runs, in this order:

| Target | How | When it shows |
|---|---|---|
| Hyprland at login | `~/.config/hypr/vitrail-cursor.lua`, loaded by `hyprland.lua` (`hl.env` plus `hl.exec_cmd("hyprctl setcursor …")`) | from the first frame of the session |
| This session's environment | `~/.config/environment.d/20-vitrail-cursor.conf` (`XCURSOR_THEME`, `XCURSOR_SIZE`) | new processes, next login |
| systemd user units and D-Bus activation | `systemctl --user set-environment` and `dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE` | the next process either one starts |
| GTK and the settings portal | `gsettings set org.gnome.desktop.interface cursor-theme/cursor-size` | live in GTK 3/4 apps that follow settings |
| Hyprland and Wayland clients | `hyprctl setcursor <theme> <size>` | immediately |
| Apps Hyprland spawns later | `hyprctl eval 'hl.env("XCURSOR_THEME", …); hl.env("XCURSOR_SIZE", …)'` | the next child, without a logout |
| X11 / XWayland, X server cursors | `~/.config/X11/vitrail-cursor.Xresources` (`Xcursor.theme`, `Xcursor.size`) merged with `xrdb -merge` | the X server's cursor and cursors created after the merge |
| GTK apps on X11 | `~/.config/gtk-3.0/settings.ini` (`gtk-cursor-theme-name`, `gtk-cursor-theme-size`) | next window/restart |
| GTK apps on X11, live | `~/.config/xsettingsd/xsettingsd.conf` (the two `Gtk/Cursor*` keys, merged into the user's file) + `pkill -HUP -x xsettingsd` | immediately, when `xsettingsd` runs |
| Qt 6 apps | `XCURSOR_THEME`/`XCURSOR_SIZE` from `environment.d` for new windows, and `gsettings`/XSETTINGS while running. `qt6ct.conf` carries the icon theme; Qt has no separate cursor key there. | next window/restart |

The stable name is what makes the first two rows work: `XCURSOR_THEME` is
always `vitrail-cursor`, and the folder behind it is rewritten in place. Any
process started after the change reads the current content.

`environment.d` alone is not enough for the first frame: SDDM starts Hyprland
before the systemd user manager applies it. `fonts apply` therefore also writes
`~/.config/hypr/vitrail-cursor.lua`, which `hyprland.lua` loads at the top. Its
`hl.env` reaches the compositor's children and its values feed the startup
`hyprctl setcursor`, so a fresh login already has `vitrail-cursor`. On the very
first login, before that file exists, the startup block runs
`vitrail-apply-settings` once: it builds the theme, writes the file and applies
the cursor for the session.

Limits worth knowing:

- **A running app keeps the cursor it already decoded.** Xcursor and
  libwayland-cursor cache the images in the process; rewriting the files in
  `vitrail-cursor` does not notify it. Chrome, Electron and other XWayland
  apps (Spotify, for one) show the old pointer until the app is restarted.
  GTK apps, the compositor's own cursor and Wayland clients that use
  `cursor-shape` change live.
- **Qt and other X11 apps that read `XCURSOR_THEME` at startup** keep the old
  pointer until they are restarted; the environment is correct for new ones.
- Xlib caches a cursor once an app has loaded it; `xrdb -merge` changes what
  the next `XcursorLibraryLoadCursor` sees, not what is already on screen.
- `xsettingsd` is only signalled if it is running (`pkill` is a no-op
  otherwise). GTK apps that read dconf directly follow `gsettings` instead.
- **Hyprland caches a theme by name.** Setting `vitrail-cursor` again does not
  reload a rebuilt theme; `fonts apply` switches to `Adwaita` and back when the
  content changed. The theme must also be reachable from `~/.icons`.
- Cursor size and theme are applied together; changing only the size still goes
  through the same steps.

## Adding a new pack

1. Install it as an Xcursor theme: `<theme>/index.theme` plus
   `<theme>/cursors/<name>` files. From the window, **Import .zip** in the
   cursor picker accepts the same layout (`<theme>/index.theme` and
   `<theme>/cursors/`, or `index.theme` plus `cursors/` at the archive root),
   installs it in `~/.icons/<theme>` and keeps an earlier copy in
   `~/.icons/.vitrail-backups`. **Delete pack** removes one of the user's
   packs; the generated `vitrail-*` themes and the system packs are never
   touched.
2. Check the licence allows redistribution **before** adding it to the repo or
   the installer manifest. A pack that only allows personal use can be used
   locally but not bundled.
3. Run `python3 -m vitrail.cursor build <theme> --force` and look at the arrow
   in both themes (`Palette tint`, or the PNG previews under
   `~/.cache/vitrail/fonts/`).
4. If the art is flat or mostly mid-grey, fix the art (a body and a rim) rather
   than the tint.

A Windows `.cur`/`.ani` archive is not an Xcursor theme: convert it first with
`python3 -m vitrail.wincursor build <folder> <theme> --name <theme>`. The
converter reads the scheme `.inf` (`OutLier_install.inf`, `install.inf`…), so a
pack whose files are `ol_pointer.cur`, `ol_point.cur`, `ol_text.cur` becomes the
standard `left_ptr`, `pointer`, `xterm` (and the resize, help, busy and person
names); without an `.inf`, files named `arrow.cur` / `hand.cur` / `ibeam.cur`
still map. The `Bonus/` folders of alternate pointers are not part of the
scheme and are ignored.

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
