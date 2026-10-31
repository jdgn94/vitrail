# Date & time, system language

The settings window cannot run commands or read tzdata: `bin/vitrail-settings`
passes `--zones` (`python3 -m vitrail.timezones index <current>`: id, lat, lon,
UTC offset now, note, from `zone1970.tab`), `--timezone` and `--ntp`
(`timedatectl show`). The window only draws, filters and writes prefs.

## World map (`shell/pages/WorldMap.qml`, maths in `shell/worldmap.js`)

- Land: `kit/assets/world-110m.svg` (Natural Earth 1:110m, public domain),
  made by `python3 -I scripts/world-map.py <ne_110m_land.geojson> <svg>`; one
  path in tenths of a degree (viewBox 3600 x 1800). Read once with XHR and drawn
  as a `Shape`/`PathSvg` (vector, sharp at any zoom); `land` = `surfaceHigh`,
  `sea` = `surface`, dots `primary`.
- View = `{ zoom, ox, oy }`; `goal` is where it is heading, wheel steps and drags
  start from it. Wheel zooms around the pointer, drag pans (animation off while
  dragging), the map never leaves the viewport (`clamp`).
- One `MouseArea` finds the dot (`nearest`, radius = body size): hover grows it
  and shows a `VitrailTooltip` (zone name, local time, UTC offset); a click that
  is not a drag emits `picked`. A zone chosen elsewhere is centred only when
  zoomed in and out of view.
- Chosen zone: solid dot in a halo; the system's zone: a ring.

## Applying (`scripts/lib/system.sh`, called last by `apply-settings.sh`)

- Prefs: `timezone` ("" = untouched), `ntp` ("" / true / false), `languageSystem`.
  The page picks a zone first and applies with a button: a click on the map
  must not raise a password prompt.
- Each action runs only when the value differs from the system AND from the
  stamp in `~/.cache/vitrail/system/<key>` (written whatever the outcome, so a
  cancelled prompt is not repeated on every slider move). Dry run:
  `VITRAIL_DRY_RUN=1` prints `dry-run: <command>` instead of changing anything.
- Polkit asks through the bar's dialog. Locale generation runs
  `pkexec /usr/local/libexec/vitrail-locale-helper <locale>` (installed
  root-owned by `install.sh`, never the repo copy: a file the user can edit must
  not run as root); the helper accepts one locale found in
  `/usr/share/i18n/SUPPORTED`, enables it in `/etc/locale.gen`, runs `locale-gen`.
