# Theming

## The palette

`vitrail colors` extracts a Material You palette from the wallpaper (matugen)
and writes `theme-dark.json` and `theme-light.json` under
`~/.cache/vitrail/generated`. Every surface asks the palette: GTK 3/4 CSS,
qt5ct/qt6ct, the Hyprland border, the shell tokens, kitty, and the generated
cursor and icon themes.

`vitrail theme apply --mode dark|light` is the single entry point; the settings
watcher calls it after any preference change that affects the palette.

## The shell

`kit/tokens.js` holds every literal; `kit/VitrailTokens.qml` resolves them for
the active theme. Components never hardcode a colour, duration or size, and the
gallery (`bin/vitrail-gallery`) is the visual contract: a component that is not
there is not part of the system.

## Fonts, icons and the cursor

- **Fonts**: one system font for GTK/Qt and the shell, a console font for kitty,
  the Material Symbols family for the shell's icons.
- **Icon packs**: the GTK/Qt pack, plus a generated layer that recolours only
  the folders (`docs/icons.md`).
- **Cursor**: a pack recoloured with the palette, with an optional Vitrail busy
  spinner (`docs/cursors.md`).

## Flatpak and Firefox

`vitrail theme apply` also grants Flatpak apps read access to the theme folders
and writes Firefox's `user.js` and `userChrome.css` (`docs/apps.md`).

## Kitty

`scripts/apply-settings.sh` writes `~/.config/vitrail/kitty-user.conf` (font,
size, padding) and `kitty-colors.conf`; kitty reloads on `SIGUSR1`, which the
script sends.
