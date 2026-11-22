# Bar elements — plan

New elements for the bar, each with its own popup, placed and hidden like the
ones the bar already has (launcher, workspaces, notifications, title, media,
clock, capture, recording, tray, network, bluetooth, vpn, profile, battery,
keyboard, power, divider). Agreed 2026-11-21. Phone integration is out: it
will be its own program.

Work goes one step at a time, in order. A step is finished only when its
"Done when" holds and it is committed on its own.

## Every element ships with

The same contract as today's elements (AGENTS.md):

1. An entry in `bar/widgets.js` (`surfaces: ["bar"]`, group, `labelKey`,
   icon, sizes/styles), so the bar editor can place, hide and put it in a
   chip.
2. Its button in `bar/<area>/`, built from `kit/` only, with `tooltip` and
   `tooltipDetail` kept live.
3. A popup that opens from it with the shared popup frame and the settings
   gear (`VitrailPopupGear`) pointing at its settings page.
4. Its preferences in `vitrail/prefs.map` and `shell/Prefs.qml`, and a place
   in the settings window.
5. Its words in all six `kit/i18n/*.json`.
6. Every program it runs in `packages/*.txt`, the PKGBUILDs, the README
   "Runtime dependencies" table and `tests/test_dependencies.py`.
7. A gallery entry, QML/Python tests, and a line in `docs/features.md` and
   `docs/manual-checks.md`.
8. Hidden by default (`DEFAULT_HIDDEN`), so nobody's bar changes until they
   add it.

Elements that only matter sometimes (privacy, updates, downloads, disks,
system health, pomodoro) take a shared "only while active" option: shown
while there is something to say, or always.

## Steps

### Step 0 — Foundation

- A `BarElement` base, a popup host and the "only while active" switch, shared
  by every new element. That way each element is its button, its popup and its
  data.
- A small pattern for data that comes from Python, with one snapshot over
  JSON and polling or a watch. It follows `vitrail/weather.py` and
  `vitrail/resources.py`.
- A "Bar elements" section in settings that lists each element and links to
  its options.

**Done when:** a sample element can be added, moved, hidden and opened, with a
tooltip and the popup's gear, and its tests pass.

### Step 1 — Volume

- **On the bar:** an icon showing the level. The wheel raises or lowers the
  volume, and a middle click mutes.
- **Popup:**
  - Master volume.
  - A slider for each application. This is roadmap P5.4: PipeWire streams,
    each of which can be moved to another output.
  - Choice of output and input device.
  - Microphone mute.
- **Reuse:** `bar/osd/audio.js` and the OSD's Pipewire code.
- **Options:** the wheel step, whether to show a percentage, and whether to
  hide streams that are silent.

### Step 2 — Brightness

- **On the bar:** an icon; the wheel changes brightness.
- **Popup:**
  - Brightness of each monitor (`brightnessctl` / `ddcutil`, already in use).
  - Night light: temperature, a schedule (fixed hours or sunset/sunrise), and
    an on/off switch.
- **New dependency:** night light needs `hyprsunset`. Declare it.
- **Options:** the step, the night light temperature and the schedule.

### Step 3 — Clock with a grouped popup (replaces a separate calendar)

- **One clock on the bar**, whose popup can group widgets.
- **Group switched off:** the popup shows only the calendar (month view, with
  today marked).
- **Group switched on:** the user chooses and orders the widgets that appear
  beside the calendar: weather, pomodoro/timer, notes, a second time zone, and
  resources.
- **Reuse:** the dashboard widgets that already exist (`bar/widgets/Dashboard*.qml`,
  `bar/dashboard/`).
- **Options:** a `clockGroup` switch, and the list and order of grouped
  widgets, edited the way the panel's order is edited.
- **Open:** whether the calendar shows events, and from which source (local
  ICS, CalDAV). Decide this before the step.

### Step 4 — Resources and network usage

- **Resources:**
  - On the bar: CPU and RAM as mini bars or numbers.
  - Popup: graphs of CPU, RAM, temperature, disk and network, plus the top
    processes with a button to end one.
- **Network usage:**
  - On the bar: up and down speed.
  - Popup: a graph and today's usage.
- **Shared sampler:** both read one sampler built on `vitrail/resources.py`,
  read once per tick.
- **Options:** the sampling interval, what the bar shows, and the units.

### Step 5 — Weather

- **On the bar:** an icon and the temperature.
- **Popup:** hourly and 5-day forecast, and a city switcher.
- **Reuse:** `vitrail/weather.py` and `DashboardWeather.qml`.
- **Options:** the city or cities, units, and the refresh interval.

### Step 6 — Pomodoro / timer and quick notes

- **Pomodoro / timer:**
  - On the bar: a countdown, shown only while one is running unless set to
    always show.
  - Popup: start, pause, cycles, quick timers (5, 10, 25 min).
  - Reuses `TimerEngine.qml` and `timers.js`.
- **Notes:**
  - On the bar: an icon showing how many notes there are.
  - Popup: the list and a field to write a new one.
  - Reuses `bar/notes/`.
- **Clock group:** both can also live in the clock's group (step 3).

### Step 7 — Privacy

- **On the bar:** a coloured dot while the microphone, camera or screen
  sharing is in use.
- **Popup:** which application is using each one, with a button to cut it
  off.
- **Source:** PipeWire nodes for the microphone and camera; portal
  screencast nodes for the screen.
- **Options:** which devices to watch, and the dot's colour.

### Step 8 — Do not disturb / focus and caffeine

- **Do not disturb / focus:**
  - On the bar: a moon; a click toggles it.
  - Popup: duration (30 min, 1 h, until tomorrow) and allowed applications.
  - It reuses the existing `notificationDnd`, `notificationMuteUntil` and
    urgent-bypass preferences.
- **Caffeine:**
  - On the bar: a cup; while on, the screen does not turn off or suspend.
  - Popup: duration and state.
  - Uses Quickshell's `IdleInhibitor`.

### Step 9 — Clipboard and colour picker

- **Clipboard:**
  - On the bar: an icon.
  - Popup: the last five copies, using the rich preview, and a button that
    opens the full history (`Super+V`).
- **Colour picker:**
  - On the bar: an eyedropper; a click picks from the screen.
  - Popup: recent colours and a button that opens the palette (`Super+P`).
- **Reuse:** `bar/clipboard/`.

### Step 10 — Updates

- **On the bar:** the number of pending packages, only when there are some.
- **Popup:**
  - A list by source (official repositories, AUR, Flatpak).
  - An "Update" button that runs the update in a kitty terminal.
- **Tools:** `checkupdates` comes from `pacman-contrib`, a new dependency.
  AUR updates use `paru -Qua` or `yay -Qua`, whichever is installed.
- **Options:** how often to check, which sources, and the AUR helper.
- **Open:** whether to notify when updates appear.

### Step 11 — Downloads

- **On the bar:** progress while downloads are running.
- **Popup:** active and recent downloads, with buttons to open each file or
  its folder.
- **Reuse:** `vitrail/downloads.py` and `vitrail/jobs.py`.

### Step 12 — Disks

- **On the bar:** appears when a removable drive is connected.
- **Popup:** mount, unmount, eject and open each drive, with its used space.
- **Tools:** `udisks2` / `udisksctl`, a new dependency.
- **Options:** automount, and which drives to ignore.

### Step 13 — System health

- **On the bar:** appears only when something is wrong.
- **What it checks:**
  - failed user or system services
  - free disk space under a threshold
  - Hyprland config errors (`hyprctl configerrors`)
  - the bar's own load errors
  - `vitrail doctor`
- **Popup:** what is wrong, with a button for each problem to fix it or show
  its logs.
- **Options:** the disk threshold, and which checks are on.

### Step 14 — Peripherals battery

- **On the bar:** the lowest battery among mouse, headphones and gamepad.
- **Popup:** each device's battery.
- **Source:** UPower devices, already a dependency.
- **Options:** which devices to show, and the low-battery warning level.

### Step 15 — Containers and services

- **On the bar:** the number of containers running.
- **Popup:** start, stop and view logs, for `docker` or `podman`, whichever is
  installed.
- **Options:** which engine, and which containers to pin.
- **Dependencies:** optional. The element hides itself when neither engine is
  present, so neither becomes a dependency.

### Step 16 — Crypto / stocks

- **On the bar:** the price of a chosen symbol.
- **Popup:** a graph of the day and a list of symbols.
- **Open:** which data provider to use, and whether it needs an API key
  (stored in the secret store, never in git). Its requests leave the
  machine, so choosing the provider is the user's decision.

## Open questions

1. Calendar events (step 3): none, local ICS, or CalDAV?
2. Updates (step 10): notify when new updates appear, or only the counter?
3. Crypto/stocks (step 16): which provider, and whether there is an API key.
4. Night light (step 2): is adding `hyprsunset` acceptable?
