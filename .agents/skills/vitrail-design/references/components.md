# Kit primitives and content patterns

## Type and icons (Material)

- Text: `tokens.font.family` = Roboto (`VitrailTokens.fontFamily`). Every raw
  `Text`/`TextInput` in kit, bar and settings sets it; `VitrailText` does it
  from the variant.
- Icons: Material Symbols Rounded (`VitrailTokens.iconFamily`), written as
  ligature names (`text: "wifi"`), never code points. `VitrailText`
  `variant: "icon"` + `filled: true` sets the FILL axis (active states).
- New icon name? Check it renders as one glyph: `TextMetrics.advanceWidth`
  under ~1.25 × pixelSize (see SKILL.md verification).

## Fills on glass are opaque

Popups are blurred layers (`vitrail-glass`). A translucent final colour
(`Qt.alpha(x, 0.14)`, `Qt.rgba(..., a)`, `opacity:` on a filled Rectangle)
drawn over the translucent card smears into a dark, soft inner edge.

- Use `VitrailTokens.solid(role | colour, amount, base)`: the colour
  pre-composited over `base` (default: the card's `surface`), alpha 1. Animate
  with `ColorAnimation`, never `opacity`.
- A shape that must vanish at rest is hidden with `visible`, not drawn at
  amount 0 (that is an opaque patch of card colour over the glass).
- A translucent tint over an already opaque parent (a highlight inside the
  `surfaceHigh` list) is fine; text colours with alpha are fine.
- Bar button highlights (opened / hovered / now playing) are the same: the bar
  is glass too, so `solid(role, amount)` over `surface`, shown with `visible`.
- The sunk look (`inset` button variant) only when the user asks for it.

## VitrailSlider (`kit`)

Material 3 expressive: thick track split by a 4 px vertical handle with a
gap each side (`tokens.slider`: `sm 8 / md 16 / lg 28`, `handle`, `gap`).

- `size` or `thickness` (px) sets the track; the handle is track + 4 × gap
  tall and halves its width while pressed.
- `segments: [{ to: 0.8, color }, { to: 1, color }]` colours by level
  (fractions of the range): filled piece full colour, empty piece 28 % (both
  opaque, `VitrailTokens.solid`).
  Example: brightness, primary to 80 %, `error` after.
- End stop dot hollow by default (`stopFilled` fills it); hidden once the
  fill reaches it or when `endIcon` is set.
- `icon` sits inside the fill (on `accentForeground`), or just past the
  handle while the fill is too short; `endIcon` at the far end.
- `readOnly`: no handle, but the gap between filled and empty stays.
- `orientation: Qt.Vertical` stands it up (minimum at the bottom, `length` px
  tall by default); `pressed` says the pointer holds the handle. The slider is
  drawn along x and the whole thing turned a quarter, so input follows.
- `wheelStep` (0 = off, so sliders in scrolling pages keep scrolling): value
  units per wheel notch, up / right more. `kit/wheel.js` accumulates notches
  (120 angle units, or touchpad pixels) into whole `stepSize` steps clamped to
  from / to and emits `moved`; the owner follows it like a drag.
  Under Wayland the wheel arrives as a TouchPad device, and a `WheelHandler`
  accepts only Mouse by default: set `acceptedDevices: Mouse | TouchPad` on any
  new one. QtTest's `mouseWheel` sends a mouse, so it cannot catch this; only a
  real wheel over a real layer-shell surface does.
- `fillOpacity` (0..1) dims the fill as an opaque pre-tinted colour; 0 hides it.
- Outer ends are pills, ends at the handle nearly square (per-corner radii).

## VitrailButton (`kit/base`)

`variant` = emphasis, `tone` = colour family (`primary`, `secondary` =
inverse neutral, `info` = tertiary, `error`), `size` sm / md / lg / xl (xl: display-size icon, the session menu's round actions). Icon-only
buttons are circles; `enabled: false` fades to 45 %.

| variant  | look                               | use it for                              |
|----------|------------------------------------|-----------------------------------------|
| elevated | solid, shadow rises on hover       | the one CTA floating over busy content  |
| flat     | solid, no shadow (default)         | main action of a card, dialog, row      |
| inset    | solid, sunk (top shadow)           | a toggle that is on, a chosen option    |
| tonal    | 22 % tint, ink in the tone         | secondary actions beside a flat one     |
| outlined | border only                        | alternatives, cancel, "open folder"     |
| text     | no fill, tinted hover              | low emphasis in content and menus (⋮)   |
| plain    | no fill, no hover tint, opacity    | toolbar / window icons (close, menu)    |

Elevation uses `RectangularShadow` (a `MultiEffect` layer blanks the fill).

## VitrailField (`kit/base`)

One text field everywhere (dialogs, toast reply, lock/login). `variant`
outline (label floats into a notch of an animated `Shape` outline from
`shapes.outlinePath`) or filled (fill, label rides inside, bottom indicator
grows from the centre); `size` sm / md / lg; `label`, `placeholder`,
`leadingIcon`, `supportingText`, `error` + `errorText`, `shake()` on a new
error, `forceActiveFocus()` (it is a FocusScope).

`type: "password"` draws one random shape per character from `Shapes.distinct` (circle, square, triangle, clover4, flower, burst: the ones that stay distinct at text size; `VitrailBusy` uses all `names`) (`shapes.js`,
`VitrailShape`) over the real TextInput, which stays invisible but keeps the
text, cursor and selection. `sync()` on `textChanged`: growth inserts at
`cursorPosition - added`, shrinking removes at `cursorPosition`, so paste and
select-all-delete work. Pop in is scale 0 to 1 `OutBack` plus rotation
-45 to 0; leaving ones shrink out. The eye (`plain` button) cross-fades shapes
and text and keeps the focus.

## VitrailBusy (`kit/base`)

Loading indicator: a shape from `shapes.js` that turns and morphs into
another random one every `motion.cycle`, outgoing shrinks out, incoming pops in
(`OutBack`). `running`, `size`, `color`, `contained` (tinted disc). It fades
out and stops its timers when not running. `VitrailButton { busy }` swaps the
icon (or starts the label) with it and ignores clicks; use it for anything that
waits (polkit check, connecting).

## Selection indicators

`VitrailSegmented` options are `{ key, label, icon }`: the optional `icon`
(Material Symbol) sits before the label in the label's colour and fills when
chosen; an empty label makes the segment icon-only. Every segmented control in
the settings pages carries icons (theme `light_mode` / `dark_mode` / `contrast`,
alignment `align_horizontal_*` / `vertical_align_*`, bar edge `*_panel_open`…).
Icon tables written as `icons: ({ … })` are checked by `tests/test_icons.py`.

`VitrailSegmented` (pill) and `VitrailTabs` (underline) draw ONE indicator
bound to `repeater.itemAt(currentIndex)` geometry and animate x / width
(`base`); `settled` skips the animation on first layout. Reuse that pattern
for any single-choice control (the settings rail does the same).

## Settings window (shell/main.qml)

Frameless, floated + centred by the Hyprland rule `vitrail-float` (class
`org.qt-project.qml`, title contains "Vitrail"). Title centred, `plain`
close. `VitrailSidebar`: collapse toggle, items grouped (`group` key → `groups` labels: look / desktop / system),
sliding pill, icons fill when active. Content sits in a `surfaceHigh` card.
Categories: appearance, wallpaper, colors, design | bar, windows, terminal |
input, language, datetime, connection, plugins. Pages: `Flickable` → `Section { icon; title }` → `VitrailSettingRow { icon;
label; description; <control> }`; sliders full width inside a Section. A page with
more than one topic splits them into `VitrailTabs` subcategories
(`property string tab`, sections `visible: page.tab === key`, scroll reset
on tab change); single-topic pages (Colors, Language, Plugins) have none.

## Pages that act on the system (ConnectionPage)

`qml6` cannot run commands, so a page that changes the system asks and reads
through files:

- Read: `bin/vitrail-settings` injects a JSON state as an argument
  (`--network`, from `vitrail/network.py`); `main.qml` parses it with
  `Args.json` and passes it down.
- Ask: the page writes a request string and raises an integer counter in an
  ini (`connectionRequest` / `connectionSeq`, area `connection`);
  `apply-settings.sh` acts once per counter value.
- Answer: the tool rewrites a JSON file in the config folder (`updated` in
  ms); while a request waits the page polls it with `XMLHttpRequest`
  (`QML_XHR_ALLOW_FILE_READ=1`, timers `motion.poll` / `motion.patience`) and
  shows whichever copy has the larger `updated`.
- While a request is in flight every action control is disabled and the one
  that asked shows `VitrailButton { busy }`; the refresh button asks `refresh`.
- Rows are `VitrailSettingRow` (state icon, name, `a · b · c` description) with
  a `tonal` `VitrailButton` (`secondary` tone when it undoes: Disconnect);
  radios are a `VitrailSwitch` row. Tabs are a `VitrailSegmented` with icons
  (one keyboard stop, Left / Right), then every control is Tab-reachable.
  A missing tool shows a one-line `content` text instead of its rows.

## Popup content (bar/network/NetworkPanel.qml, VpnPanel.qml)

Internet and VPN are separate bar buttons and popouts (`network`, `vpn`); they
share `Entry.qml` and `Scroller.qml`, and `network.js` / `vpn.js` hold the
pure helpers (tested in `tst_network.qml`, `tst_vpn.qml`).

- Status header: glyph on a tinted disc (`size("display")`), `subtitle`
  title, `content` status line, optional primary pill badge (the VPN panel
  shows the provider of the tunnel that is up).
- `Entry` rows: fixed-width glyph slot (glyph widths vary), title + `label`
  detail, a `VitrailButton` (`tonal` to connect, `glass` on the active row).
  Active row tinted primary 0.14; others foreground 0.06 on hover (opaque
  `VitrailTokens.solid` fills, shown only while active or hovered).
- Long lists go in a `Scroller` capped at about 8 rows.
- State icons: Wi-Fi `signal_wifi_0_bar` → `network_wifi_{1,2,3}_bar` →
  `signal_wifi_4_bar`, offline `signal_wifi_off`, ethernet `lan`, VPN
  `shield_lock` (filled) / `shield`, also on the bar's VPN button.
- When NetworkManager lists no devices, `Networking.connectivity` (Full)
  still marks the system online.
