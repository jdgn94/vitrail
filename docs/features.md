# Features

## The bar and the frame

A single bar on any screen edge (top, bottom, left or right), with or without
the stained-glass frame. It holds the launcher, clock, background apps, network,
VPN, power profile, the session menu and the recording chip. Every element
declares a live tooltip; the frame and the bar follow the palette.

## The panel

Opening the panel's hot zone (no bar button) shows the notification centre: one
card per app with its notifications, Do Not Disturb, clear per app or all, and
the widgets slot:

- now playing (MPRIS: art, title, artist, controls),
- quick toggles (Wi-Fi, Bluetooth, microphone, DND, VPN, airplane),
- capture (the area overlay, the toolbar and recording),
- quick notes (kept in `misc.ini`),
- the session row (lock, log out, reboot, power off).

## Launcher

`Mod+D`: applications, windows, files, calculator, clipboard and web, with
inline actions (`>` run, `=` calculate, `/` files, `;` clipboard). The
`wallpaper:` mode lists the library's pictures as thumbnails and the eighteen
effects: choosing one shows that wallpaper (`vitrail wallpaper pick`) or sets
the effect for the whole screen. Keyboard only; the clip panel is `Mod+V` (`Mod+.` emojis, `Mod+P` colours, `Mod+Shift+P` pick from screen):
hovering a history row (or moving onto it with the arrows) opens a card with
the copy as its source styled it (font, size, weight, italics, colour,
spacing, lists) or the image, and picking a styled entry pastes the style into
apps that take HTML. Settings: Launcher → Clipboard.

## Capture

The bar's camera button opens the capture overlay (`vitrail/capture.py`): the
screen freezes, the area can be dragged and resized with its eight handles —
even across monitors — and a toolbar outside it offers the actions. `Enter`
or `Ctrl`+`C` takes the picture and copies it (in record mode `Enter` records and `Ctrl`+`C` still copies), `G` or `Ctrl`+`S` saves it under `~/Pictures/Screenshots`,
`A` opens it in the editor (pencil, text, shapes, arrows; undo; save or copy at the picture's own size), `R` records that area with `wf-recorder` — one monitor per
recording — (a red chip in the bar stops it), `T` sets a 3 or 5 second countdown, `W` picks a window
(a click takes it), `F` takes the whole layout and `Esc` leaves; the toolbar
appears once there is an area; each button's tooltip names its key. Once the
selection rests (300 ms) the overlay looks in it, locally and in the
background, for text (`tesseract`) and codes (`zbarimg`): **Copy text** (`O`)
and **Translate** (`L`) are enabled only when text was found ("No text
detected" otherwise) and the **QR / bar code** button (`Q`) appears only when a
code was found (Bar → Capture can turn the detection off, which offers them
always). Copy text reads the area and copies the text, with a notification that
previews it; the languages are `ocrLanguages` (default: the system language
plus English, only the installed `tesseract-data-*`). Translate shows the text
translated by `translate-shell` in a card beside the area (loading and error
states, a copy button) into `translateTarget` (default: the system language) —
it sends the text to Google Translate online. The QR button copies the code's
content and, for a web link, the card offers to open it. **Colour
palette** (`C`) shows the area's main colours on a card (swatch, hex and share,
loading and error states): ImageMagick quantizes the area locally and similar
shades merge. A click on a swatch puts that colour in the clipboard and in the
colour history of `Super+P`; the card's copy button takes them all, one hex per
line. The number of colours is Bar → Capture → *Colours in the palette*. **Pin** (`P`) keeps
the area on screen as a floating glass window on its monitor: drag it, zoom with
the wheel, change its opacity with `Ctrl`+wheel or the bar that appears on
hover, close it with `Esc`, a double click or the close button; any number of
pins, and they outlive the overlay. The **editor** (`A`) opens the area in a
glass window centred on its monitor: pencil (`P`, with a highlighter mode), text
(`T`, typed in place), shapes (`F`) and arrows (`A`), each with its colour (six
swatches and a custom one), width and options; undo and redo take one element at
a time, the view zoom never changes the saved picture, **Copy** (`Ctrl`+`C`) and
**Save** (`Ctrl`+`S`) draw the picture and its marks at its own pixel size, and
`Esc` discards (asking first when something would be lost). Bar → Capture sets
its starting tool and whether it remembers the last options. `I`
(Ask AI) opens a question field beside the area; `Enter` opens the default
browser on Google Lens with the picture and the question (its AI Overview
answers it, and the AI Mode tab continues with both). Nothing is sent before
`Enter`, only to Google, and the Bar → Capture switch removes the button and the
key. Letters are plain keys: with `Ctrl`, `Alt` or `Meta` they do nothing, except `Ctrl`+`C` and
`Ctrl`+`S`; on a card `Ctrl`+`C` copies its content (the colours, the QR content or
the translation). Every action says what it did in a notification: screenshot
copied (its size) or saved (its path), editor result (saved or copied), area pinned, countdown
started, recording started and saved (the file) and Ask AI opening Google.
`PRINT` opens the
same overlay (and `Super+PRINT` with the whole layout selected). The folders and
the recording flags live in `capture.ini` (Bar → Capture).

## The settings window

Categories: Appearance, Fonts & icons, Wallpaper, Colors, Design, Bar, Windows,
Monitors, Terminal, Launcher, Input, Sound, Language, Date & time, Connection,
Plugins. Every preference is applied within a second by
`scripts/apply-settings.sh`; the window never runs commands itself.

## Networking and VPN

The Connection page lists Ethernet, Wi-Fi, VPN and Bluetooth with their real
state; the VPN module (`vpn/`) is Vitrail's own, with a domain-based split
tunnel.
