# The palette in Flatpak apps and Firefox

GTK's generated CSS covers applications that can read `~/.config/gtk-3.0`.
Two kinds of application cannot, and this is what Vitrail does about them:

- **Flatpak apps** run in a sandbox where that folder does not exist;
- **Firefox** does not read GTK's CSS for its own chrome.

The code is `vitrail/apps.py`; it runs from `vitrail theme apply`, which
`scripts/apply-settings.sh` calls after every palette change.

## Flatpak

`flatpak override --user` grants every installed application read-only access
to what the theme needs:

| Path | Why |
|---|---|
| `xdg-config/gtk-3.0`, `xdg-config/gtk-4.0` | the generated `gtk.css` |
| `xdg-config/fontconfig` | the font aliases |
| `xdg-config/qt5ct`, `xdg-config/qt6ct` | the Qt colour schemes |
| `xdg-data/icons` | the generated icon and cursor themes (`vitrail-*`) |

The command is idempotent and stamped in `~/.cache/vitrail/flatpak-overrides`,
so it runs once and again only if the list changes. Overrides are per user (no
application id), so a newly installed Flatpak inherits them without anything
else to do.

```sh
flatpak override --user --show      # what is in effect
```

A Flatpak app that was already running keeps its palette until it restarts; the
override affects the next start. Qt Flatpak apps are not covered: they bring
their own Qt runtime and platform theme, and the sandbox does not see
`environment.d`.

## Firefox

Firefox reads neither GTK's CSS nor `gsettings` for its chrome. Vitrail uses the
supported user-chrome route:

1. find the default profile in `~/.mozilla/firefox/profiles.ini` (`Default=1`,
   then the `Install…` default, then the profile named `default`);
2. write `toolkit.legacyUserProfileCustomizations.stylesheets` into the
   profile's `user.js` — **not** `prefs.js`, which Firefox rewrites on exit;
   an existing `user.js` keeps every line and is backed up once as
   `user.js.before-vitrail`;
3. write `chrome/userChrome.css` with the palette as CSS custom properties
   (`--vitrail-surface`, `--vitrail-on-surface`, `--vitrail-primary`, …) and a
   few conservative rules for the tab bar, the navigation bar and the URL bar.

The stylesheet is regenerated on every palette change, so the browser follows
the wallpaper. Firefox must be **restarted** to read `user.js` the first time;
after that, a restart (not a reinstall) picks up the new colours.

If Firefox has never run there is no profile and no `profiles.ini`: Vitrail logs
`no Firefox profile yet`, writes nothing, and the next `theme apply` after the
first launch sets it up.

## libadwaita and GTK 4

Nothing extra is needed: GTK 4 and libadwaita read `gsettings`
(`color-scheme`, `icon-theme`) and the generated `gtk-4.0/gtk.css`, both written
by `vitrail/system_theme.py` and by the Fonts page (icon theme). A Flatpak
libadwaita app picks them up through the overrides above.

## Verify

```sh
# the overrides
flatpak override --user --show | grep -E 'gtk-3.0|icons'

# Firefox
grep legacyUserProfileCustomizations ~/.mozilla/firefox/*/user.js
head -12 ~/.mozilla/firefox/*/chrome/userChrome.css
```

Then change the wallpaper and check that a Flatpak app started afterwards and a
restarted Firefox follow the new colours.

## Limits

- A running Flatpak app or Firefox keeps its colours until restarted; nothing
  reloads another process's stylesheet.
- Qt Flatpak apps are out of scope (own runtime, no `environment.d`).
- Firefox's user-chrome selectors are the browser's, not ours; a Firefox
  redesign can leave a rule inert without breaking anything.
