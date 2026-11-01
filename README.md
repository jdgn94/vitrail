# Vitrail

Dotfiles and a desktop layer for Arch Linux built around Hyprland.

A *vitrail* is a single stained-glass window made of many colored panes: one
visual identity, one material, many compositors.

## Intent

- **One system, many compositors.** Configuration is written once and adapted
  to the detected compositor.
- **Material + Liquid Glass, with judgement.** Real transparency, blur and
  worked animations, not stacked effects.
- **Qt for the interface.** Our own Qt/QML tools to manage theme, windows, bar
  and settings without editing files by hand.

## Install

The installer is plain bash: a fresh Arch system has no Python, so nothing
else can be required.

```sh
./install.sh          # interactive
./install.sh --dry-run
./install.sh --yes --compositor hyprland --aur yay
```

The interactive flow uses the keyboard only:

| Key | Action |
|---|---|
| `↑` / `↓` (or `j` / `k`) | move |
| `space` | toggle the checkbox |
| `enter` | accept the selection |

It asks for the AUR helpers (`yay`, `paru`, `pikaur`; several are fine), shows a
full summary, and only writes after you confirm. Hyprland is the only desktop,
so it is not a question.

niri is not part of Vitrail: the project needs compositor-side rounding, blur
and per-focus opacity, which niri does not provide.

What it does:

1. Verifies the system is Arch or a derivative.
2. Installs the complete official package manifest with
   `pacman -S --needed`. The manifest is the same on your machine as on a clean
   system: packages you already have are skipped, never removed from the list.
3. Installs the chosen AUR helpers, bootstrapping them with `git` + `makepkg`
   when no helper exists yet, then installs the packages listed in `aur.txt`.
4. Links `dots/**` into `$HOME`, one file at a time.
5. Moves anything it is about to overwrite into `.backup/<timestamp>/`.

It never deletes: if a directory is in the way, it stops and says so.

## Runtime dependencies

Every program Vitrail starts at runtime is declared in `packages/*.txt`, which
`install.sh` installs, and checked by `tests/test_dependencies.py` (it scans
`bar/`, `kit/`, `shell/`, `scripts/`, `vitrail/` and the Hyprland config for
the programs they call). Adding a call to a new program means adding its
package to the manifest and a row here.

| Package | Provides | Used for |
|---|---|---|
| `hyprland`, `hyprlock` | `hyprctl`, `hyprlock` | compositor control, lock screen |
| `quickshell`, `qt6-declarative` | `quickshell`, `qml6` | the bar and the settings window |
| `matugen` | `matugen` | Material palette from the wallpaper |
| `ffmpeg`, `imagemagick` | `ffmpeg`, `ffprobe`, `magick` | wallpaper import and optimisation |
| `networkmanager` | `nmcli` | wired profile, network popout |
| `glib2` | `gsettings` | GTK light/dark |
| `kitty` | `kitty` | terminal, launcher `>` mode |
| `libqalculate` | `qalc` | launcher calculator and conversions (`=`) |
| `plocate`, `fd` | `plocate`, `fd` | launcher file search (`/`); `plocate-updatedb.timer` is enabled by the installer |
| `cliphist`, `wl-clipboard`, `wtype`, `hyprpicker` | `cliphist`, `wl-copy`, `wl-paste`, `wtype`, `hyprpicker` | launcher clipboard history (`;`), the clipboard panel (`Mod+.`) with emojis and the colour picker, and pasting a pick into the focused window |
| `xdg-utils` | `xdg-open` | opening files, folders and links |
| `wireplumber`, `playerctl`, `brightnessctl` | `wpctl`, `playerctl`, `brightnessctl` | media keys, laptop panel brightness |
| `ddcutil` | `ddcutil` | brightness of external monitors over DDC/CI (OSD); needs `/dev/i2c-*` access, set up by the installer |
| `grim`, `slurp` | `grim`, `slurp` | screenshots |
| `pciutils` | `lspci` | GPU vendor detection in the installer and `vitrail doctor` |
| `networkmanager`, `bluez-utils`, `wireplumber`, `power-profiles-daemon` | `nmcli`, `bluetoothctl`, `wpctl`, `powerprofilesctl` | the panel's quick toggles and the connection panel (networks, Bluetooth, power profile) |
| `awww`, `mpvpaper` | `awww`, `awww-daemon`, `mpvpaper` | still wallpapers with transitions (awww) and animated ones (mpvpaper with VA-API) |

`hypraether-vpn` comes from the VPN module (`vpn/`), not from the manifest.

## VPN

`vpn/` is the domain-based split tunnel imported from Hypraether: OpenVPN,
dnsmasq, nftables and policy routing. The installer drives it:

```sh
./install.sh --vpn split   # only the listed domains go through the tunnel
./install.sh --vpn full    # everything except the excluded domains
./install.sh --vpn none    # leave networking untouched (default unattended)
```

In the interactive installer it is a radio menu after the package questions.
Credentials live in a private sqlite vault (`~/.config/hypraether/vpn/vault.db`,
mode 600) and never in the repository; `vpn/.gitignore` blocks `*.ovpn` and
`vault.db`.

## Network

```sh
scripts/ensure-ethernet.sh
```

Marks the wired NetworkManager profile as autoconnect, priority 100 and
infinite retries, so the Ethernet link is always the one in use.

## Scrolling layout

Hyprland 0.56 ships the scrolling layout in core (`hyprscrolling` was merged),
so Vitrail only flips options:

```lua
hl.config({
  general = { layout = "scrolling" },
  scrolling = { column_width = 0.4, follow_focus = true, wrap_focus = false }
})
```

Windows → Layout exposes the switch, the default column width and both
behaviours. Turning it off returns to `dwindle`; nothing is restarted.

## Plugins

A plugin is a folder with `plugin.json` and a QML entry:

```json
{ "name": "hello", "version": "1.0.0", "entry": "Hello.qml" }
```

Installed in `~/.local/share/vitrail/plugins/<name>/`. `vitrail plugins index`
lists them, `vitrail plugins lock` pins them in
`~/.config/vitrail/plugins.lock.json`, and the Plugins page renders each entry
inside a card. See `examples/plugins/hello/`.

Plugins run inside the Vitrail process: **there is no sandbox**. Only install
code you trust.

## Style files

```sh
vitrail style show
vitrail style export --out my-style.json
vitrail style import my-style.json
```

A style carries `spacing`, `radius`, `blur`, `opacity` and `fontBase`, which is
what the Design page edits. Typography is a scale over `fontBase`, so one value
resizes the whole interface.

## Colors from an image

```sh
vitrail colors --image ~/Pictures/wall.png
vitrail colors --image https://example.com/wall.jpg --scheme vibrant --mode light
vitrail colors --image wall.png --out ~/.cache/vitrail/generated --reload
```

Accepts a local path or a URL (downloaded and cached in
`~/.cache/vitrail/wallpapers`). The engine is **matugen** (Material You); the
glass layer is computed by Vitrail.

- **Schemes:** `tonal` (default), `content`, `expressive`, `fidelity`,
  `vibrant`, `neutral`, `monochrome`, `rainbow`, `fruit-salad`, `smart`.
- **Mode:** `dark`, `light`, `smart` (picked from the image).
- **Contrast:** `--contrast -1..1`.

It writes themes for everything that supports live reload:

| File | Application |
|---|---|
| `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` | GTK and libadwaita |
| `qt/vitrail.qss` + `qml/VitrailTheme.qml` | Qt Widgets and Qt Quick |
| `hypr/colors.conf` | Hyprland (`$vitrail_*`) |
| `terminal/kitty.conf` | kitty |
| `theme.json` | Material roles + glass tokens |

`theme.json` is the stable interface: the Qt GUI reads from it, never from
matugen directly.

### Window decorations

Vitrail asks for the smallest possible decoration:

- `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` for Qt apps.
- `gtk-decoration-layout=:close` for the few GTK clients that still draw
  client-side decorations, so only a close button remains.

A close button drawn by Vitrail around another application's window is not
possible on Wayland: a client cannot frame another client's surface. Closing is
ours through `Mod+Q`.

### Applying settings

`scripts/apply-settings.sh` pushes the stored settings to the running session.
Hyprland 0.56 with a Lua config uses non-legacy parsers, where
`hyprctl keyword` is refused, so everything goes through `hyprctl eval`:

```lua
hl.config({
  general = { border_size = 2 },
  decoration = {
    rounding = 14,
    active_opacity = 0.97,
    inactive_opacity = 0.88,
    blur = { enabled = true, size = 6, passes = 3, ignore_opacity = false }
  },
  input = { follow_mouse = 1, kb_layout = "us,es", ... }
})
```

A legacy `hyprctl keyword` path is kept as a fallback for non-Lua configs.

Glass is the only surface style that turns blur on. Solid keeps the opacity the
user chose but draws no blur, so a translucent window shows the wallpaper
unfiltered. Blur itself is a single configurable value (`blurStrength`).

Applying is automatic: `vitrail-settings.path` (systemd user unit) watches
every preference file (one `PathChanged=` each; the directory is not watched,
because apply-settings writes its own files there) and runs
`vitrail-apply-settings` on every change, so the panel is live without a button.

### Preference files

Preferences are split by area into `~/.config/vitrail/<file>.ini`, named after
the category of the settings window that shows the key.
[`vitrail/prefs.map`](vitrail/prefs.map) (`<file> <key>` per line) is the one
source of truth: `vitrail/prefs.py`, the bar (`bar/prefs.js`), the apply script
(`scripts/lib/ini.sh`) and `shell/Prefs.qml` all follow it, and
`tests/test_prefs_map.py` fails when a key is used that the map does not list,
the window declares it in another file, or the path unit watches another set.

| File | Keys |
|------|------|
| `appearance.ini` | `appearance`, `surfaceStyle`, `surfaceOpacity`, `radius`, `blurStrength`, `spacing`, `fontBase` |
| `bar.ini` | `barEdge`, `barScreens`, `barStyle`, `barSize`, `barOpacity`, `barOpacityFollow`, `frameStyle`, `frameSize`, `panelSize`, `panelPush`, `notificationPosition`, `notificationMax`, `notificationDnd`, `clipboardMax`, `clipboardPaste`, `mediaStyle`, `trayStyle` |
| `wallpaper.ini` | `wallpaper`, `wallpaperMode`, `wallpaperDir`, `wallpaperType`, `wallpaperSelection`, `wallpaperInterval`, `wallpaperOrder`, `wallpaperImport`, `wallpaperRemove`, `systemColor` (`wallpaperSeed`: legacy) |
| `windows.ini` | `windowLayout`, `visibleColumns`, `followFocus`, `wrapFocus`, `borderWidth`, `opacityFocused`, `opacityUnfocused` |
| `input.ini` | `keyboardLayouts`, `keyboardSwitch`, `numlockOnStart`, `focusFollowsMouse` |
| `terminal.ini` | `terminalScheme`, `terminalPadding`, `fontSize`, `tabStyle`, `tabIcons`, `tabNumbers` |
| `launcher.ini` | `launcherEngine`, `launcherBangs`, `launcherModes`, `launcherView`, `launcherClear` |
| `language.ini` | `language`, `languageSystem` |
| `datetime.ini` | `timezone`, `ntp` |
| `misc.ini` | `selftest` (written by the smoke test), `quickNotes`, `clipboardColors` and any key the map does not list |

A key shared by several pages (`radius`, `blurStrength`, `surfaceStyle`,
`surfaceOpacity`) lives with the page that owns it, Appearance. To add a
preference: add its line to `prefs.map`, declare it in `shell/Prefs.qml` (the
file's `Settings` plus an alias), and read it by key everywhere.

**Migration.** A single `settings.ini` from before the split is divided into
these files the first time `vitrail-apply-settings`, `bin/vitrail-settings` or
the bar runs (`vitrail migrate`). It is serialised with a lock, writes each file
atomically (a file already split keeps its values), and renames the old file to
`settings.ini.before-split` last, so it can be re-run after an interruption.
The old file is removed rather than replaced by a pointer: nothing reads it
any more, and a stale one would suggest two sources of truth.

## Settings window

```sh
./bin/vitrail-settings
```

Qt 6 / QML panel that edits the preference files in `~/.config/vitrail/` immediately.

- **VitrailSurface** is the base container. `solid` uses the alpha you set and
  nothing else; `glass` lowers the alpha and adds a light edge. Real backdrop
  blur comes from the compositor, so the window itself stays transparent.
- **Theme:** light, dark or auto (auto follows the clock for now).
- **Palette:** taken from the wallpaper scheme produced by `vitrail colors`.
- **Navigation:** a collapsible category rail on the left; each category opens
  its own screens as subcategory tabs on the right.
- **Appearance:** theme and surface material.
- **Windows:** border geometry and window opacity (focused and unfocused).
  Blur is a single global value and only exists in glass mode.
- **Input:** keyboard layouts with variants and the switch shortcut; pointer
  focus behaviour.
- **Language:** `ON SAVE`, everything else is `LIVE`.

`LIVE` means the value is written as soon as you change it and applied by
`scripts/apply-settings.sh`. `ON SAVE` keeps a draft until you press Save (the
language works this way, because it only takes effect in the next session).
- **Language:** English, Spanish, Portuguese, Italian, French and German.

Changes are saved as you move a control. To push them to the session:

```sh
scripts/apply-settings.sh
```

That sets Hyprland's rounding, blur and inactive opacity through `hyprctl` and
writes `~/.config/environment.d/10-vitrail-locale.conf` for the language.
Hyprland has one blur size, so focused blur maps to `blur:size` and unfocused
blur maps to `inactive_opacity`.

Two Qt constraints are worked around in the code, both verified on Qt 6.11:

- `import QtCore` together with `Qt.labs.settings` in one file makes the window
  fail to load without a message, so paths arrive as command-line arguments.
- `XMLHttpRequest` never completes for local files, so translations are a
  JavaScript library and the palette arrives as one JSON argument.

## Login and lock

Both screens share `kit/AuthScreen.qml`: same card, same material, same
username and password fields. The lock only adds widgets through the `header`
and `extras` slots (the clock is the first one).

Preview them without installing anything:

```sh
./bin/vitrail-preview login
./bin/vitrail-preview lock
```

- **Login** is an SDDM theme (`login/`). SDDM 0.21 in this repo is Qt6, so it
  loads the same QML. Authentication is not wired yet: `submitted` is the hook
  where the SDDM login call goes.
- **Lock** is the UI half only. A real locker must take `ext-session-lock-v1`
  from a native Wayland client; QML cannot do that on its own. The card, the
  fields and the slots are already the ones the native client will render.

One QML trap worth knowing: properties whose names start with `on`
(`onSurface`, `onPrimary`) are read as signal handlers and their bindings
silently never apply. The palette therefore uses `foreground`, `muted` and
`accentForeground`.

## Development

The project uses [uv](https://docs.astral.sh/uv/): the environment lives in
`.venv` and never touches the system Python.

```sh
uv sync
uv run python -m unittest discover -s tests   # color engine + translations
bash tests/install_test.sh                    # bash installer
bash tests/qml_smoke.sh                       # QML lint + offscreen render
uv run vitrail --help
```

`graphify` is installed as a development dependency from the `graphifyy`
package and stays isolated in `.venv`:

```sh
uv run graphify --version
uv run graphify install --platform opencode   # optional: agent skill
```

Graph artifacts (`graphify-out/`) are regenerated and not versioned.

## Structure

```
install.sh   interactive bash installer (no Python required)
bin/         vitrail-settings and vitrail-preview launchers
vpn/         split-tunnel VPN module (installer, config, CLI)
kit/         shared design system: surface, auth base, palette, i18n
shell/       Qt/QML settings window
login/       SDDM theme
lock/        lock screen UI
scripts/     apply-settings.sh (Hyprland + locale)
packages/    manifests: base, hyprland, aur
dots/        what gets linked into $HOME (empty for now)
vitrail/     colors.py (theme engine) and cli.py (commands)
tests/       installer, QML smoke test, colors and translation tests
```

## Status

Interactive installer, theme engine and the first settings window are working.
Next: the dotfiles and the remaining settings pages.

## Safe mode

When a Hyprland config change leaves the session unusable:

```sh
vitrail safe-mode status     # reads hyprctl configerrors, exits 1 on errors
vitrail safe-mode enter      # arms the fallback
vitrail safe-mode session    # starts Hyprland with dots/.config/hypr/safe.lua
vitrail safe-mode exit       # back to the normal config
```

The fallback config knows four binds (`Mod+Q`, `Mod+Return`, `Mod+,`,
`Mod+Shift+Q`) and starts the bar, so the settings window is reachable even
when the normal config does not load.

## Bar and screen frame

```sh
vitrail-bar          # started by Hyprland on login (needs quickshell)
vitrail-gallery      # every frame × bar × edge combination
```

The bar has three slots, *start*, *center* and *end*: left/center/right when
it is horizontal, top/middle/bottom when it is vertical. It lives inside a
frame drawn around the whole screen whose inner corners follow the system
radius. Everything is chosen in **Settings → Bar** and applies live:

| Setting | Values |
|---|---|
| Position | left, top, right, bottom |
| Monitors | `primary` (top-left monitor, default) or `all`; the frame is drawn on every monitor |
| Bar style | `docked` (melts into the frame), `floating` (island inside it) |
| Screen frame | `full` (border), `corners` (rounded corners only), `none` |
| Bar opacity | like focused windows (`opacityFocused`) or its own value |
| Bar size / frame width / panel size | token ranges from `kit/tokens.js` |

### Wallpaper

**Settings → Wallpaper** lists the images and videos in `~/Pictures/Wallpapers`
(`wallpaperDir` in `wallpaper.ini` changes the folder). The bar draws the
wallpaper itself, so it can follow the frame:

- `frame`: the wallpaper fits inside the frame and makes room when a full
  panel opens; windows make room too.
- `screen`: the wallpaper covers the whole screen and never moves. Windows
  make room for full panels only if *Windows make room for full panels* is on.

On glass the frame shows a blurred copy of the wallpaper; on solid it sits on
the surface color. Choosing a wallpaper regenerates the palette (a video lends
one frame through `ffmpeg`). Until one is chosen, any other wallpaper tool
keeps working.

### Panels

| Keys | Panel |
|---|---|
| `Super + P` | `full`: grows out of the frame along the bar edge |
| `Super + Shift + P` | `overlay`: floats above wallpaper and windows, moves nothing |

Both are also scriptable: `vitrail-bar ipc call panel toggle full|overlay`,
`vitrail-bar ipc call panel close`. Panels are empty for now.
