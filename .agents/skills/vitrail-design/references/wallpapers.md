# Wallpapers and system theme

## Library

`~/.config/vitrail/wallpapers/{images,videos}` (Vitrail's own copies,
apart from the user's pictures; `wallpaperDir` overrides it). Prefs:
`wallpaperType` (one kind at a time), `wallpaperSelection` ("|"-joined, same
kind), `wallpaper` (on screen), `wallpaperInterval` (min), `wallpaperOrder`
(sequential / random), `systemColor` (colour of the whole system: "" =
from the wallpaper, a hex = fixed; the old `wallpaperSeed` migrates into it),
`wallpaperMode` (frame / screen fit, shared by all kinds).

The settings window (qml6) cannot touch files: it writes requests
`wallpaperImport` / `wallpaperRemove` = "<nonce>|path|path…" (the nonce makes
a repeat a new value) and `vitrail wallpaper sync` copies them in (never
overwriting: name-2.ext) or deletes them, only inside the library, then
clears the key. The window updates the selection itself before asking for a
removal. Delete on a tile is two clicks (arm, confirm).

Entering the library (`sync` requests, `vitrail wallpaper import <files|dirs>`,
install.sh with assets/): images and videos go through `vitrail/media.py`
(verify, then optimize; a broken file is rejected, never copied). Imports never
overwrite, skip identical content, and remember each source's hash in
`<library>/.sources`, so re-running adds nothing and re-encodes nothing.
`sync` also drops dead paths from `wallpaperSelection` and moves `wallpaper` to
the first remaining.

- Picking another kind replaces the selection; same kind toggles (one stays).
- Settings page: settings first (fit, order, interval select, rotation-order
  strip, system colour), library below. The strip (several selected) is
  draggable (`shell/reorder.js`) and writes `wallpaperSelection`; it only
  matters for "In order". Thumbnails use `PreserveAspectFit` on the tile
  colour, clipped by a MultiEffect rounded mask (blank under the offscreen
  software renderer: screenshot on the real compositor).
- The bar rotates (`vitrail wallpaper next` rewrites `wallpaper=`) when more
  than one is selected.

## Pipeline

wallpaper.ini change → systemd path unit → scripts/apply-settings.sh →
`vitrail wallpaper sync` → `vitrail wallpaper apply [--force]` (stamp: wallpaper
+ systemColor; fixed colour → `matugen color hex` for every kind, automatic →
image / video frame) → `vitrail theme apply --mode dark|light`
(vitrail/system_theme.py): gtk-{3,4}.0/gtk.css, gtk-3.0 prefer-dark, gsettings
color-scheme, qt5ct/qt6ct `colors/vitrail.conf` + conf keys,
environment.d QT_QPA_PLATFORMTHEME=qt6ct, Hyprland active border. The bar
re-runs theme apply when auto mode flips at 07:00 / 19:00.

Foreign files are copied once to `*.before-vitrail` before being taken.
Testing with a temp XDG_CONFIG_HOME still hits the real dconf through
gsettings: restore `color-scheme` afterwards.

## Terminal palette

`colors.terminal_palette`: background = surface, foreground = on_surface,
cursor = primary, selection = primary_container / on_primary_container; ANSI
from matugen's base16 *in the active mode* (1 red=base08, 2 green=base0b, 3
yellow=base0a, 4 blue=base0d, 5 magenta=base0e, 6 cyan=base0c, 7=base05,
8=base03, 15=base07; brights 9-14 = hue-kept lightness steps), lightness
nudged until foreground >= 7:1, ANSI 1-7 / 9-15 >= 4.5:1, color8 >= 3:1.
base16 slot N is NOT ANSI colour N (that made every coloured output invisible).

## Media optimizer

`vitrail/media.py`: images capped at 3840 px, metadata stripped, WebP (q90)
only if smaller and ffmpeg SSIM >= 0.98 vs the resized source (Qt reads WebP
via its imageformats plugin, matugen extracts from it); videos always lose
audio, capped at 3840x2160, AV1 (libsvtav1 crf 30, preset 6, 10-bit) kept only
if smaller and VMAF >= 95 (1080p scaled, sampled), else the stream is copied
without audio. Tools run through an injectable `run`.
