# Bar popups

Reference: macOS-like tray menu that grows out of a docked bar
(card flush with the frame edge, concave fillets into the frame, rounded
outer corners, same tint as the frame, no seam or edge line at the base).

## Docked bar → tab of the frame

- `VitrailBar.popup` (rect) + `popupOpen` → one entry of `VitrailFrame.tabs`.
  Other docked cards (the notification stack) go in `VitrailBar.tabs`.
- `Frame.holePath(w, h, hole, radius, tabs)`, tabs = `[{ edge, rect, reveal }]`
  on any edges: fillet radius `min(R, depth)`, outer corners
  `min(R, depth/2, length/2)`. Each edge is walked in a frame turned so it is
  the left side (`turn` / `unturn`); left, top, right, bottom is clockwise.
- `VitrailBar.popupReveal` animates 0→1 (`fast`): the tab grows out of the bar.
  Callers own the reveal of their own tabs.
- The popup layer draws only the content; its `VitrailSurface` is hidden.
- Placement (`bar/shell.qml`, `popupCard`): cross-axis flush at
  `hole[edge]`; along the bar `Frame.popupAlong()`: centred on the anchor;
  within `2 * radius` (hole corner + fillet) of a hole end it snaps flush.
- Corner case (reference: popup near the top of a left bar): a tab flush with
  a hole end takes that corner — no rounded hole corner there, the tab's free
  side joins the perpendicular frame edge with a concave fillet instead.

## Floating bar → island

- Own `VitrailSurface`, cross-axis at `reserve[edge] + gap(md)` (a gap past
  the bar), along the bar `Frame.popupAlong()` clamps to `hole + gap(md)` so
  it never touches the frame lines.
