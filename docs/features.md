# Features

## Bar element foundation

`BarElementBase` (bar/BarElementBase.qml) is the base of every new bar element: the icon button with its tooltip, click, middle click, right click and wheel, a custom face when a button does not fit, and the "only while active" switch (Settings → Bar elements, one `barActiveOnly` preference for all elements). `BarSnapshot` brings an element's data from a Python module as one JSON snapshot, polled only while the element is in a bar. The sample element (bar/sample/, hidden by default) exercises every layer, and Settings → Bar elements has one block per element. See docs/bar-elements.md for the recipe.

## Volume bar element

An icon that follows the default output's level (muted, none, low, high) and, with `volumePercent`, the level as text. The wheel moves the master volume by `volumeStep` (1–25 %, default 5), a middle click mutes, and a click opens the popup: the master slider with its device's name and mute, one row per application stream (slider, mute, and an output chooser that moves the stream to another sink), the output and input device choosers and the microphone mute. `volumeHideSilent` leaves paused streams out. The data is `vitrail.audio`'s snapshot (`pw-dump`), polled only while the element is in a bar; every change is one `python3 -m vitrail.audio` process. Without PipeWire or `pw-dump` the icon goes neutral and the popup says it cannot read the audio server. Hidden by default (bar → Editor, or Settings → Bar elements), where its block holds the three options.

## Updates bar element

The number of pending packages, and nothing while there are none. `checkupdates` (pacman-contrib) fills the official repositories, `paru -Qua` or `yay -Qua` the AUR and `flatpak remote-ls --updates` Flatpak; `updatesSources` picks the three and `updatesAurHelper` fixes the AUR helper (`auto` follows what is installed). `updatesInterval` sets how often the snapshot is polled (minutes, 60 by default). The popup groups the rows by source (`name from → to`), turns what does not fit into "and N more", shows a source's failure as a calm line with its code, refreshes on demand and offers one Update per source that runs the snapshot's own argv (`sudo pacman -Syu`, `paru -Sua`, `flatpak update -y`) in a kitty terminal. When the total grows and at least one package is new, one notification offers the popup; the first snapshot after start is the silent baseline. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active": at zero it leaves the bar until it has something to say.

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
