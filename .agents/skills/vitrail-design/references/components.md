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

## VitrailSlider (`kit`)

Material 3 expressive: thick track split by a 4 px vertical handle with a
gap each side (`tokens.slider`: `sm 8 / md 16 / lg 28`, `handle`, `gap`).

- `size` or `thickness` (px) sets the track; the handle is track + 4 × gap
  tall and halves its width while pressed.
- `segments: [{ to: 0.8, color }, { to: 1, color }]` colours by level
  (fractions of the range): filled piece full colour, empty piece 28 %.
  Example: brightness, primary to 80 %, `error` after.
- End stop dot hollow by default (`stopFilled` fills it); hidden once the
  fill reaches it or when `endIcon` is set.
- `icon` sits inside the fill (on `accentForeground`), or just past the
  handle while the fill is too short; `endIcon` at the far end.
- `readOnly`: no handle, but the gap between filled and empty stays.
- Outer ends are pills, ends at the handle nearly square (per-corner radii).

## VitrailButton (`kit/base`)

`variant` = emphasis, `tone` = colour family (`primary`, `secondary` =
inverse neutral, `info` = tertiary, `error`), `size` sm / md / lg. Icon-only
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

## Selection indicators

`VitrailSegmented` (pill) and `VitrailTabs` (underline) draw ONE indicator
bound to `repeater.itemAt(currentIndex)` geometry and animate x / width
(`base`); `settled` skips the animation on first layout. Reuse that pattern
for any single-choice control (the settings rail does the same).

## Settings window (shell/main.qml)

Frameless, floated + centred by the Hyprland rule `vitrail-float` (class
`org.qt-project.qml`, title contains "Vitrail"). Title centred, `plain`
close. `VitrailSidebar`: collapse toggle, `tonal` lg "Config file" action,
items grouped (`group` key → `groups` labels: look / desktop / system),
sliding pill, icons fill when active. Content sits in a `surfaceHigh` card.
Pages: `Flickable` → `Section { icon; title }` → `VitrailSettingRow { icon;
label; description; <control> }`; sliders full width inside a Section. Tabs
only when a page would not fit (WindowsPage).

## Popup content (bar/network/NetworkPanel.qml)

- Status header: glyph on a tinted disc (`size("display")`), `subtitle`
  title, `content` status line, optional primary pill badge (VPN on).
- `Entry` rows: fixed-width glyph slot (glyph widths vary), title + `label`
  detail, a `VitrailButton` (`tonal` to connect, `glass` on the active row).
  Active row tinted primary 0.14; others foreground 0.06 on hover.
- Long lists go in a `Scroller` capped at about 8 rows.
- State icons: Wi-Fi `signal_wifi_0_bar` → `network_wifi_{1,2,3}_bar` →
  `signal_wifi_4_bar`, offline `signal_wifi_off`, ethernet `lan`, VPN
  `shield_lock` (filled) / `shield`, bar VPN `vpn_lock`.
- When NetworkManager lists no devices, `Networking.connectivity` (Full)
  still marks the system online.
