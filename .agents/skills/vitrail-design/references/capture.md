# Capture overlay (bar/capture)

The selection is two rects per surface:

- `root.selection` (layout coords) is the exact data: hit-testing
  (`handleAt` / `cursorFor`), the size label, `confirmed`. It never lags.
- `surface.shown` (surface coords) is the drawn area: its four edges
  (`mass.el/et/er/eb`) are springs (`capture.liquid` spring, damping, mass,
  epsilon) toward `surface.local`. Veil, border, grips and the toolbar seat
  read it.
- The springs are integrated by hand: one `FrameAnimation` (`pulse`) calls
  `Capture.springStep` for the four edges once per frame and runs only while
  one of them moves. Never use `Behavior` + `SpringAnimation` per edge: a real
  mouse sends hundreds of events a second, each restarts the animation before
  it advances, and the drawn area only catches up when the pointer stops.
  `springStep` is the closed-form solution (frame-rate independent, dt clamped,
  velocity kept when the target moves).

## Motion

- Each edge is its own spring, so a dragged edge overshoots once and rests
  (about 0.1-0.15 s) while the opposite edge stays put. While dragging, the
  drawn edge trails the exact one by about 19 ms x the pointer's speed (half of
  it is the frame quantization): 6 px at 300 px/s, 19 px at 1000 px/s. Solid surface: damping 1
  (critically damped) and no bow or swell. `captureAnimation` off: `mass` equals
  the exact rect at once, radius 0.
- The outline is `Capture.outline(shown, Capture.edgeBows(exact, shown), radius)`:
  a rounded rect whose sides bow by `bow` x the px that edge still has to travel
  (outward when growing ahead, a dent on the trailing side), capped by `bowMax`
  and a fifth of the shorter side so it never self-intersects. The corner radius
  is `Capture.softRadius`: `rest` + `swell` x the widest strain. Both settle on
  their own as the springs rest; there is no velocity state. Grips sit on the
  bowed outline (`Capture.grips`).
- The neck and the birth drop run on a `VitrailLiquid` timeline of
  `capture.liquid.glide` ms (`openMs`), not the popups' 460 ms.
- Born (first `local` of a gesture): the edges start as a `capture.liquid.drop`
  circle at the press point (`root.anchor`; the pointer for a jump) and spring
  into the rect, bulging while the pointer runs ahead.
- Jumped (`root.glide`: select all, window pick): the same springs plus
  `VitrailLiquid.replay()` so `look.bond` draws the droplet's neck (`Frame.goo`)
  from a drop at the previous centre. Keyboard nudges are not jumps: no neck.

## Veil

The clear hole is a mask, not an even-odd fill: the neck and the birth drop
overlap the area, and an even-odd path paints the veil back where subpaths
overlap. The hole path is the bowed outline plus the neck. `veilFill` (layered, hidden) goes through a `MultiEffect` with
`maskInverted` and a layered `Shape` filled with `goo.path` (WindingFill).
The border strokes the bowed outline only. No fill inside the selection.

## Performance rules (measured)

Pointer handlers must stay under a millisecond: a 60 ms handler stalled every
frame (15 events in a drag, 8 frames of 50-130 ms). The cause was the colour
loupe: an `Image` with a moving `sourceClipRect` reloads, and decodes, the whole
2560x1440 PNG on every change, hidden or not. The loupe is now a
`ShaderEffectSource` over the already loaded frozen `Image` (`frozen`), so a
new crop costs nothing. Rule: never bind a moving `sourceClipRect` to the
pointer; crop a loaded image with `ShaderEffectSource.sourceRect`. After the
fix a fast drag over both 2560x1440 monitors runs at 60 fps (median 16.0 ms,
no frame over 25 ms, 0.5-1 ms per pointer event) with the mask veil, the
outline `Shape` and the grips all on, so the veil is not the cost.

## Actions that leave the overlay

- **Copy text** (`O`, `document_scanner`): `capture.read_text` composes the
  area, greys and enlarges it (`ocr_scale`), runs `tesseract --psm 6|7 -l
  <installed languages>` and copies the text with `wl-copy`; the bar shows a
  notification with `preview()` (escaped, the body is StyledText). The languages
  are `ocrLanguages`, else the system language + English, filtered by
  `tesseract --list-langs` (a wanted language that is not installed is dropped;
  none installed: English, then any).
- **Ask AI** (`I`, `auto_awesome`, preference `captureAi`): the button opens
  `CaptureAsk` (a `VitrailField` and a send button) in the toolbar's seat;
  Enter submits, Escape returns to the toolbar, a press on the screen starts a
  new area. `confirmed(..., text)` carries the question. Why this route: Google
  has no documented AI Mode upload URL, but Lens' multipart upload
  (`lens.google.com/v3/upload`, field `encoded_image`) takes the question as
  `q`, lands in a Lens search (udm=24) whose AI Overview answers it, and its
  "AI Mode" tab carries the picture and the text on (verified in Firefox,
  2026-11-19). The POST must come from the browser: the `vsrid` it returns only
  resolves with the cookie the upload set, so a URL built by Python shows a
  broken thumbnail, and `udm=50` on the upload is ignored. So `capture.ask`
  writes a private page (0600, runtime folder) that rebuilds the file from
  base64 with `DataTransfer` and submits the form, and opens it with
  `xdg-open`; `forget` deletes it after `ASK_KEEP` seconds. The clipboard +
  `udm=50` fallback was not needed.

## Detection, cards, colour and pins

- **Detection** (`captureDetect`): `onSelectionChanged` bumps `token`, clears
  `found` and closes any card; `settling` (`capture.detect` ms) then emits
  `detectRequested(selection, token)`. The shell runs one `capture detect`
  at a time (niced, one OCR thread): a newer request signals the running one
  and starts after it exits. `detected(token, result)` keeps only the current
  token (`Capture.fresh`). Copy text and Translate are `available` only with
  text; QR is `visible` only with a code. Disabled buttons keep hover (the
  `Action` uses its own `HoverHandler` and `available`, not `enabled`) so the
  tooltip says why. Detection composes into `detect.png`; actions use their own
  file names so none races another.
- **Cards** (`CaptureCard`): Translate and QR take the toolbar's seat like the
  question card; `phase` loading/done/error (not `state`: Item has one). The
  shell runs `capture translate|qr` and calls `setCard`. QR copies in Python and
  the card offers *Open* only for `is_url` (http/https), through
  `capture open`. Translate sends the text to `trans -b :<target> -i <file>`
  from a private file; `translateTarget` empty means the system language.
- **Colour** (`C`, `picking`): a 1 px `Canvas` per surface draws the frozen
  image's pixel under the pointer (`Capture.pixelAt`) and reads it back; the
  loupe is an `Image` with `sourceClipRect` (`Capture.loupeClip`) placed by
  `loupePlace`. The click calls `colorPicked(hex)` and the shell sends it to
  `useColor` (the `Super+.` history) and a toast. The canvas draws only once
  `isImageLoaded`: before that it reads black.
- **Pin** (`P`): `capture pin` copies the composed area to
  `$XDG_RUNTIME_DIR/vitrail/pins/` (outside `capture/`, which the next freeze
  empties). `PinLayer` (owned by the shell, so pins outlive the overlay) keeps a
  `ListModel` and an `Instantiator` of `PinWindow`s: a layer surface at the
  area's place on its monitor (`monitorOf`, `pinStart`), `Overlay` layer,
  `keyboardFocus: OnDemand` (Escape works after a click, never a permanent
  grab). `PinCard` reports drag, wheel and `Ctrl`+wheel; zoom keeps the point
  under the pointer fixed (`pinZoom`). `closed` is taken by the window, so the
  window's own signal is `dismissed`. The `vitrail-pin` namespace is in the
  glass layer rule. Files are deleted on close (`forget --after 0`); a bar
  restart leaves its pins' files in the tmpfs until logout.

Every number lives in `kit/tokens.js` `capture.liquid` (and `capture.ask`); geometry in
`bar/capture/capture.js` (tests `tst_capture_geometry.qml`).
