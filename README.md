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
| `fontconfig` | `fc-list` | the installed font families the Fonts page offers |
| `libqalculate` | `qalc` | launcher calculator and conversions (`=`) |
| `plocate`, `fd` | `plocate`, `fd` | launcher file search (`/`); `plocate-updatedb.timer` is enabled by the installer |
| `cliphist`, `wl-clipboard`, `wtype`, `hyprpicker` | `cliphist`, `wl-copy`, `wl-paste`, `wtype`, `hyprpicker` | launcher clipboard history (`;`), the clipboard panel (`Mod+.`) with emojis and the colour picker, and pasting a pick into the focused window |
| `xdg-utils` | `xdg-open`, `xdg-mime` | opening files, folders and links; finding the desktop's file manager |
| `nautilus` | the file manager | "open folder" and "open file" of a download, with the desktop's own choice read from `xdg-mime` (Nautilus is the fallback installed with Vitrail) |
| `python-dbus`, `python-gobject` | — | the downloads watcher (`vitrail/downloads.py`): a notification per download and the buttons that cancel, delete or open it |
| `wireplumber`, `playerctl`, `brightnessctl` | `wpctl`, `playerctl`, `brightnessctl` | media keys, laptop panel brightness |
| `ddcutil` | `ddcutil` | brightness of external monitors over DDC/CI (OSD); needs `/dev/i2c-*` access, set up by the installer |
| `grim`, `slurp` | `grim`, `slurp` | screenshots |
| `pciutils` | `lspci` | GPU vendor detection in the installer and `vitrail doctor` |
| `networkmanager`, `bluez-utils`, `wireplumber`, `power-profiles-daemon` | `nmcli`, `bluetoothctl`, `wpctl`, `powerprofilesctl` | the panel's quick toggles, the bar's network and power-profile popups, and the settings window's Connection page (networks, Bluetooth and power profile; `vitrail.network`: Wi-Fi, Bluetooth and VPN state and requests) |
| `awww`, `mpvpaper` | `awww`, `awww-daemon`, `mpvpaper` | still wallpapers with transitions (awww) and animated ones (mpvpaper with VA-API) |

`vitrail-vpn` comes from the VPN module (`vpn/`), not from the manifest.
`ping` (iputils, in the Arch `base` group, so not in the manifest) measures the
latency of each VPN connection for the VPN tab and for the automatic choice of
the best one. `xdg-desktop-portal-gtk` (in `packages/base.txt`) or any other
FileChooser backend of your portal config serves the settings window's file
dialog.

## VPN

`vpn/` is the domain-based split tunnel imported from Vitrail: OpenVPN,
dnsmasq, nftables and policy routing. The installer drives it:

```sh
./install.sh --vpn split   # only the listed domains go through the tunnel
./install.sh --vpn full    # everything except the excluded domains
./install.sh --vpn none    # leave networking untouched (default unattended)
```

In the interactive installer it is a radio menu after the package questions.
Credentials live in a private sqlite vault (`~/.config/vitrail-vpn/vault.db`,
mode 600) and never in the repository; `vpn/.gitignore` blocks `*.ovpn` and
`vault.db`.

The tunnel is vitrail-vpn's own **system unit**
(`vitrail-vpn@<id>.service`, started by `vitrail-vpn connect`, with
`Restart=on-failure`), never a child of Vitrail: stopping or restarting the bar
leaves the connection exactly where it was. The **login rule** is the
`vitrail-vpn-autostart.service` user unit (installed with the dotfiles and
enabled by `install.sh` when the VPN is installed): it runs
`vitrail-network autostart`, which connects the best connection while
`~/.config/vitrail-vpn/enabled` asks for it. As a unit, it does not depend on
the bar — the tunnel comes up after a login even if Quickshell never starts.
Logs: `journalctl --user -u vitrail-vpn-autostart` for the rule and
`journalctl -u "vitrail-vpn@*"` for the tunnel.

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
| `bar.ini` | `barEdge`, `barScreens`, `barStyle`, `barSize`, `barOpacity`, `barOpacityFollow`, `frameStyle`, `frameSize`, `panelSize`, `panelPush`, `notificationPosition`, `notificationMax`, `notificationDnd`, `notificationMuteUntil`, `notificationSnooze`, `notificationMuted`, `notificationUrgentApps`, `notificationUrgentBypass`, `notificationSnoozes`, `clipboardMax`, `clipboardPaste`, `mediaStyle`, `trayStyle`, `osdKeys`, `osdKeyTime`, `osdHotZone`, `osdSize`, `osdStep`, `osdBrightnessStep` |
| `wallpaper.ini` | `wallpaper`, `wallpaperMode`, `wallpaperDir`, `wallpaperType`, `wallpaperSelection`, `wallpaperInterval`, `wallpaperOrder`, `wallpaperImport`, `wallpaperRemove`, `systemColor` (`wallpaperSeed`: legacy) |
| `windows.ini` | `windowLayout`, `visibleColumns`, `followFocus`, `wrapFocus`, `borderWidth`, `opacityFocused`, `opacityUnfocused` |
| `monitors.ini` | `monitorOverrides` |
| `input.ini` | `keyboardLayouts`, `keyboardSwitch`, `numlockOnStart`, `focusFollowsMouse` |
| `terminal.ini` | `terminalScheme`, `terminalPadding`, `fontSize`, `tabStyle`, `tabIcons`, `tabNumbers` |
| `sound.ini` | `soundOutputApps`, `soundInputApps`, `soundFocusApps`, `soundStep` |
| `fonts.ini` | `fontSystem`, `fontConsole`, `uiIcons`, `iconTheme`, `cursorTheme`, `cursorSize` |
| `launcher.ini` | `launcherEngine`, `launcherBangs`, `launcherModes`, `launcherView`, `launcherClear` |
| `language.ini` | `language`, `languageSystem` |
| `datetime.ini` | `timezone`, `ntp` |
| `connection.ini` | `connectionRequest`, `connectionSeq` (the Connection page's request, run once per counter value) |
| `misc.ini` | `selftest` (written by the smoke test), `quickNotes`, `clipboardColors` and any key the map does not list |

The VPN keeps its own document outside these files, in a folder of its own:
`~/.config/vitrail-vpn/settings.ini` (`vpnSettings`: which connections the
automatic choice may use) and `~/.local/share/vitrail-vpn/` (the OpenVPN files
Vitrail copied there). Both are created 0700, their files 0600, and they follow
`$HOME`: every system user has its own document, files and rules, and the
migration moves the old `vpnSettings` out of `misc.ini` once.

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
- **Fonts & icons:** three tabs (Text, Icons, Cursor) over the lists this
  machine has (`fc-list`, `/usr/share/icons`): one system font for the apps
  and the shell, the console font, the shell's Material Symbols family, the
  GTK/Qt icon pack, and the cursor pack with its size. The window cannot run
  commands, so `bin/vitrail-settings` injects `python3 -m vitrail.fonts state`
  as `--fonts`; `scripts/apply-settings.sh` runs `fonts apply` when
  `fonts.ini` changes, and a value that is not installed falls back to its
  default instead of reaching fontconfig. Palette-tinted cursors are P2.10.
- **Windows:** border geometry and window opacity (focused and unfocused).
  Blur is a single global value and only exists in glass mode.
- **Monitors:** each output's mode, scale, rotation, position, mirror and
  enabled state, saved as one JSON document in `monitors.ini` (`monitorOverrides`)
  and applied when it changes and at login: the Hyprland start hook runs
  `vitrail-monitors apply --force`, so a two-monitor layout with different
  scales comes back after a logout without the bar being involved.
- **Input:** keyboard layouts with variants and the switch shortcut; pointer
  focus behaviour.
- **Connection:** Internet (Ethernet and Wi-Fi), VPN and Bluetooth on tabs. The
  window cannot run commands, so `bin/vitrail-settings` injects the state
  (`python3 -m vitrail.network state`, as `--network`), and a click writes
  `connectionRequest` and raises `connectionSeq` in `connection.ini`.
  `scripts/apply-settings.sh` runs `python3 -m vitrail.network apply <request>`
  once per counter value (stamp: `~/.cache/vitrail/system/connection-seq`; the
  journal of `vitrail-settings.service` gets the verb, the credential's name
  and the commands without secrets) and `apply` rewrites
  `~/.config/vitrail/network-state.json`, which the page polls while it waits
  (its `result` says which verb it answers and whether it failed).
  `--tab internet|vpn|bluetooth` opens a tab; `--view global|<connection id>`
  opens a VPN view.

  The VPN tab shows **vitrail-vpn's own model**, never a parallel list. The
  state's `vpn` has `tunnels` (id, name, provider, region, credential,
  config_path, active), `credentials` (name, username, usedBy; no password),
  `mode` (`split`/`full`), `domains` (domain, address count), `enabled` (the
  tool's `~/.config/vitrail-vpn/enabled` marker), `quality` (`{id: {latency,
  loss}}` from the last probe; `state` never pings). Four views: the
  connections (a `tune` button at the left of each row opens its settings, the
  ping and quality level (good < 100 ms and no loss, fair < 250 ms and at most
  10 % loss, poor, or "—" when unmeasured) of every connection sits left of
  Connect / Disconnect, and an "Add VPN" and a "VPN settings" button close the
  section), the import form ("Add VPN", also the last block of the global
  settings), the global settings (traffic mode,
  connect at startup, the URL list grouped by registrable domain, credentials,
  import) and one connection's settings (name, provider, region and config path
  read-only; credential; "Use for the automatic choice"; remove).
  Requests: `wifi-on`, `wifi-off`, `wifi-connect:<ssid>`, `wifi-disconnect`,
  `bt-on`, `bt-off`, `bt-connect:<mac>`, `bt-disconnect:<mac>`, `bt-scan`,
  `refresh`, and for the VPN `vpn-up:<id>`, `vpn-down:<id>`, `vpn-off`
  (disconnect), `vpn-best` (probe, then connect the best), `vpn-probe`,
  `vpn-mode:split|full`, `vpn-domain-add:<url>`, `vpn-domain-remove:<domain>`,
  `vpn-domain-refresh`, `vpn-remove:<id>`, `vpn-cred-remove:<name>` and the
  JSON ones `vpn-import:{file,name?,credential?}`,
  `vpn-cred-add:{name,user,nonce}`, `vpn-cred-update:{name,rename?,user?,nonce?}`
  and `vpn-cred-assign:{name,ids}`; anything else is refused, every argument is
  validated and reaches the tool as one argv item. The VPN tab sends
  `vpn-probe` when it opens and every minute while it is open; it is a
  background request (`shell/vpnqueue.js`): the page stays operable while it
  runs, a tick is skipped while a real request is busy or pending, and a
  request made during a probe waits as the one pending request and goes out
  when the probe's answer (or its 20 s timeout) lands. The bar's VPN popup
  shows the same ping and level beside each connection, read from
  `network-state.json`; when nothing measured them within a minute it asks for
  a `vpn-probe` the same way (`connectionRequest` then `connectionSeq`, at most
  once a minute).
  `vpn-domain-add:<url>` adds the host and the live subdomains that
  certificate transparency (crt.sh) lists for its registrable domain (at most
  50) with `domain add` each. The marker is the "Connect at startup" switch:
  on runs `vpn-best`, off runs `vpn-off`, and Connect / Disconnect on any row
  moves it through the tool; Vitrail keeps no copy.

  The automatic choice is vitrail-vpn's rule: of the connections with a
  credential (all if none has one) the measured one with the lowest latency
  (mean of the average round trips of up to three `remote` hosts of its
  config, `env LANG=C ping -c 3 -W 1`, side by side), packet loss breaking a
  tie; nothing measured, the first. Vitrail adds one filter: a connection
  switched off under "Use for the automatic choice" (`vpnSettings` in
  `~/.config/vitrail-vpn/settings.ini`, `{"connections": {"<id>": {"auto":
  false}}}`) is left out unless that leaves nothing.

  An import copies the picked `.ovpn` into `~/.local/share/vitrail-vpn` first
  (0700/0600, verified by its digest) and hands that copy to the tool, so the
  connection never depends on a file the user may move; "Move the original
  file" deletes it only after the copy is verified. At login the bar runs
  `python3 -m vitrail.network autostart` once per graphical session (a stamp
  under `$XDG_RUNTIME_DIR`, keyed by the compositor instance, so restarting the
  bar never undoes a disconnect): the marker with nothing up and a credential
  connects the best (waiting up to 30 s for NetworkManager when nothing could
  be measured), a tunnel up without the marker records the marker, otherwise
  nothing happens.

  Passwords never travel in `connection.ini`, `misc.ini`, the state, an
  argument or a log. The page writes the password with `Qt.labs.settings` to
  `$XDG_RUNTIME_DIR/vitrail-secret-<nonce>.ini` (a private tmpfs;
  `bin/vitrail-settings` passes it as `--runtime`) and the request carries only
  the random nonce; the helper reads it, gives the tool a private copy
  (`--pass-file`, mode 0600) and deletes both files whatever happens, and
  files older than five minutes are swept at every request. The file dialog of
  the import form is `QtQuick.Dialogs.FileDialog`; `bin/vitrail-settings`
  sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal` for the window so it reaches the
  desktop's portal (under `qt6ct` Qt draws a plain dialog of its own). The
  settings window runs with `umask 077`, so every file it writes (the VPN
  document included) is its user's alone.
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

`graphify` (the `graphifyy` package, in the `dev` group) builds the code graph
in `graphify-out/`, which is git-ignored and never committed. The tracked hooks
in `.githooks/` do the routine work: a **pre-commit** formats the staged Python
with `ruff` (120 columns) and the staged shell with `shfmt` (4 spaces, indented
case arms, operators first), and a **post-commit** refreshes the graph in the
background (`scripts/graphify-refresh.sh`, detached, one build at a time).
Enable them once per clone:

```sh
scripts/install-hooks.sh
uv run graphify --version
graphify query "how does the frame open a popup"
```

QML and the `.pragma library` JS are hand-formatted on purpose: `qmlformat`
rewrites the import order, expands inline objects and collapses the aligned
ternaries, and Prettier cannot parse the pragma.

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

### Session menu

The power button opens a full-screen menu on its monitor (right click: the
compact popout). Lock runs at once; the actions that cut work — suspend,
hibernate, restart, shut down, and log out — first check what is still running
(`vitrail/session.py`: a download, a package manager, a job started through
`vitrail/jobs.py`) and, when there is something, say what it is with **Cancel**
and **Go ahead**. After that (except log out) a **30 second countdown** runs,
with **Cancel** and **Do it now**, and the action happens by itself when it
reaches zero. Escape cancels (and returns to the menu), Enter confirms; the
countdown, the command and the check live in the bar (`shell.runSession`).

### Notifications

The bar owns `org.freedesktop.Notifications` (Quickshell's server): an app's
notification becomes a card on the opposite side of the bar, the panel
(`Super + N`, or a hot zone on that side) keeps what arrived after the toast
expires, and Do Not Disturb lists arrivals without showing them. The stack
takes the newest five (`notificationMax`).

**Downloads** are notifications of their own. No D-Bus API reports a download,
so `vitrail/downloads.py` runs with the bar and watches the XDG download
folders for the files a downloader is still writing (`.part`, `.crdownload`,
`.download`, `.tmp`): each one is a card with the app that is writing it, the
name, the size, the speed, the elapsed time and a bar, replaced in place as the
file grows and never toasted twice. The total is only known when the
downloader reserved the final size, so the card shows a percentage when it can
and an indeterminate bar otherwise — never an invented one. The X at the end of
the bar removes the partial file (if the app keeps writing, the card says so);
when the file becomes its final name the card says how long it took and offers
**Delete**, **Open folder** and **Open file**, which use the file manager the
desktop is configured with (`xdg-mime query default inode/directory`, Nautilus
as the fallback).

Every card offers **Copy** (through the clipboard store), **Snooze** (15
minutes, 1 hour or tomorrow: it leaves the list and comes back by itself) and
**Mute** for its app. A bell beside the launcher opens the centre on its
monitor (left click) and silences everything for an hour (right click; a second
right click turns it back on). The panel comes in from its whole edge, its
groups follow one another, and **Clear all** runs the cards back out that way
before they leave. It groups a chat by conversation (`Telegram Desktop · Ana`,
with its unread count), lists the muted apps and shows today's counts per app —
how many arrived, how many were acted on — so a noisy app can be muted with
evidence. A notification marked urgent (a critical urgency, or an app in
`notificationUrgentApps`) wears a marked border and bypasses Do Not Disturb
when `notificationUrgentBypass` is on. A picture or file attachment opens with
the file manager, and bare URLs in the body are links. The last 300 rows and
the counts live in `~/.local/state/vitrail/notifications.json`
(`vitrail/notify.py`), so they survive a reload.

Any other long task uses the same card through one small API:
`python3 -m vitrail.jobs run --name "Updating packages" -- pacman -Syu`, or the
`Job` class for a progress the tool can report (`job.update(done, total)`);
Cancel stops the child process.
