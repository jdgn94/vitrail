# Vitrail roadmap

Living document. Each task lists its dependencies and how we know it is done.
Nothing here is scheduled by date: the order is the dependency order.

## Locked decisions

| Area | Decision |
|---|---|
| Compositor | Hyprland only, Lua config (`hl.*`), runtime changes through `hyprctl eval` |
| Shell | Quickshell (`bar/`), settings in `shell/`, shared design system in `kit/` |
| Still wallpapers | `awww` (transitions, per-output) |
| Animated wallpapers | `mpvpaper` with `hwdec=vaapi` |
| Wallpaper import | GIF/video accepted, converted to mp4 (h264, output size, 15 fps, no audio) |
| Wallpaper rule | ≤ 30 s, ≤ 15 fps, estimated RAM ≤ budget |
| Login | SDDM theme fed by a snapshot of the last session (cursor, palette, wallpaper) |
| Lock | Native `ext-session-lock` client; wallpaper rotation frozen while locked |
| Modes | Priority: manual > focused app class > time window |
| Fonts / icons / cursor | One page, applied to the whole system at once |
| Settings | `~/.config/vitrail/*.ini`, one file per area (`vitrail/prefs.map`), versioned schema with migrations |

## Cross-cutting rules

These apply to every task below, not to a phase:

- **Accessibility**: every panel is reachable and usable with the keyboard alone,
  popups trap focus, and no action depends on hover.
- **Tooltips**: every bar element declares a live tooltip (`bar/TooltipLayer.qml`).
- **Dependencies**: every program Vitrail runs is declared in `packages/*.txt`;
  `tests/test_dependencies.py` is the gate.
- **Gallery**: a component that is not in the gallery is not part of the system.

## Measured baseline (this machine, 2560×1440)

| Case | RAM |
|---|---|
| `awww`, still image | 73 MB |
| `awww`, 17.7 s GIF (266 frames) | 1504–1666 MB |
| `mpvpaper`, 4K video, VA-API | 309 MB (2 % of one core) |

`awww` caches every frame at output resolution; `mpvpaper` streams and decodes on
the GPU, so its memory does not grow with duration.

---

## 0.5 — Panels and wallpapers (daily driver)

### P0 Foundations

| Task | Depends on | Done when |
|---|---|---|
| P0.1 Base components: Text, Button, Field, Icon, Tooltip; migrate `kit/composed` | — | Gallery renders every component × variant × theme; `test_design_system` passes with no raw primitives in composed |
| P0.2 Settings schema v2: immutable defaults, user overrides, migrations | P0.1 | Upgrading keeps every value; a packaged default change never overwrites a user override; `vitrail config validate` reports unknown keys |
| P0.3 Dependency + tooltip enforcement | — | `test_dependencies` and `test_tooltips` fail on an undeclared program or a button without a tooltip |
| P0.4 Wallpaper supervisor (awww + mpvpaper) | P0.2 | Switching still ↔ animated takes < 1 s, keeps the palette in sync, and survives shell reload |
| P0.5 `vitrail doctor` + safe mode | P0.2 | A broken Hyprland config still gives a usable bar; `vitrail doctor` exports a sanitised report with config, GPU, portals, services |

### P1 Shell surface

| Task | Depends on | Done when |
|---|---|---|
| P1.1 Generic popup host (kinds, anchors, keyboard, click-out, hover switching) | P0.1 | Three kinds open from the bar, move between buttons, close on outside click and after the idle timeout |
| P1.2 Notification panel: grouping, DND, expiry, actions | P1.1 | A burst of 20 notifications stays grouped; DND silences them; actions run |
| P1.3 Clipboard history (cliphist, text and images) | P1.1 | Copy → appears in the panel → selecting it pastes |
| P1.4 Music indicator (MPRIS): title, artist, controls | P1.1 | Controlled from the bar and from the notification panel |
| P1.5 Wallpaper panel: grid, type, transition, random, interval, import | P0.4 | Pick an image → transition plays → palette regenerates → survives a reboot; importing a 4K GIF produces an mp4 within budget |
| P1.6 Quick toggles: wifi, bluetooth, mic, DND | P1.1 | Each toggle reflects real state and survives a reload |
| P1.7 Native launcher: apps, windows, files, calculator, inline actions | P1.1, P0.1 | Opens from `Mod+D`, keyboard-only, no external launcher installed |
| P1.8 Keyboard navigation pass over every popup | P1.1–P1.7 | Every popup is fully operable with Tab/Space/Enter/Escape; focus never escapes the open popup |

### 0.5 acceptance

A fresh install can be used for a full day: bar, launcher, notifications,
clipboard, music, wallpapers, quick toggles, no config file editing.

---

## 0.7 — System integration

| Task | Depends on | Done when |
|---|---|---|
| P2.1 Monitors: layout, resolution, refresh, scale, rotation, per-monitor overrides | P0.2 | Two monitors with different scales persist and restore after logout |
| P2.2 Fonts, icons, cursor: system font, console font, UI icons, app icon pack, cursor | P0.1 | One change updates GTK, Qt, kitty, the shell and the cursor in the same session |
| P2.3 Power: profiles, battery state, low-battery warnings | P0.2 | Profile switch reflects in `powerprofilesctl` and survives reboot |
| P2.4 Modes engine: apps, time window, automatic | P0.2, P1.6 | A mode applies ≥ 2 effects (profile, DND, bar density); automatic wins over time, manual wins over both |
| P2.5 Installer: GPU detection (AMD/NVIDIA/Intel) and driver choice | P0.3 | A clean VM with each vendor gets the right driver and a working session |
| P2.6 Polkit agent with Vitrail styling | P0.1 | An elevation prompt from `pacman` appears in our surface, not in a GTK dialog |
| P2.7 Bluetooth: pairing, A2DP/HFP profile, peripheral battery | P1.1 | Pair, switch profile and read battery without leaving the panel |
| P2.8 App theme sync: Flatpak overrides, browser themes, libadwaita icons | P2.2 | A Flatpak app and Firefox follow the wallpaper palette without manual steps |
| P2.9 Snapshots: btrfs/Snapper or Timeshift integration in the installer | P0.2 | Snapshot taken before the first upgrade; restore documented and tested |

---

## 0.9 — Capture and session

| Task | Depends on | Done when |
|---|---|---|
| P3.1 Screenshots: region, window, full, annotate (grim/slurp/swappy) | P0.1 | Saved to the configured path and copied to the clipboard |
| P3.2 Recording: screen and region, with indicator and stop from the bar | P3.1 | Produces a playable file with audio |
| P4.1 Lock: native `ext-session-lock` client + PAM | P0.1, P4.2 | Locks all outputs, wrong password retries, unlock returns to the session; rotation timer frozen |
| P4.2 SDDM theme + last-session snapshot | P0.1, P2.2 | Greeter shows the last cursor, palette and wallpaper; wrong password is handled |
| P4.3 Idle policy: lock, DPMS, suspend, inhibit while media plays | P4.1 | Each timeout is configurable; playback and gamepads inhibit sleep |

---

## 1.0 — Widgets, toys and release

| Task | Depends on | Done when |
|---|---|---|
| P5.1 Desktop widget host (background layer, grid, per-monitor) | P0.1 | Two widgets stay in place across monitor changes |
| P5.2 Widget API + 3 built-ins (clock, system monitor, now playing) | P5.1 | A third-party widget can be dropped in without touching core files |
| P5.3 Notification-centre widgets | P5.2, P1.2 | The panel composes widgets from the same API |
| P5.4 Per-application audio mixer (PipeWire streams, move between sinks) | P2.3 | Each stream has its own volume and target device |
| P5.5 Keybinding overlay: searchable, generated from the Hyprland config | P1.7 | Opens with a shortcut and lists every bind, searchable |
| P5.6 Laptop support: lid switch, trackpad gestures, ambient light | P2.3 | Closing the lid suspends; gestures switch workspaces; brightness follows ambient light |
| P5.7 Flatpak/AppImage lifecycle: desktop entries, icons, permission overrides | P2.8 | A newly installed Flatpak appears in the launcher with its own icon |
| P5.8 Accessibility bridge: at-spi, screen reader pass | all | Orca announces every panel and popup action; no unreachable control |
| P6.1 Docs: install, features, theming, plugin API, troubleshooting | all | A new user can install and customise from the docs alone |
| P6.2 Packaging: AUR package of the installer + shell | P6.1 | `yay -S vitrail` gives the same result as cloning |
| P6.3 `vitrail update`: update the shell, configs and palette in one step | P6.2 | One command updates everything and keeps user overrides |

### 1.0 acceptance

Clean Arch/Manjaro → login → lock → daily use with every feature in this
document, no manual Hyprland editing, gallery and tests green.

---

## What to take from each reference repository

| Repo | Take | Do not take |
|---|---|---|
| caelestia-dots/shell | Global + per-monitor config split, wallpaper switcher flow, scheme presets, OSD patterns | Its whole config surface; we want fewer options, well explained |
| end-4/dots-hyprland | Widget concept, settings organisation, Lua Hyprland patterns | Code: it is GPL-3.0 |
| JaKooLit/Arch-Hyprland | Modular installer scripts, GPU detection, wallpaper picker flow, snapshot advice | Anything from its dots (archived upstream, March 2026) |

## Risks

| Risk | Mitigation |
|---|---|
| `awww` memory grows with duration | Animated wallpapers go to `mpvpaper`; awww only for stills |
| `ext-session-lock` needs native code | Ship a small C++ client; keep the QML unchanged between lock and login |
| SDDM cannot read the user's cache | Root-owned `/var/lib/vitrail/session.json` written at logout |
| Quickshell/Qt updates break bindings | Pin via package manifest; smoke test renders the shell headlessly |
| Design drift across panels | Gallery is the contract; composed components may not use raw primitives |
| A broken config locks the user out | P0.5 safe mode and `vitrail doctor` land before panels multiply |

## Open questions

- RAM budget per animated wallpaper (default 3 GB, measured at import).
- Image and colour pickers: our own components or system tools (`swappy`, `nwg-look`)?
- Plugin sandboxing: QML plugins run in-process; decide the trust model before shipping any.
