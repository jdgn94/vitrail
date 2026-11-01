# Media player (P1.4)

The bar's player sits beside the clock (`GridLayout` with the bar's flow, so it
stacks in a vertical bar) and opens its popout; the notification panel shows
the same `MediaPanel` as its first widget.

## Two looks (`mediaStyle` in `bar.ini`)

Each look is its own component in `bar/media/` (`DiscArt`, `CassetteArt`); the
settings tiles draw the same components, scaled, so a preview is the look.
Every number comes from `VitrailTokens.media` (`kit/tokens.js`, `media`).

- **disc** (`DiscArt`) — the cover is a round record with a hole, inside a ring
  of 36 marks. The ring is a function of playback state: `energy` (0 paused ..
  1 playing, eased over `media.disc.settle`) feeds `Media.markLength` /
  `markOpacity`.
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
  dark rounded rectangle holding the cover (tinted, `cassette.cover`), a dark
  trapezoid of tape on the left thinning into a light strip, and two light reels
  with a hub and six teeth; below, a darker trapezoid base with two round holes
  and two slots. Shell and label swap with the theme (`ink` is the dark one of
  surfaceHigh / foreground, `paper` the light one); darker parts are
  `Qt.darker` by `cassette.deepen`. The reels turn in opposite directions
  (`cassette.turn` ms) on a `FrameAnimation` and freeze when paused.

Both take the palette roles as properties (default: `VitrailTokens`). The
settings window must pass its own palette: `shell/` and `bar/` reach `kit` by
different paths, so QML gives each its own `VitrailTokens` singleton and the
bar's is never configured there.

## Progress bar (both looks)

`[ wave ][ playhead ][ thin line ..... end dot ]`, laid out by
`Media.progressLayout` (pure, tested): wave 0..`waveEnd`, a vertical rounded
playhead at the played fraction, a thin line to the right, a small dot at the
right edge, each `progress.gap` apart. All sizes in `media.progress`.

- The wave is one `Canvas` over the whole bar, a sine drawn to `waveEnd`
  (`wave` px thick, round caps, `amplitude`, `wavelength`), thicker than the
  line (`line`). It repaints on width, height, `waveEnd`, phase and palette
  changes, so it is correct while paused.
- It travels one wavelength per `progress.period` (5000 ms, about 6 px/s): calm,
  not a flicker. A `FrameAnimation` advances the phase only while playing; paused
  there is no animation or timer for the bar, the wave stays where it was and
  resumes from that phase.
- The elapsed time keeps ticking from a 250 ms timer that runs only while
  playing. The bar is display-only: no seeking.

## Controls

- Loop (`repeat`, highlighted while on; None → Track → Playlist), shuffle
  (`shuffle`), previous, play/pause, next.
- The application is a chip under the controls: its icon, its name and a
  chevron that opens the list of players when more than one is running
  (`shell.mprisPlayers` + `shell.mprisIndex`). The shell keeps **one entry per
  application** (Firefox and its browser integration are the same player), so
  a name never repeats.
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
be identical (dots, wave, reels) while paused.

## MPRIS notes

- `metadata` is the raw MPRIS map: titles live in `xesam:title`, artists in
  `xesam:artist`, and browsers escape them (`&quot;`), so `media.js` decodes.
- Use the typed fields (`trackTitle`, `trackArtist`, `trackArtUrl`) in QML;
  `loopState` is `MprisLoopState` (None / Track / Playlist).
