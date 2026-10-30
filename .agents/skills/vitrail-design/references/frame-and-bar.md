# Frame and bar

- `VitrailFrame` = full-screen fill minus the content hole (`OddEvenFill`),
  plus a glass stroke along the hole. Hole outline: `Frame.holePath()`.
- Bar variants (`VitrailVariants.bar`):
  - `docked`: the bar is the thick side of the frame (`hole[edge] = bar`).
    No own surface; slot padding clears the inner corners (`border + radius`).
  - `floating`: own `VitrailSurface` island, inset `border + gap` from the
    screen edge; reserves `border + gap + bar`.
  - `islands` (docked): the frame stays `border` thick (`hole[edge] = border`)
    and rises to the full bar thickness under each slot group (start / centre /
    end, empty ones skipped) as tabs of the frame; start and end islands are
    stretched into the screen corners. `reserve[edge] = bar`, so windows keep
    clear of them. Input mask = the three islands (`bar.startMask` …), not the
    whole strip.
  - `floatingIslands`: like `floating`, but one `VitrailSurface` pill per
    group instead of one long bar.
  - `Frame.islands(groups, edge, w, h, { bar, pad, inset }, merge)` turns the
    group content rects into island rects (pad = bar style gap).
  - `layout.dock[edge]`: where docked cards (popup, notification stack) hang
    from: `hole`, or `bar` past the islands, so they rise out of an island.
- Panels (`VitrailVariants.panel`): `full` grows `hole[edge]` (attached, follows
  the frame's animated insets); `overlay` is a floating island under the bar.
- `holePath` walks each edge as a depth profile: the tabs on one edge are
  merged (max depth per interval, equal neighbours joined) so a popup rising
  out of an island, or any overlap, is one outline. Every step is rounded with
  `min(R, |b - a| / 2, half the flats on both sides)`: the corner at the
  shallower depth bends like a base fillet (sweep 1), the deeper one like a
  tab corner (sweep 0). A profile touching an end of the edge takes that
  corner.
- Insets/corner animate in `VitrailFrame` (`leftInset`…, `corner`); anything
  glued to the frame must follow those animated values.
