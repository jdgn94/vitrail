# Screenshot editor (`bar/capture/Editor*.qml`)

`A` in the capture overlay opens the area in the editor; swappy is gone.

## Flow

`capture edit --geometry` composes the area into a private
`$XDG_RUNTIME_DIR/vitrail/edits/edit-<ms>.png` (`{"image","w","h"}`); the shell
(`captureEdited`) hands it to `EditorLayer` (owned by the shell, like `PinLayer`: an
`Instantiator` of `EditorWindow`s). Save / Copy render the scene to
`<image>-final.png`, then `capture finish <final> --save|--copy` copies it into
`captureDir` (or the clipboard) and deletes it; `finish` only takes files of `edits/`.
The layer's `drop` runs `forget` on both files. The shell notifies `saved` /
`copied` and the two failures; a failed save keeps the window open.

## Pieces

- `editor.js` (pure, `tests/qml/tst_editor.qml`): options and what is remembered
  (`options` sanitizes saved JSON field by field), element constructors, pen path,
  arrow geometry, history (`commit` / `undo` / `redo`, never in place), fit / zoom /
  window size, `shortcut`. Elements are plain data in **picture pixels**, with
  everything resolved (the highlighter is a wide, translucent pen element).
- `EditorCard` holds the state and reports (`rendered`, `renderFailed`,
  `discarded`); no Quickshell import, so `tst_editor_card.qml` drives it with the
  pointer and keys. `EditorWindow` is the thin layer surface around it.
- `EditorCanvas`: the picture fitted on a backdrop (`Flickable` > `frame` > scaled
  item > `scene`). **`scene` is never scaled**; its parent is. `render` does
  `scene.grabToImage(cb, Qt.size(w, h))`, so the export is the shown picture at
  native size: a grab is `size x window.devicePixelRatio` pixels, so the size
  asked is the picture's divided by the ratio (exact on whole scales), and
  `finish --size WxH` resizes a render a pixel off (1.5x) to the area's own pixels.
  Elements are `EditorElement`s (`Shape`, `CurveRenderer`; an ellipse is
  a `PathAngleArc`, not a rounded rectangle). A label is typed in a `TextEdit` over
  a bare `EditorElement` (background only).
- `EditorOptions`: a `StackLayout` of one row per tool, so the bar is as tall as the
  tallest and the window does not jump on a tool change. `EditorSwatches`: six
  swatches from `capture.editor.color.swatches` (annotation colours are the same on
  any wallpaper, so they are not palette roles), a custom seventh from
  `EditorColorDialog` (the kit's `VitrailColorPicker`: wheel, tone slider and hex
  field; see `components.md`).
- `EditorDialog`: modal inside the card (scrim, glass surface, Cancel / accept,
  Esc / Enter), used for the discard confirmation and the colour. Not a `Popup`.

## Rules

- A `PanelWindow` (namespace `vitrail-editor`, in both glass layer rules), not a
  `FloatingWindow`: only layers are blurred (windows have no class of their own to
  float and centre), and an unanchored layer with `ExclusionMode.Ignore` is centred
  on its output. `keyboardFocus: Exclusive`, `Overlay` layer.
- The window is sized from the picture between `capture.editor.window` and its
  `share` of the screen (`windowSize`, `chrome` = the card's own height without the
  canvas); the pixel ratio makes "100%" mean one picture pixel per monitor pixel.
- Every size and colour is in `kit/tokens.js` `capture.editor`.
- Tooltips: `EditorAction` places them above the button; give `align: "start"` /
  `"end"` to a button at the window's edge so the pill is not cut. The header ✕ has
  none (it would leave the window).
- Slider widths: `Layout.preferredWidth` **and** `Layout.maximumWidth`; a
  `VitrailSlider` in a `RowLayout` otherwise grows to fill.
- A `FocusScope` remembers its focus child: after a dialog closes, focus the canvas
  (`canvas.forceActiveFocus()`), not the card, or the hidden dialog keeps the keys.
- Keys: `Editor.shortcut(key, modifiers, typing)`; while a label is typed only
  `Ctrl+S` still acts, the text keeps its own keys. Tool letters are P T F A.
- A JS function named `export` fails to load: the card's is `deliver`.

## Looking at it

Offscreen, without a compositor: a throwaway `Window` that imports
`bar/kit` (the same singleton the editor imports; `kit/` is a different one and
stays unconfigured), configures `VitrailTokens` and holds an `EditorCard`; call
`commit(Editor.penElement(...))` for marks, `deliver("save")` for the export and
`contentItem.grabToImage` for the picture. Layer behaviour (centring, blur, focus)
needs the real session: `docs/manual-checks.md`.
