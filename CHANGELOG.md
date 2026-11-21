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
- The capture selection moves like jelly: it is born as a drop at the pointer,
  each edge springs to the selection and bows while it moves, window picks and
  full-screen glide with a neck, and the dark veil has the same shape
  (setting: Bar → Capture).
- More capture actions: **Copy text** (`O`) reads the area with tesseract,
  locally; **Translate** (`L`, translate-shell, online) shows the translation
  on a card; **QR / bar code** (`Q`, zbar) copies a code's content and opens
  links; **Colour palette** (`C`) shows the main colours of the
  area (local, ImageMagick; similar shades merged) and a click copies one into
  the `Super+.` colour history, or all of them from the card; **Pin** (`P`) keeps the area as a floating
  glass window (drag, zoom, opacity); **Ask AI** (`I`) asks Google about the
  area in the default browser. The selection is searched for text and codes in
  the background so only the buttons that can work are enabled, and every
  button's tooltip names its key. Settings: Bar → Capture (detection, Ask AI,
  OCR languages, palette size, Translate language).
- Capture keys and notices: `Ctrl`+`C` copies the picture (it used to open the
  palette), `Ctrl`+`S` saves it, and letter shortcuts ignore Ctrl/Alt/Meta; on a
  card `Ctrl`+`C` copies its content. Every action says what it did in a
  notification: copied, saved (with the path), annotator opened, pinned,
  countdown started, recording started and saved, Ask AI opening, QR and
  translation copied.
- Rich clipboard: a copy keeps the style of its source (font family, size,
  weight, italics, colour, spacing, lists). The watcher keeps the source's
  `text/html` beside cliphist's text (`~/.cache/vitrail/clipboard/`, keyed by the
  SHA-256 of the text, capped, pruned when the history drops the entry, never
  for password managers), picking an entry offers `text/plain` and `text/html`
  together through a small GTK 4 helper, and hovering a row of the `Super+.`
  history opens a glass card with the styled text (sanitized: no scripts, event
  handlers or remote resources) or the image. Settings: Launcher → Clipboard
  (`clipboardRich`, `clipboardPreview`).
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
- Rows that do not fit scroll instead of being cut: the settings' subcategory
  tabs (wheel, drag, the chosen tab always in view) and the emoji groups,
  whose pill no longer starts half cut when the tab opens.
- The clipboard owns the keys: `Super+V` history, `Super+.` emojis, `Super+P`
  colours and `Super+Shift+P` pick from the screen; a window floats with
  `Super+Shift+V` now. The empty side panel, its variants, its token and the
  "windows make room for full panels" switch are gone.
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
- The capture overlay: the screen freezes, the area is editable with handles
  (across monitors), and a toolbar outside it takes the picture (copied),
  saves, annotates, records that area, counts down, picks a window or the whole
  layout. `PRINT` opens the same overlay (`Super+PRINT`, whole layout).

- Installation without cloning (`bootstrap.sh`), an AUR package, and
  `vitrail update` against the installed branch, with snapshots.
