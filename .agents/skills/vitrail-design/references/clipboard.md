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
