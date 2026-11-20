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
the effect for the whole screen. Keyboard only; the clip panel is `Mod+.`:
hovering a history row (or moving onto it with the arrows) opens a card with
the copy as its source styled it (font, size, weight, italics, colour,
spacing, lists) or the image, and picking a styled entry pastes the style into
apps that take HTML. Settings: Launcher → Clipboard.

## Capture

The bar's camera button opens the capture overlay (`vitrail/capture.py`): the
screen freezes, the area can be dragged and resized with its eight handles —
even across monitors — and a toolbar outside it offers the actions. `Enter`
takes the picture and copies it, `G` saves it under `~/Pictures/Screenshots`,
`A` opens it in `swappy`, `R` records that area with `wf-recorder` — one monitor per
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
content and, for a web link, the card offers to open it. **Colour** (`C`)
turns the pointer into a loupe over the frozen screen; a click puts the colour
in the clipboard and in the colour history of `Super+.`. **Pin** (`P`) keeps
the area on screen as a floating glass window on its monitor: drag it, zoom with
the wheel, change its opacity with `Ctrl`+wheel or the bar that appears on
hover, close it with `Esc`, a double click or the close button; any number of
pins, and they outlive the overlay. `I`
(Ask AI) opens a question field beside the area; `Enter` opens the default
browser on Google Lens with the picture and the question (its AI Overview
answers it, and the AI Mode tab continues with both). Nothing is sent before
`Enter`, only to Google, and the Bar → Capture switch removes the button and the
key. `PRINT` opens the
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
