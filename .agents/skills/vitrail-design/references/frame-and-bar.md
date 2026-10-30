# Frame and bar

- `VitrailFrame` = full-screen fill minus the content hole (`OddEvenFill`),
  plus a glass stroke along the hole. Hole outline: `Frame.holePath()`.
- Bar variants (`VitrailVariants.bar`):
  - `docked`: the bar is the thick side of the frame (`hole[edge] = bar`).
    No own surface; slot padding clears the inner corners (`border + radius`).
  - `floating`: own `VitrailSurface` island, inset `border + gap` from the
    screen edge; reserves `border + gap + bar`.
- Panels (`VitrailVariants.panel`): `full` grows `hole[edge]` (attached, follows
  the frame's animated insets); `overlay` is a floating island under the bar.
- Insets/corner animate in `VitrailFrame` (`leftInset`…, `corner`); anything
  glued to the frame must follow those animated values.
