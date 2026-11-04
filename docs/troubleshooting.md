# Troubleshooting

## First stop: the doctor

```sh
vitrail doctor            # system, config, services, display, colours
vitrail doctor --report /tmp/vitrail-report.txt
```

Safe mode starts Hyprland with a minimal config that still gives a bar, a
terminal and the settings window:

```sh
vitrail safe-mode status
vitrail safe-mode session
```

## The bar or a popup does not appear

```sh
pkill quickshell            # the bar restarts from the Hyprland config
journalctl --user -b --grep vitrail --no-pager
```

If only the settings window misbehaves, run it from a terminal
(`vitrail-settings`) and read the QML warnings.

## A setting does nothing

The window writes the INI; `vitrail-settings.path` runs
`scripts/apply-settings.sh`. Check that the unit is active and read its log:

```sh
systemctl --user status vitrail-settings.path
journalctl --user -u vitrail-settings -n 50
```

## Cursors or icons do not change

- Cursor: `hyprctl setcursor <theme> <size>` is what the compositor uses;
  `xrdb -query | grep Xcursor` covers X11. Running Qt/X11 apps may need a
  restart (`docs/cursors.md`).
- Icons: GTK and Qt read the theme at startup; windows created after the change
  use it.
- Flatpak: `flatpak override --user --show` must list the theme folders.

## A preference file is wrong

`vitrail config validate` reports unknown, misplaced or future keys. Files live
in `~/.config/vitrail/*.ini`; removing one restores the QML defaults for its
keys.

## The update refuses

`vitrail update` refuses when the checkout has local changes. Commit them,
`git stash`, or `--force` to discard. A package install is updated by the
package manager, not by git.

## Snapshots

Before moving the checkout, `vitrail update` creates a snapshot when btrfs or
timeshift is available (`vitrail snapshot list`). Restore with
`timeshift --restore` or `btrfs subvolume snapshot` in reverse; `--no-snapshot`
skips it and `--require-snapshot` refuses to update without one.
