# Optional assets

Vitrail carries a few optional assets in the repository. Nothing outside the
wallpapers is installed by default: `install.sh` asks which groups you want, and
the same choice is available without a terminal.

## Groups

| Group | Folder | Installed to |
|---|---|---|
| `images` | `assets/wallpapers/` | the wallpaper library (`vitrail wallpaper import`) |
| `animated` | `assets/animation-wallpapers/` | the wallpaper library, as videos |
| `cursors` | `assets/cursors/<pack>/` | `~/.local/share/icons/<pack>/` |
| `icons` | `assets/icons/<pack>/` | `~/.local/share/icons/<pack>/` |

Wallpapers are imported by the same code the settings window uses: they are
verified, optimized and added to `~/Pictures/Wallpapers` without replacing a
file that is already there.

## Choosing

In the interactive installer the assets come as one checklist after the VPN
question, with the size of each group:

```
[x] Wallpapers (24M)
[ ] Animated wallpapers (81M)
[ ] Cursor themes (4.1M, 2 pack(s))
[ ] App icon packs (38M, 1 pack(s))
```

Only **Wallpapers** starts checked. Without a terminal:

```sh
./install.sh --yes --assets=images,animated,cursors,icons
./install.sh --yes --assets=cursors,icons
./install.sh --yes --assets=none
```

Omitting `--assets` keeps the old behaviour for unattended runs: every
wallpaper folder, no cursors or icon packs. `--assets=none` installs no asset
at all. `--dry-run` prints the plan and copies nothing.

## Cursor and icon packs

A pack is one directory under `assets/cursors/` or `assets/icons/`, and it is a
complete theme:

```
assets/cursors/<pack>/          assets/icons/<pack>/
├── index.theme                 ├── index.theme
└── cursors/                    └── 48x48/apps/*.svg
    ├── left_ptr                    (and any other size/context folders)
    └── hand2
```

Before copying, the installer checks that `index.theme` exists and carries an
`[Icon Theme]` section, that a cursor pack has a non-empty `cursors/` folder,
and that an icon pack has at least one icon file (`.svg`, `.png`, `.xpm`,
`.jpg`, `.webp`) inside a size folder. A pack that fails is reported by name
and skipped; the rest of the install continues.

Packs are copied to the user's own `~/.local/share/icons/`, never to
`/usr/share/icons`, so a theme the system already provides is untouched. If a
theme with the same name is already installed, it is moved to
`~/.local/share/icons/.vitrail-backups/<pack>-<timestamp>` before the new one
takes its place — replacing a pack is never destructive. A pack that only
symlinks into the system themes loses the link, not the system theme.

The copied pack is an ordinary installed theme: it appears in the settings
window's **Cursor** or **App icon pack** picker, and the palette-adaptive layer
(`vitrail-<pack>` for cursors, `vitrail-icons-<pack>` for icons) is built from
it when you choose it. That is the same path as a pack imported from a zip.

### Bundled Material Design cursors

`assets/cursors/MaterialDesign-Light/` and
`assets/cursors/MaterialDesign-Dark/` are converted from the Windows pack in
`assets/cursors/material-design/source/`. The `material-design` folder itself is
source material and carries a `.vitrail-source` marker, so the installer skips
it and only installs the two complete themes. The pack, its Agreement and the
required credit to Jepri Creations are documented in
[`assets/cursors/material-design/README.md`](../assets/cursors/material-design/README.md).

## Licensing

Vitrail is GPL-3.0-only. A third-party pack may be committed under `assets/`
**only** when its licence allows redistribution and is compatible with that:
include the pack's own licence file and attribution next to its `index.theme`.
A pack that is personal-use only can be installed by hand, but it must not be
added to this repository. When in doubt, leave it out: the installer's
`cursors` and `icons` groups are empty until a pack passes that check.

The same rule applies to wallpapers and to the existing cursor designs: the
credits live in the README's licence section.
