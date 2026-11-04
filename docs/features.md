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
- capture (three screenshots and recording),
- quick notes (kept in `misc.ini`),
- the session row (lock, log out, reboot, power off).

## Launcher

`Mod+D`: applications, windows, files, calculator, clipboard and web, with
inline actions (`>` run, `=` calculate, `/` files, `;` clipboard). The
`wallpaper:` mode lists the library's pictures as thumbnails and the eighteen
effects: choosing one shows that wallpaper (`vitrail wallpaper pick`) or sets
the effect for the whole screen. Keyboard only; the clip panel is `Mod+.`.

## Capture

Region, active window or full screen, saved under `~/Pictures/Screenshots` and
copied to the clipboard; annotation with `swappy` when enabled. Recording with
`wf-recorder` (full screen or a region) shows a red chip in the bar to stop it.
Folders and flags live in `capture.ini` (Bar → Capture).

## The settings window

Categories: Appearance, Fonts & icons, Wallpaper, Colors, Design, Bar, Windows,
Monitors, Terminal, Launcher, Input, Sound, Language, Date & time, Connection,
Plugins. Every preference is applied within a second by
`scripts/apply-settings.sh`; the window never runs commands itself.

## Networking and VPN

The Connection page lists Ethernet, Wi-Fi, VPN and Bluetooth with their real
state; the VPN module (`vpn/`) is Vitrail's own, with a domain-based split
tunnel.
