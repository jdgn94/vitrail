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

## Several monitors (Hyprland 0.56, measured with ydotool)

One layer surface per monitor, all `keyboardFocus: Exclusive`, `focus: true` on
every `gestures` item, and every surface handles keys (`root.key(event,
monitor)`). The toolbar, cards and size label stay as they were (toolbar on
`host`, the monitor under the pointer at open; the size label on the monitor
holding the pointer).

- **Exclusive layers gate the pointer.** While any layer surface is Exclusive,
  Hyprland routes pointer input only to the Exclusive ones. With only the host
  Exclusive, the other monitor's surface saw no enter, press or move: an area
  could only be made on the host's monitor. Hence all of them are Exclusive.
- **The keyboard goes to one surface and follows the click.** Right after open
  it landed on DP-2 whichever surface was the host; a click moves it to the
  clicked surface. So anything keyboard-driven must work from any surface:
  Escape, shortcuts and nudging do (every surface calls `root.key`), and the
  Ask AI card (`CaptureAsk`) is shown on the surface that got the `I` key
  (`root.askOn`, set by `beginAsk(monitor)`; the toolbar button passes the host,
  which a click has just given the keyboard). Toggling the others to `None`
  while asking did not hand the keyboard back to the host: typing went nowhere
  and Escape stopped working.
- **No implicit grab on layer surfaces.** Crossing into the other monitor with
  a button held makes Hyprland send the pressing surface a release (at the last
  position it knew, outside its monitor, `Capture.outside`), switch the pointer
  focus to the other surface (enter, then moves with `buttons == 0`, no press)
  and forget the button: the physical release reaches nobody (no surface event,
  no `release` bind, `hl.is_key_down` is keyboard only, socket2 has no button
  events). Polling `j/cursorpos` cannot help (no button state), and an empty
  input mask on the other surface only makes the pointer vanish.
- **So a gesture is carried over.** A release outside its own surface is not a
  release: `root.carried` keeps the gesture (create, move or resize) alive, the
  moves of any surface drive it (`area.pressed || root.carried`), and the next
  press ends it at the pointer (`press` calls `release` and returns). The area
  spans both monitors with `Capture.move/normalize/resize` clamped to the union
  bounds; `toLocalRect` gives each surface its part. The user drags over, lets
  go wherever, and clicks to place the edge.

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
frame (15 events in a drag, 8 frames of 50-130 ms). The cause was an `Image`
with a `sourceClipRect` following the pointer: it reloads, and decodes, the
whole 2560x1440 PNG on every change, hidden or not. Rule: never bind a moving
`sourceClipRect` to the pointer; crop a loaded image with
`ShaderEffectSource.sourceRect`. After the fix a fast drag over both 2560x1440
monitors runs at 60 fps (median 16.0 ms, no frame over 25 ms, 0.5-1 ms per
pointer event) with the mask veil, the outline `Shape` and the grips all on,
so the veil is not the cost.

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
- **Colour palette** (`C`, `palette` icon, preference `capturePaletteSize`,
  3-10, default 6): there is no dropper or loupe any more. `startPalette`
  puts a `palette` card (loading) in the toolbar's seat and asks the shell for
  `capture palette`; `capture.palette` composes the area into `palette.png`,
  shrinks it (`-scale 128x128>`), quantizes it to 24 colours without dither and
  counts them (`-format %c histogram:info:`), all with ImageMagick. Ranking is
  Python (`rank_palette`): by pixel share, each colour joins the nearest
  bigger one closer than 0.07 in OKLab (its pixels add up, the bigger one's
  hex stays, so every swatch is a real colour of the area), colours under 2 %
  are dropped (the first always stays), up to the size. The CLI prints
  `{"colors": [{"hex", "share"}]}`. `CaptureCard` renders `kind: "palette"` as
  a `GridLayout` (`capture.card.swatch`: columns, height, edge) of tiles; hover
  outlines in the accent and its tooltip says "Copy this colour". A click emits
  `colorChosen(hex)` and the card's copy button `colorsChosen(list)`; the shell
  closes the overlay, `rememberColors` writes the `Super+.` history in one
  write (first colour on top), `useColor` also copies the one in the chosen
  format, `captureColors` copies all as hex lines, and a toast says "Colour
  copied" / "Colours copied". Escape closes the card and keeps the area.
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

`A` opens the editor: see `editor.md`.

## Keys and notices

`Capture.shortcut(key, modifiers, mode, card)` (capture.js, tested) maps a key to an
action name and `key()` only dispatches. Letters are plain: with Ctrl, Alt or Meta
they do nothing, except `Ctrl+C` = copy (`copyCard` while a card is shown: the
palette's colours, the QR content or the translation, as the card's copy button) and
`Ctrl+S` = save. Enter confirms (records in record mode); `Ctrl+C` always copies the
picture, even in record mode. Every action tells what it did through
`shell.captureNotice(key, body)`: copy (size), save (path), pin, timer,
record start (path, from `captureRecord`'s stdout) and stop (path, from
`captureStop`: the chip and the panel stop it through `toggleRecording`), Ask AI
opening, QR / translation copy, plus colour, palette, OCR and the failures. Bodies are
StyledText: paths go through `captureEscape`. `vitrail.notify send` is one-shot and has
no action listener, so a notice carries no buttons ("Open folder" would need a
daemon). The notification toast lasts 5 s whatever the countdown, so the timer notice
can show in a picture taken 3 s later.

Every number lives in `kit/tokens.js` `capture.liquid` (and `capture.ask`); geometry in
`bar/capture/capture.js` (tests `tst_capture_geometry.qml`).
