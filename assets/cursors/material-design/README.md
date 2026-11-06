# Material Design cursor pack

**Material Design Cursor Concept** by **Jepri Creations** —
<https://www.deviantart.com/jepricreations>

The original Windows pack is kept in [`source/`](source/) exactly as it was
downloaded (`material-design-cursor-concept-free.zip`), with its `LICENSE`
(the author's Agreement) beside it. The two Xcursor themes in this repository
were converted from the pack's `light/` and `dark/` folders:

| Theme | Windows source | Contents |
|---|---|---|
| `MaterialDesign-Light` | `light/` | 17 cursors plus standard aliases |
| `MaterialDesign-Dark` | `dark/` | 17 cursors plus standard aliases |

Both are ordinary Xcursor themes (`index.theme` + `cursors/`) and can be
installed by `install.sh --assets=cursors`. Choosing one in **Settings →
Fonts → Cursor** builds the palette-adaptive `vitrail-MaterialDesign-*` layer
from it like any other pack.

## Licence and credit

The pack is redistributed under the author's Agreement, copied verbatim as
[`source/LICENSE`](source/LICENSE). In short:

- You may use the pack, modify it for personal use, publish a **heavily
  modified** version, and share or redistribute the pack **without
  remuneration**.
- You may not sell it, claim or rename it as your own, or use monetized URL
  shorteners to the author's site or files.
- The author and the cursor pack must be credited clearly, with a link to
  <https://www.deviantart.com/jepricreations>.

The generated Xcursor themes are a format conversion of the original artwork;
the credit above applies to them too.

### Agreement (verbatim)

```
AGREEMENT
By Getting this Cursor Pack you're allowed to...

Use the cursor pack in your computer or whatever device is compatible.
Modify the cursor pack for personal use.
Publish your heavily modified version of the pack.*
Share and distribute the pack of cursors without remuneration.*

You're not allowed to...

Share and distribute the pack of cursors with remuneration.
Claim (and rename) my cursor pack as your own.
Use monetized URL shorteners to my site or files.

*My cursor and myself (the author) should be credited clearly, add link to my DeviantArt Page.
https://www.deviantart.com/jepricreations
```

## Regenerating the themes

Extract the zip, then run the converter once per source folder (standard
library only):

```sh
python -m vitrail.wincursor build <extracted>/light assets/cursors/MaterialDesign-Light --name MaterialDesign-Light
python -m vitrail.wincursor build <extracted>/dark  assets/cursors/MaterialDesign-Dark  --name MaterialDesign-Dark
```

`source/` is source material, not a theme: the `.vitrail-source` marker makes
the installer skip the folder.
