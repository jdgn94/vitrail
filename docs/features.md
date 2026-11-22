# Features

## Bar element foundation

`BarElementBase` (bar/BarElementBase.qml) is the base of every new bar element: the icon button with its tooltip, click, middle click, right click and wheel, a custom face when a button does not fit, and the "only while active" switch (Settings → Bar elements, one `barActiveOnly` preference for all elements). `BarSnapshot` brings an element's data from a Python module as one JSON snapshot, polled only while the element is in a bar. The sample element (bar/sample/, hidden by default) exercises every layer, and Settings → Bar elements has one block per element. See docs/bar-elements.md for the recipe.

## Volume bar element

An icon that follows the default output's level (muted, none, low, high) and, with `volumePercent`, the level as text. The wheel moves the master volume by `volumeStep` (1–25 %, default 5), a middle click mutes, and a click opens the popup: the master slider with its device's name and mute, one row per application stream (slider, mute, and an output chooser that moves the stream to another sink), the output and input device choosers and the microphone mute. `volumeHideSilent` leaves paused streams out. The data is `vitrail.audio`'s snapshot (`pw-dump`), polled only while the element is in a bar; every change is one `python3 -m vitrail.audio` process. Without PipeWire or `pw-dump` the icon goes neutral and the popup says it cannot read the audio server. Hidden by default (bar → Editor, or Settings → Bar elements), where its block holds the three options.

## Updates bar element

The number of pending packages, and nothing while there are none. `checkupdates` (pacman-contrib) fills the official repositories, `paru -Qua` or `yay -Qua` the AUR and `flatpak remote-ls --updates` Flatpak; `updatesSources` picks the three and `updatesAurHelper` fixes the AUR helper (`auto` follows what is installed). `updatesInterval` sets how often the snapshot is polled (minutes, 60 by default). The popup groups the rows by source (`name from → to`), turns what does not fit into "and N more", shows a source's failure as a calm line with its code, refreshes on demand and offers one Update per source that runs the snapshot's own argv (`sudo pacman -Syu`, `paru -Sua`, `flatpak update -y`) in a kitty terminal. When the total grows and at least one package is new, one notification offers the popup; the first snapshot after start is the silent baseline. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active": at zero it leaves the bar until it has something to say.

## Disks bar element

A drive glyph that appears while a removable drive is connected, from `vitrail.disks`' snapshot (`lsblk --json`). The popup draws one card per drive with its label, its size, a used/total bar and its mount point, and offers **Mount** or **Unmount**, **Eject** (only while unmounted) and **Open** (only while mounted, in the desktop's file manager through `vitrail.files`). The actions go through `udisksctl` as the user, without root or a password; a forbidden button is disabled with its reason underneath, and a failed answer is a calm line with the text `udisksctl` returned. `disksIgnore` (labels or UUIDs, one JSON array) leaves drives out of both the bar and the popup, and `disksAutomount` (off by default) mounts a newly seen drive through the same action: a drive is recorded before its mount starts, so it is never mounted twice, and it is forgotten when unplugged so a re-plug mounts again. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active": with nothing plugged in the element has no drive to name and leaves the bar.

## Containers bar element

The number of containers running, from `vitrail.containers`' snapshot (`docker ps -a --format json`, or `podman` when docker is absent). The popup lists one row per container with its name, its image, its state and health and its ports, pinned containers first with a pin toggle. **Start** is offered while a container is stopped, **Stop** while it runs, and **Logs** always, in a kitty terminal (`--tail 200`); no action ever runs without a click, and the snapshot refreshes after each one. `containersEngine` chooses the engine (`auto` follows docker, then podman) and `containersPinned` holds the names pinned first (one JSON array). Neither engine is a dependency: with neither installed the element's `active` is false, so its default "only while active" mode leaves the bar entirely and the popup would say which engines were looked for. Hidden by default (bar → Editor, or Settings → Bar elements).

## Peripherals battery bar element

The lowest battery among the watched mouse, keyboard, headset and gamepad, from `vitrail.battery`'s snapshot (`upower -e` and `upower -i`, one JSON object; the machine's own battery, line power and UPower's synthetic display device are already left out). The button writes that percentage beside a battery glyph and turns into a warning below `peripheralsLow` (5–50 %, default 20) while the device discharges; a charging device takes the bolt and the primary tone instead. The tooltip names the device and its level and, below, the other watched devices or the single device's state. The popup draws one row per watched device with its kind glyph, a level bar, the percentage and the state ("charging", "discharging", "full") plus the time left when UPower knows it; no device is one calm line, not an empty card. `peripheralsHide` (one JSON array of `mouse`, `keyboard`, `headphones` and `gamepad`) leaves whole kinds out of the bar and the popup, so the lowest is chosen among the devices still watched; "headset" is accepted for `headphones`. The lowest follows UPower's own rule: a discharging device wins over a lower charging one, and charging, full and unknown devices only compete when nothing discharges. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active": without a watched device that reports a percentage there is no number for the bar.
## Brightness bar element

A sun glyph that follows the primary monitor's level (the OSD's own `brightness_low`/`medium`/`high`); the wheel moves that monitor by `brightnessStep` (1–20 %, default 5), and a click opens the popup. The popup draws one row per monitor Hyprland reports: a laptop panel is read and written through `brightnessctl`, an external display over DDC/CI through `ddcutil`, and a display that cannot be read shows the reason instead of a slider. The night light section has its switch, a colour temperature slider (1000–10000 K, 4000 K by default), and a schedule: off, fixed hours, or sunset/sunrise from the weather module. `nightLightTemperature` and `nightLightSchedule` hold the values, `nightLightEnabled` the switch; the next change ("On at 19:42") is computed by `vitrail.nightlight`'s `plan()`, and one timer runs `vitrail.nightlight apply` at most once a minute while the switch is on, even with the popup closed. Hidden by default (bar → Editor, or Settings → Bar elements), where its block holds the step, the switch, the temperature and the schedule.

## Resources bar element

Two stacked mini bars (CPU in the accent, RAM in the info tone) or two numbers, chosen by `resourcesBar` (`both`, `cpu`, `ram` or `numbers`); the tooltip gives CPU, RAM and, when the machine has a thermal zone, the temperature, with the free disk space and the network rate on its second line. The popup draws five graphs from the sampler's history (CPU, memory, temperature, free disk, network down and up) with the current value and its unit, then the five busiest processes. **End** sends SIGTERM; a process that is still there offers **Force quit**, which asks "Sure?" before it sends SIGKILL, and nothing is killed without a click (`vitrail.resources kill` refuses pid 1, itself and the shell). A metric the machine does not have (no thermal zone, no disk) is one calm line in place of its graph. `resourcesInterval` (1–10 s, default 2) and `resourcesUnits` (`auto`: memory in KiB/MiB/GiB, disks and networks in kB/MB/GB; or `binary`/`decimal` everywhere) live in Settings → Bar elements. One sampler serves every consumer: `python3 -m vitrail.resources state --tick` once per tick through `bar/resources/ResourcesSampler.qml`, only while an element that reads it is in a bar (`--top` only while the popup is open), with one 60-point history ring. The previous CPU ticks and network counters live in a small cache under `$XDG_RUNTIME_DIR`, so a tick needs no pause. Hidden by default (bar → Editor, or Settings → Bar elements).

## System health bar element

A warning glyph that appears only when something is wrong, with the number of problems when there are several (the tooltip names the first and says "and N more"). `vitrail.health` checks failed user and system services (`systemctl --failed`), local filesystems under the free-space threshold, the errors `hyprctl configerrors` reports while Hyprland runs, and `vitrail doctor`; the shell adds the `bar` problem when one of its own bar entries could not load its component (`BarEntry.failed`, a `Loader.Error`). The icon takes the `error` tone when any problem is an error and the `info` tone while there are only warnings (the kit has no warning family). The popup lists one row per problem: a severity dot, the title (translated in QML from the problem's id, never an English code), the detail wrapped and capped at three lines, **Logs** and **Fix** when the problem has them. Both open the problem's argv in a kitty terminal the user sees (`--hold`), so nothing is ever fixed silently; a clean machine shows one calm "Everything is fine" line. `healthDiskThreshold` (1–50 %, default 5) and `healthChecks` (a JSON array of `services`, `disk`, `hyprland`, `doctor`; default all) live in Settings → Bar elements. The snapshot is read once a minute, only while the element is in a bar, and again when the popup opens or either setting changes. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active".

## Privacy bar element

One small dot that appears only while a watched microphone, camera or screen share is in use, and leaves the bar when the capture ends. `vitrail.privacy` reads the PipeWire graph (`pw-dump`): a running capture stream is a use, a camera that is merely present is not, a stream that reads a sink's monitor is not a microphone, and a stream fed by the screencast portal is a screen (its blind spots, such as X11 or `wlr-screencopy` captures, are listed in the module's docstring and are not widened in QML). The tooltip names the kinds in use and the first two applications ("and N more"); a use whose application has no name is still counted and shows its stream's name. The popup has one block per kind in use (an idle kind draws nothing), a row per application with its stream label, and **Cut off**, which says only "in use", never "recording", since the snapshot does not know that. Cut off runs `python3 -m vitrail.privacy stop KIND NODE`, which reads the graph again and destroys that one stream node (`pw-cli destroy`) only while it is still that use; the application is not killed and may reconnect. `privacyWatch` (a JSON array of `microphone`, `camera`, `screen`; default all) and `privacyDotColor` (`error`, `primary` or `info`, a palette role, never a literal; default `error`) live in Settings → Bar elements. The snapshot is read every two seconds, only while the element is in a bar, and again when the popup opens. Hidden by default (bar → Editor, or Settings → Bar elements), where it starts in "only while active"; "always" keeps a shield glyph in place while nothing is captured.

## Weather bar element

The condition glyph and the current temperature with its unit, from `vitrail.weather`'s Open-Meteo snapshot. The popup draws now (condition, temperature, today's high/low and the wind when the answer has it), the next twelve hours in a strip and the next five days, all through the same formatting helpers as the desktop weather widget (`temperature`, `degrees`, `condition` and `weekday` in `bar/dashboard/dashboard.js`). A city switcher over `weatherCities` writes `weatherLocation`, the preference the module already reads; `weatherUnits` is `metric` or `imperial`, and `weatherInterval` (minutes, 15 by default) is how often the bar asks for a snapshot, only while the element is in a bar or the night light's sun schedule needs the times. With a warm cache an offline answer keeps the last reading and adds one calm line; with no cache the state is only that line and the button hides in "only while active" (its default), since there is no temperature to show. Hidden by default (bar → Editor, or Settings → Bar elements), where its block holds the cities, the units and the interval.

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
