# App icon packs

One directory per pack: `assets/icons/<pack>/` is a complete icon theme with
`index.theme` (`[Icon Theme]`) and at least one icon file (`.svg`, `.png`,
`.xpm`, `.jpg`, `.webp`) inside a size folder such as `48x48/apps/`.

`install.sh --assets=icons` validates every pack and copies it to
`~/.local/share/icons/<pack>`, where the settings window lists it as a normal
app icon pack and builds the palette-adaptive `vitrail-icons-<pack>` layer from
it. An existing theme of the same name is moved to `.vitrail-backups/` first;
system themes under `/usr/share/icons` are never touched.

## Licence

Bundling a pack requires a licence that permits redistribution and is
compatible with Vitrail's GPL-3.0-only. Put the pack's licence and attribution
next to its `index.theme`; do not add a personal-use-only pack to this
repository. See [`docs/assets.md`](../../docs/assets.md).
