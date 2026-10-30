# Wallpapers and system theme

## Library

`<wallpaperDir or ~/Pictures/Wallpapers>/{images,svg,videos}` (created by
`vitrail wallpaper apply`). Prefs: `wallpaperType` (one kind at a time),
`wallpaperSelection` ("|"-joined, same kind), `wallpaper` (on screen),
`wallpaperInterval` (min), `wallpaperOrder` (sequential / random),
`wallpaperSeed` (SVG seed, "" = the drawing's own colour), `wallpaperMode`
(frame / screen fit, shared by all kinds).

- Picking another kind replaces the selection; same kind toggles (one stays).
- The bar rotates (`vitrail wallpaper next` rewrites `wallpaper=`) when more
  than one is selected.

## Adaptive SVG

Placeholders `{{role}}` (any matugen role: surface, primary,
primary_container…), unknown roles → on_surface. Palette from the seed via
`matugen color hex`; `generated/wallpaper-{dark,light}.svg` are the filled
copies the bar shows (`?v=` busts the cache). Settings previews fill them in
QML (XHR + `data:` URL; needs `QML_XHR_ALLOW_FILE_READ=1`, set by
bin/vitrail-settings). Example: `examples/wallpapers/waves.svg`.

## Pipeline

settings.ini change → systemd path unit → scripts/apply-settings.sh →
`vitrail wallpaper apply` (stamp: only a new wallpaper / seed extracts;
video → ffmpeg frame) → `vitrail theme apply --mode dark|light`
(vitrail/system_theme.py): gtk-{3,4}.0/gtk.css, gtk-3.0 prefer-dark, gsettings
color-scheme, qt5ct/qt6ct `colors/vitrail.conf` + conf keys,
environment.d QT_QPA_PLATFORMTHEME=qt6ct, Hyprland active border. The bar
re-runs theme apply when auto mode flips at 07:00 / 19:00.

Foreign files are copied once to `*.before-vitrail` before being taken.
Testing with a temp XDG_CONFIG_HOME still hits the real dconf through
gsettings: restore `color-scheme` afterwards.
