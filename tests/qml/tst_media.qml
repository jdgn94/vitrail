import QtQuick
import QtTest
import "../../bar/media/media.js" as Media

TestCase {
    name: "Media"

    function test_clock_formats_minutes_and_hours() {
        compare(Media.clock(0), "0:00")
        compare(Media.clock(7), "0:07")
        compare(Media.clock(187), "3:07")
        compare(Media.clock(3723), "1:02:03")
    }

    function test_clock_tolerates_missing_values() {
        compare(Media.clock(undefined), "0:00")
        compare(Media.clock(-5), "0:00")
        compare(Media.clock("nope"), "0:00")
    }

    function test_label_joins_title_and_artist() {
        compare(Media.label({ title: "Song", artist: "Band" }, "Spotify"), "Song — Band")
        compare(Media.label({ title: "Song" }, "Spotify"), "Song")
        compare(Media.label({ artist: "Band" }, "Spotify"), "Band")
        compare(Media.label({}, "Spotify"), "Spotify")
        compare(Media.label(null, ""), "")
    }

    function test_html_entities_from_browsers_are_decoded() {
        compare(Media.decode("Kashita &quot;Riboba&quot;"), 'Kashita "Riboba"')
        compare(Media.decode("Rock &amp; Roll"), "Rock & Roll")
        compare(Media.decode("&lt;live&gt;"), "<live>")
        compare(Media.decode("plain"), "plain")
    }

    function test_the_glyph_follows_the_state() {
        compare(Media.glyph(true), "pause")
        compare(Media.glyph(false), "play_arrow")
        verify(Media.isPlaying(1))
        verify(Media.isPlaying("playing"))
        verify(!Media.isPlaying(0))
    }
    function test_ring_marks_are_equal_dots_when_paused() {
        for (var i = 0; i < 36; i++) {
            var beat = Media.beat(0.37, i)
            compare(Media.markLength(beat, 0, 3, 11), 3)
            compare(Media.markOpacity(beat, 0, 0.6, 0.4), 0.6)
        }
    }

    function test_ring_marks_bounce_when_playing() {
        compare(Media.markLength(1, 1, 3, 11), 11)
        compare(Media.markLength(0.5, 1, 3, 11), 7)
        compare(Media.markLength(0, 1, 3, 11), 3)
        compare(Media.markOpacity(1, 1, 0.6, 0.4), 1)
        compare(Media.markOpacity(0, 1, 0.6, 0.4), 0.4)
        // Halfway between the states it is halfway in length.
        compare(Media.markLength(1, 0.5, 3, 11), 7)
    }

    function test_beat_stays_in_range() {
        for (var i = 0; i < 36; i++) {
            var value = Media.beat(0.9, i)
            verify(value >= 0 && value <= 1)
        }
    }
}
