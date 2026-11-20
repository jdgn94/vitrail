# Changelog

## 1.0.0 — unreleased

The first distributable release.

- The shell: bar, screen frame, notifications panel, launcher, clipboard, OSD,
  session menu, quick notes, media player and power profile.
- The settings window: appearance, wallpaper, colours, design, bar, windows,
  monitors, terminal, launcher, input, sound, fonts/icons/cursor, language,
  date & time, connection, plugins.
- Theming that follows the wallpaper: GTK/Qt, kitty, palette-tinted cursors and
  icon folders, Flatpak and Firefox.
- Wallpaper changes animate: a random ink or outline transition chosen by the
  picture, with a length setting, and the palette waits for it to end.
- Wallpaper effects: a picker with a preview of each effect over the picture on
  screen (images only), one choice for the whole shell that every output
  applies to its own picture, a broken `sunken` recipe fixed, and the layer
  reloads its effect copy instead of staying blank while it is written.
- Two drawn styles join the effects: `dots` (pointillism, the picture as round
  dots of its colours on a canvas) and `ascii` (coloured characters), both on a
  ground that follows the light/dark mode, with a Detail setting for the dot
  size and the character count. `charcoal` now turns over with the mode: white
  lines on black at night, dark lines on paper by day. The picker shows the
  drawn styles at a scale a thumbnail can read.
- The background steps out of a fullscreen window's way: the video wallpaper
  pauses, the rotation waits, the cava visualiser ends and changes skip their
  animation (Settings → Wallpaper → Pause on fullscreen, on by default).
- Pointillism as a style of its own: many small, close dabs, each one a single
  colour read from one pixel — no averages, no dot split between two colours —
  a touch more saturated, hairline canvas between them, so the picture stays
  sharp. `dots` keeps its large dabs.
- System colour: automatic, Material's main hues and a custom colour, as one
  row of chips; the change animation reaches ten seconds on a stepped slider.
- One picker for every choice made by sight: the same mosaic dialog behind the
  icon and cursor cards, the font fields and the wallpaper effects (whose cells
  are a wide preview of the picture); the font and effect triggers are a select
  field with a chevron.
- The OSD's cards open with a right click on their slider and carry the
  settings gear at the top right; the brightness card opens with a single
  monitor and says so.
- Cursors: one installed-pack list, Adaptive and Monochrome switches, one
  stable `vitrail-cursor` theme, and `.zip` import/delete, so a new app reads
  the current pointer without a logout.
- Icon packs: one list, Adaptive recolours only the folder icons with the
  system colour (solid by default, symbolic sizes included), and a
  Pack/Light/Solid folder fill.
- One file dialog: open and save dialogs come from the FileChooser portal,
  drawn by Phosh's GTK 4 chooser, for the settings window and for GTK 3 apps
  (the browser's included) through `GTK_USE_PORTAL=1`.
- Screenshots (region, window, full, annotate) and screen recording from the
  panel, with the recording chip in the bar.
- Installation without cloning (`bootstrap.sh`), an AUR package, and
  `vitrail update` against the installed branch, with snapshots.
