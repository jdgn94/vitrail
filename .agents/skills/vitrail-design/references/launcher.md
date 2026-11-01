# Application launcher

One content component (`bar/launcher/Launcher.qml`), two presentations chosen
by its `variant` (`VitrailVariants.launcher`, sizes in `tokens.launcher`):

| | popout | fullscreen |
|---|---|---|
| opens | right click on the bar button, `launcher popout` | left click, Super alone (`launcher toggle`), `launcher open <mode>` |
| host | popout kind `launcher` (the usual `popupCard`) | `LauncherScreen.qml` in a `vitrail-launcher` PanelWindow per monitor |
| look | compact card, ~640 x 560, 6 columns, 1-line names | dimmed glass/solid backdrop, centred field (`narrow`), category tabs and a big icon grid (`content` wide, 72 px icons, 2-line names), centred result list, footer hints |
| monitor | the button's, or the focused one (IPC) | the button's, or the focused one (Super / IPC) |

Both take the keyboard (`Exclusive` while open). The popout does not close
when the pointer leaves; the full-screen one closes with Escape or a click on
the backdrop, fades and scales in like the session menu, and is built fresh
on every open (`Loader` inside `LauncherScreen`). `vitrail-launcher` is in the
`vitrail-glass` layer rule (`hyprland.lua` and `apply-settings.sh`, checked by
`tests/test_design_system.py`). A new presentation is a new entry in the
variant table plus a token block; the gallery draws every entry
(`gallery/LauncherPreview.qml`, made-up apps).

## Layout (`Launcher.qml`)

- Row: `VitrailField` (search icon) + mode chip + expand button (`Ctrl+E`
  grows the card to `launcher.expand` of the screen, more columns).
- Empty query: Favourites, Recent (frecency), then `VitrailTabs` by category
  (the tab strip scrolls sideways) over the apps, as a tile grid or, with
  `launcherView=list`, as rows.
- Typing: result rows grouped by type with headers (`Results.sections`);
  `Ctrl+1..9` run the first nine. Footer: key hints.
- `→` / `Ctrl+K` / right click on an app: its menu (desktop actions, pin,
  hide, open folder), opened beside that tile or row (`Results.menuPlace`:
  right of it, top-aligned, flipped left or clamped to stay inside the list
  area; it follows the list while it scrolls). The highlighted delegate
  registers itself in `selectedItem` for the keyboard. Tiles and rows declare
  `tooltip` / `tooltipDetail`; one `VitrailTooltip` inside the launcher shows them (the bar's host places
  tooltips by bar edge, which does not fit content in a popout).
- Keys are caught in `VitrailField.keyPressed` (before the text takes
  Ctrl+E / Ctrl+K / Tab); the arrows move only when the caret is at an end.
- Escape is `Keys.onEscapePressed` on the root `FocusScope` (plus the field's
  `onEscaped`, which swallows the key otherwise), so it works whichever item
  has the focus: it closes the open menu, otherwise the launcher (a typed
  query or mode prefix does not need clearing first). Never use `Shortcut`:
  `QQuickShortcut` segfaults Quickshell on teardown (`qs kill`). The clipboard
  panel does the same.

## Logic (pure, `.pragma library`, tested in `tests/qml/tst_launcher_*.qml`)

| file | holds |
|---|---|
| `query.js` | prefixes, bangs (built in + user), Tab cycling, URL and math detection |
| `search.js` | fuzzy score, frecency (half life 7 days), ranking with favourites |
| `apps.js` | desktop entries to items, main category, tabs |
| `history.js` | state document (launches, favourites, hidden), clear requests |
| `results.js` | grouping, list and grid navigation |
| `actions.js` | `:` actions (themes, wallpaper, lock, session, popouts, settings pages) |
| `commands.js` | argument lists for every program it runs (never shell strings from text) |
| `engine.js` | what each mode lists for a query |

## Modes

`?` web (engine from `launcherEngine`, bangs `!g !ddg !yt !gh !aur !aw !w` +
`launcherBangs`), `=` `qalc -t` (async, busy row, Enter copies with
`wl-copy`), `>` command (Enter in kitty, Shift+Enter detached), `/` files
(`plocate`, else `fd` in `$HOME`; capped at `launcher.maxFiles`), `@` windows
(`Hyprland.toplevels`, `focuswindow`), `:` actions, `;` clipboard (`cliphist`).
A bare URL opens directly. Async programs go through `AsyncRun.qml` (latest
request wins, timeout `motion.timeout`).

## State and settings

- `~/.local/state/vitrail/launcher.json` (`LauncherStore.qml`, one per shell):
  atomic writes after a pause. Settings page `LauncherPage` (category
  `launcher`) keeps the preferences in launcher.ini (`launcherEngine`,
  `launcherBangs`, `launcherModes`, `launcherView`) and asks the bar to clear
  history / hidden apps with a timestamp in `launcherClear` (`<ms>` or
  `<ms>:hidden`).
- `vitrail set appearance|surfaceStyle <value>` (`vitrail/prefs.py`) is what
  the theme and surface actions run.

## Pitfalls

- A function named `escape` is illegal in QML (use `dismiss`).
- `Quickshell.iconPath(name, true)` returns "" when the theme lacks the icon;
  the fallback form renders a checkerboard.
- Quickshell hot reload can keep stale components: restart the bar before
  trusting a live test.
- `wtype -k Escape` never reaches the Qt window here (other keys do), so
  Escape was checked by calling `press` in a preview, not live.
- Tiles hold their full number of name lines so a row of tiles stays level.
