# Install

## Requirements

Arch Linux or a derivative, a user account, and `sudo` for the packages. The
installer is plain bash: a fresh system needs nothing else first.

## Without cloning by hand

```sh
curl -fsSL https://raw.githubusercontent.com/jdgn94/vitrail/master/bootstrap.sh | bash
```

`bootstrap.sh` shallow-clones the repository in `~/.local/share/vitrail` (or
updates that clone) and runs the installer there. `VITRAIL_REPO` points it at a
fork or an SSH remote; `VITRAIL_HOME` changes the checkout's place.

## From a checkout

```sh
git clone https://github.com/jdgn94/vitrail.git
cd vitrail
./install.sh
```

The interactive flow picks the AUR helper, the compositor, the VPN mode and the
optional assets, shows a summary and only writes after you confirm. Non-interactive:

```sh
./install.sh --yes --compositor hyprland --aur yay --vpn split
```

Useful flags: `--dry-run` (the plan, no changes), `--skip-packages` (only link
the dotfiles), `--repair` (re-link and re-enable what is missing), `--gpu
auto|amd|nvidia|intel`, `--assets images,animated,cursors,icons|none`,
`--root DIR`, `--home DIR`.

`--assets` picks the optional content the repository carries. The interactive
installer asks with a checklist (only wallpapers checked); without the flag,
unattended runs install every wallpaper folder and no cursors or icon packs.
See [`assets.md`](assets.md) for the folders and the licence rule.

## From the AUR

```sh
yay -S vitrail          # or vitrail-git
vitrail-install         # links it into your home
```

The package installs the tree in `/usr/share/vitrail`; `vitrail-install` runs
the same installer with `--root /usr/share/vitrail`, so dotfiles, units and the
bar are still yours, not root's.

## After installing

`vitrail welcome` picks a wallpaper (and so a palette) if you have none, opens
the settings window and lists the next steps. `vitrail doctor` reports the
system, config, services, display and colours.

## Update

```sh
vitrail update --check   # installed commit, remote commit, behind or not
vitrail update           # fetch the branch, move the checkout, reinstall
```

The installer records where it installed from and its choices in
`~/.local/share/vitrail/install.json`. `vitrail update` reads it, compares the
installed commit with `origin/<branch>` and, when they differ, fetches, moves
the checkout and re-runs the installer with the same choices. Your
`~/.config/vitrail` is never touched. Local changes block the update unless you
pass `--force`; `--dry-run` shows the installer's plan.

A package install is updated by the package manager; `vitrail update` then only
re-runs the post steps and says so.

## Uninstall

```sh
./uninstall.sh            # remove the links and units, keep the settings
./uninstall.sh --purge    # also move ~/.config/vitrail* into .backup/
```

`--packages` lists the packages the manifest installed; it does not remove them.
