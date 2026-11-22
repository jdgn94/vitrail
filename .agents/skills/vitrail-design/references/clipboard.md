# Clipboard panel (P1.3)

A card at the pointer, with three tabs over the same surface: History, Emojis
and Colours. The tabs are `VitrailTabs` (the underline slides with the base
motion, the same as the launcher's); there is no close button, the panel closes
with Escape or a click outside.

Four commands, one per entry point:

| Keys | Command | Opens |
|---|---|---|
| `Mod+.` | `vitrail-bar ipc call clipboard toggle` | the History tab |
| `Mod+Shift+.` | `... clipboard emoji` | the Emojis tab |
| `Mod+Alt+.` | `... clipboard colors` | the Colours tab |
| `Mod+Ctrl+.` | `... clipboard pick` | the screen picker alone |

- **Window:** a full-screen overlay on the focused monitor (`vitrail-clipboard`,
  Overlay layer), `mask: Region {}` so the whole screen takes the click that
  closes it; `WlrKeyboardFocus.Exclusive` while open. The card sits at the
  pointer, pulled inside the screen by `gap("md")` (`Clipboard.clamp`).
- **Card:** a `VitrailField` with the search (`clipboard.search`) and a list of
  the history, newest first. Text entries show one line of their preview;
  image entries show a thumbnail and their size.
- **Keyboard:** type to filter, Up/Down move, Escape closes. **Enter** copies
  (and pastes when `clipboardPaste` is on), **Shift+Enter** only copies,
  **Ctrl+Enter** copies without the trailing newline, for a terminal.
- **Filters:** a `VitrailSegmented` with All / Text / Images / Links
  (`Clipboard.kind`), and the counter `shown / clipboardMax`.
- **Clearing:** the ✕ of a row deletes that entry (`cliphist delete`); the
  header's `delete_sweep` empties the history (`cliphist wipe`) and takes a
  second click within three seconds, so one stray click cannot wipe it.
- **Hint:** the footer line spells the three Enter modes out.
- **Thumbnails:** `cliphist decode <id>` writes a PNG to
  `$XDG_RUNTIME_DIR/vitrail-clip-<id>.png` the first time the row is on screen;
  the shell keeps the path so it is decoded once.
- **Empty state:** the same container as the notification panel, with
  `content_paste_off` and `clipboard.empty` / `clipboard.noMatch`.
- **Picking:** `cliphist decode <id> | wl-copy`; with `clipboardPaste` on,
  `wtype -M ctrl v -m ctrl` pastes it into the focused window.
- **History size:** `clipboardMax` (50–1000, default 100) becomes
  `-max-items` in `~/.config/cliphist/config` through `vitrail clipboard apply`.

## Rich copies and the hover card

- **Store:** `vitrail/richclip.py` keeps the source's `text/html` in
  `$XDG_CACHE_HOME/vitrail/clipboard/<sha256 of the plain bytes>.html` (0600).
  The key is the text itself, so any cliphist entry finds its style however it
  got its id and however often it was copied; a copy younger than a minute is
  never pruned. The sanitizer (`richclip.sanitize`) is an allow-list of tags,
  attributes and CSS; the stored original is only ever shown sanitized.
- **Card:** `bar/clipboard/ClipboardPreview.qml`, a `VitrailSurface` with a
  `VitrailText` in `Text.RichText`; `rich.js` rewrites the CSS to what Qt draws
  (px lengths, hex colours, sizes capped by `VitrailTokens.clipboard.preview`
  and scaled so a poster still fits). Copies whose colours want a light or dark
  page sit on a patch of the theme's own light/dark tone. It shows after the
  tooltip delay, beside the panel on the side with room, and follows the arrow
  keys. Sizes live in the `clipboard.preview` tokens.
- **Re-copy:** `vitrail clipboard copy <id>` offers text and HTML at once through
  a GTK 4 helper (`wl-copy` offers one type); `Ctrl+Enter` stays plain.

## Emojis

- `assets/emoji.json` is built by `scripts/build-emoji.py` from Unicode's
  `emoji-test.txt` and CLDR's English and Spanish annotations: one row per
  emoji with its character, its Unicode group, its English name and the words
  a search should match in both languages (530 KB, 3963 emojis).
- The tab has a search, the nine groups as icons (`VitrailSegmented`) and a
  grid; a click copies the emoji and leaves the tab open, so several can be
  picked in a row.
- `bar/clipboard/emoji.js` holds the filter and the counts
  (`tests/qml/tst_emoji.qml`), and `tests/test_emoji.py` guards the asset.

## Colours

- The tab shows the format selector first (HEX, HEX8, RGB, RGBA, HSL, HSLA),
  then the current colour and its value, a "Pick from screen" button
  (`hyprpicker -f hex`) and the last ten colours.
- "Pick from screen" closes the panel first and runs the picker one frame
  later, so the grab never includes the card.
- Choosing a swatch, picking a new colour or changing the format copies the
  colour at once (`wl-copy`).
- `clipboardColors` in `misc.ini` keeps the last ten as a JSON array;
  `bar/clipboard/colors.js` does the parsing, the formatting and the list
  (`tests/qml/tst_colors.qml`).
- History rows whose text is a colour show a swatch instead of the glyph.

Rules live in `bar/clipboard/clipboard.js` (image parsing, filter, label,
clamp) and are tested in `tests/qml/tst_clipboard.qml`.

The emoji groups are a `VitrailSegmented` with ten icon-only segments: the row
scrolls sideways in the panel's width (wheel, drag) and the chosen group is
revealed. The selection pill must not scroll past the first group when the tab
opens — the control starts from width 0, so `reveal()` has to wait for a width.

## The bar's clipboard element (`bar/clipboardbar/`)

- **Button:** the history's count and the newest copy's redacted first line in
  `tooltip`, the oldest copy the popup shows in `tooltipDetail`. `active` is
  "there is at least one copy"; the element is hidden by default and starts in
  "only while active" when the user enables it.
- **Cut:** `clipboardbar.js` takes the history's entries (`cliphist list`, the
  same list `Super+V` reads), de-duplicates them like the history, drops
  colour copies (a colour is not a copy) and keeps `clipboardbarRecent`
  (1–10, default 5).
- **Popup rows:** the same `ClipboardPreview` as the hover card with
  `compact: true`: no surface of its own, `rowWidth`/`rowHeight`/`rowLines`
  from `VitrailTokens.clipboard.preview`, and a fixed row height so the list
  has a size before its delegates exist. A click copies through
  `shell.pickClip` (the history's `cliphist decode | wl-copy`), never a second
  copy path.
- **Full history:** the footer button calls `shell.openClipboard("history")`,
  exactly what `vitrail-bar ipc call clipboard toggle` runs. Do not build a
  second list.
- **Redaction:** `Clipboard.redact` in `bar/clipboard/clipboard.js` (also used
  by the history's own labels) keeps a secret's key and drops its value:
  private keys, URL credentials, bearer tokens, JWTs and `key=value` for
  password/token/secret-style keys.

## The colour picker element (`bar/colorpicker/`)

- **Button:** an eyedropper. A click runs the palette's own picker
  (`shell.pickColor` → `hyprpicker -f hex`) and copies the result the palette's
  way (`shell.useColor`); the popup is a right click, so the pick never grabs
  the bar's own card.
- **Popup:** the recent colours as a `Flow` of swatch cells (a swatch and its
  hex); a click copies one, the footer button calls
  `shell.openClipboard("color")`, which is the `Super+P`/`clipboard colors`
  path.
- **Store:** `colorpickerColors` in `bar.ini` (up to 24) beside the palette's
  `clipboardColors` in `misc.ini` (ten). `shell.useColor` writes both. The
  palette's ten were too few for `colorpickerRecent` (4–24, default 12), so
  the two bounds stay separate.
