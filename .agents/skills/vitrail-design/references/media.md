# Media player (P1.4)

The bar's player sits beside the clock (`GridLayout` with the bar's flow, so it
stacks in a vertical bar) and opens its popout; the notification panel shows
the same `MediaPanel` as its first widget.

## Two looks (`mediaStyle` in `bar.ini`)

Each look is its own component in `bar/media/` (`DiscArt`, `CassetteArt`); the
settings tiles draw the same components, scaled, so a preview is the look.
Every number comes from `VitrailTokens.media` (`kit/tokens.js`, `media`).

- **disc** (`DiscArt`) — a vinyl record inside a ring of 36 marks. The ring is
  a function of playback state: `energy` (0 paused .. 1 playing, eased over
  `media.disc.settle`) feeds `Media.markLength` / `markOpacity`.
  - The record (`record` item, the only part that turns): a disc `disc.vinyl`
    times darker than the theme's dark tone (`ink`: surfaceHigh in dark,
    foreground in light), outlined with the light tone (`paper`) at `disc.edge`
    so it reads on a dark card, `disc.grooves` (radii in px) as transparent
    circles with a `disc.groove`-alpha light border, the label circle
    (`disc.label` px) and the spindle hole.
  - The label: `primary` fill with the cover cropped to the circle (a
    `MultiEffect` mask; `clip` does not round). With no cover (or one that has
    not loaded) it shows the `label` property (the panel's `trackLabel`, the
    same text as the button's tooltip) in a `VitrailText` (`label` variant,
    `accentForeground` ink) inside the square that fits the circle, shrunk
    (`Text.Fit`, min `disc.labelMin`) and elided; the hole is hidden then, so
    it does not sit under the text.
  - The tonearm is drawn above `record`, so it never turns: a base on the edge
    (`armAngle`, `armReach`), a thin arm and a head over the grooves
    (`headAngle`, `headReach`), in `paper` at `armTone`. Geometry is computed
    from the tokens in `DiscArt`.
  - Paused: `energy` 0, so every mark is the same round dot (`disc.dot` px,
    opacity `disc.idle`): a dotted border around the cover.
  - Playing: marks grow to `disc.longest` and bounce (`disc.bounce` ms per
    bounce, each mark offset by the golden ratio, opacity `low..1`). The ring
    never turns; only the record does (`disc.turn` ms per turn).
  - A `FrameAnimation` drives phase and angle from the frame clock: pause
    freezes the record at its angle, play resumes there. The bounce clock runs
    only while playing or while the ring is still settling.
  - Do not animate a `ShapePath` `dashOffset` for this: dashes travelling
    around a circle read as the ring turning.
- **cassette** (`CassetteArt`) — a tape built from Rectangles / two `Shape`
  polygons, 80 px wide (`media.cassette`, px of that width). Dark shell with a
  screw in each corner; light label (big "A" in `VitrailText`, three thin lines,
  a `primary` band with a thin `info` stripe along its foot); the window is a
  dark rounded rectangle holding the cover (full strength, masked to the window; with no cover the label shows the track's text in place of its three lines, `Text.Fit` down to `cassette.textMin`), a dark
  trapezoid of tape on the left thinning into a light strip, and two light reels
  with a hub and six teeth; below, a darker trapezoid base with two round holes
  and two slots. Shell and label swap with the theme (`ink` is the dark one of
  surfaceHigh / foreground, `paper` the light one); darker parts are
  `Qt.darker` by `cassette.deepen`. The reels turn in opposite directions
  (`cassette.turn` ms) on a `FrameAnimation` and freeze when paused.

Both take `cover`, `label` and the palette roles as properties (default:
`VitrailTokens`; the disc also takes `dark`, `accentForeground` and
`surfaceHigh`). The
settings window must pass its own palette: `shell/` and `bar/` reach `kit` by
different paths, so QML gives each its own `VitrailTokens` singleton and the
bar's is never configured there.

## Progress bar (both looks)

The shell's own `VitrailSlider` (size `sm`: track, filled part, handle, gap, end
stop), always visible and **seekable**: `from 0`, `to` the track length, `value`
the position, `onMoved` writes `position` on the panel and on the player. It is
`readOnly` (no handle) when there is no player, the player cannot seek or the
length is unknown. While the handle is held the 250 ms tick stands still.

- The wave is one `Canvas` over the slider, drawn from the track start to
  `bar.activeEnd` (the slider's fill end, just before the handle's gap), as thick
  as the track (`bar.track`) so it merges with it; `amplitude`, `wavelength`,
  round caps (`media.progress`).
- `energy` (0 paused .. 1 playing) eases over `progress.settle` (InOutQuad) and
  drives the wave: amplitude is `amplitude * energy` and the phase speed is
  multiplied by it, so it flattens and slows to a stop instead of freezing. The
  wave is always drawn opaque (no fade: a translucent fill over the glass
  smears). The slider's `fillOpacity` is `energy > 0 ? 0 : 1`: the straight fill
  hides the moment the wave (flat at first) takes over; the empty part, the
  handle and the end stop never change.
- It travels one wavelength per `progress.period` (5000 ms): calm, not a flicker.
  The `FrameAnimation` runs only while playing or while `energy > 0`; it repaints
  on phase, energy, width and palette changes.
- The elapsed time keeps ticking from a 250 ms timer that runs only while
  playing.

## Controls

The body is a 2-column `GridLayout` with one spacing (`unit`, `gap("md")`, the
same as the host card's padding, so the padding is even on all sides):

- row 0: the art cell (as large as the larger look, each centred in it, so
  switching looks moves nothing) | the text column (title, artist, progress,
  elapsed / total), centred against the art and filling the rest;
- row 1: the controls, spanning both columns, centred;
- row 2: the application chip, centred (its list opens over the card, above it).

- Loop (`repeat`, highlighted while on; None → Track → Playlist), shuffle
  (`shuffle`), previous, play/pause, next.
- The application is a chip under the controls: icon + gap + name + gap +
  chevron (only when more than one player runs) + padding. The name takes its
  text width up to `media.chip.nameMax`, then scrolls, so the chip hugs its
  content. The chevron opens the list of players (`shell.mprisPlayers` +
  `shell.mprisIndex`). The list is drawn **over the card, just above the chip**
  (the card never changes size); its width is its widest row plus padding (each
  row's name follows the same rule), centred on the chip and clamped to the
  card, and a name that does not fit the card scrolls. The current entry is
  shaded, a click chooses it and closes the list. The shell keeps **one entry
  per application** (Firefox and its browser integration are the same player),
  so a name never repeats. Sizes: `media.chip`; card width `media.panel`.
- The title, the artist and the application name are `VitrailMarquee`: a text
  that fits stays still, and one that does not slides left like a carousel,
  with a gap between the end and the next copy so the loop reads as two lines.

## Settings

Settings → Plugins → "Media player" shows two tiles (Disc / Cassette), each the
real look paused and scaled (`media.preview`) with its name below; the chosen
one is shaded. A tile sizes itself from its content, so nothing is clipped.
They write `prefs.mediaStyle` (`bar.ini`). The bar watches the
preference files, so the switch is live; no reload.

## Testing a panel with a fake player

`MediaPanel` only needs an object with `playbackState` (1 = playing),
`metadata`, `position`, `length`, `loopState`, `shuffle`, … Run it in a
`FloatingWindow` under `quickshell -p` with `QT_QPA_PLATFORM=offscreen`, call
`VitrailTokens.configure(palette, true, "solid")`, `grabToImage` twice a few
hundred ms apart and diff the ring's annulus: it must differ while playing and
be identical (dots, wave, reels) while paused. Wrap the panel in a rectangle
padded by `gap("md")` (the popout card's margin) and check that nothing leaves
it, with the list expanded (find the `expanded` property of the chip's column).

## MPRIS notes

- `metadata` is the raw MPRIS map: titles live in `xesam:title`, artists in
  `xesam:artist`, and browsers escape them (`&quot;`), so `media.js` decodes.
- Use the typed fields (`trackTitle`, `trackArtist`, `trackArtUrl`) in QML;
  `loopState` is `MprisLoopState` (None / Track / Playlist).
