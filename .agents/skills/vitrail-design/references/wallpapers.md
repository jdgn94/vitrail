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
- Settings page: settings first (fit, effect, transition and its length, system
  colour, rotation order, interval select, rotation-order strip), then one
  block per output, then the library. The system colour sits under the
  animation length: Automatic (a chip carrying the first letter of its own
  name, ringed when in use), one of Material's main hues (the 500 tones, one per
  hue — no steps) or a custom colour from `ColorDialog`; the chips wrap in a
  `Flow` and the custom one shows the chosen colour. The animation length is a
  stepped slider (0.2–10 s, `snap: true`). The strip (several selected) is
  draggable (`shell/reorder.js`) and writes `wallpaperSelection`; it only
  matters for "In order". Thumbnails use `PreserveAspectFit` on the tile
  colour, clipped by a MultiEffect rounded mask (blank under the offscreen
  software renderer: screenshot on the real compositor).
- The bar rotates (`vitrail wallpaper next` rewrites `wallpaper=`) when more
  than one is selected.

## Effects and previews

`wallpaperEffect` is one choice for the whole shell: it applies to whichever
picture each output shows. `wallpaperMonitors` (one JSON object keyed by
output) only holds a picture, `{"DP-1": {"wallpaper": "/path"}}`; an output
without one follows the global picture. Only pictures take an effect: a video
is decoded by its own engine and shown as it is.

The page keeps a compact row with the effect's name (the previous row style,
because a grid inline takes too much room); the picker is a `VitrailPicker`
whose cells are one wide, rounded preview of the picture the whole screen
shows, five per row.

`vitrail/effects.py` holds the recipes as `magick` argument lists (never a
shell string). ImageMagick 7 refuses a negative bevel, so `sunken` raises the
picture upside down instead of `-raise -10x-10`. `apply()` fails loudly when
magick writes nothing, and `vitrail/wallpaper.py` copies the plain picture into
the bar's stable file in that case: the layer never points at a file that is
not there.

The bar draws `cache/wallpaper-effect.png`, or `wallpaper-effect-<output>.png`
for an output with a picture of its own. `wallpaper.applied` is the stamp: it
carries the whole `wallpaperMonitors` document (so a per-output picture is a
change) and is rewritten **after** the copies, so watching it means "the
pictures are on disk". `bar/shell.qml` bumps `wallpaperRevision` on that file
and the picture URL carries it (`?v=N`): QML never retries a load that failed,
so a layer pointed at a copy that was still being written would stay blank.

`apply()` publishes the picker's previews at 320 px in
`cache/previews/global/<effect>.png`, one file per recipe including `none`; a
recipe magick refuses is left out and its tile stays empty. The page reloads
them with a `previewRevision` query a few seconds after a picture changes.

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

## Change animation

`kit/base/VitrailWallpaper.qml` keeps the outgoing picture (`leavingSource`)
while `kit/shaders/wallpaper-transition.frag` draws the incoming one through
the animation: `ink` (blobs of the new picture grow from an `origin`, a
threshold falling over fbm noise), `outline` (a Sobel pass traces the incoming
contours and the fill follows) or `fade`. `kit/wallpaper.js` turns the incoming
path into a stable spec — kind, duration ±15 %, origin, seed — so both outputs
showing the same picture animate together and a picture keeps its animation
when it returns. `random` picks between ink and outline from that hash.

The shader lives inside the wallpaper's layered `media` item, whose effects
(`MultiEffect` blur and the rounded hole mask) draw it. Two gotchas:

- A `visible` binding on a child of that hidden layer never updates (the layer
  renders hidden children, but Qt does not re-evaluate their `visible`). Fade
  the shader with `opacity` instead, and hide the sampled images with
  `ShaderEffectSource.hideSource`.
- Qt 6 needs pre-baked shaders: `scripts/build-shaders.sh` (`qsb --qt6`) writes
  `kit/shaders/*.qsb`; `tests/test_shaders.py` re-bakes and compares the bytes.
  Never edit the `.qsb`.

The bar (`shell.qml`) and the settings window (`main.qml`) hold `palette.json`
until the spec's duration ends (`paletteHoldUntil` + a timer), so the interface
does not recolour halfway through. Videos change in place. An ImageMagick
effect is derived into a stable `wallpaper-effect.png`; the bar keeps the
previous picture until `wallpaper.applied` names that effect and the copy
exists (`shell.appliedEffect` / `shell.effectPresent`), then moves to it with the
same animation. The palette is held through the pass and the animation.

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
