import QtQuick
import QtTest
import "../../kit/wallpaper.js" as Transition

// The wallpaper's change animation: which effect a picture gets, and when.
TestCase {
    name: "WallpaperTransition"

    function test_none_means_no_animation() {
        var spec = Transition.spec("/pictures/a.png", "none", 1600)
        compare(spec.kind, "none")
        compare(spec.duration, 0)
    }

    function test_the_same_picture_keeps_its_animation() {
        var first = Transition.spec("/pictures/forest.png", "random", 1600)
        var second = Transition.spec("/pictures/forest.png", "random", 1600)
        compare(first.kind, second.kind)
        compare(first.duration, second.duration)
        compare(first.seed, second.seed)
        compare(first.originX, second.originX)
    }

    function test_random_reaches_both_effects() {
        var kinds = {}
        for (var index = 0; index < 40; index++)
            kinds[Transition.spec("/pictures/" + index + ".webp", "random", 1600).kind] = true
        verify(kinds["ink"])
        verify(kinds["outline"])
    }

    function test_a_video_changes_without_animation() {
        compare(Transition.spec("/pictures/loop.webm", "random", 1600).kind, "none")
        compare(Transition.spec("/pictures/loop.mp4", "ink", 1600).kind, "none")
    }

    // A fullscreen window stops the background work, but only when the switch
    // is on.
    function test_a_fullscreen_window_holds_the_wallpaper() {
        verify(Transition.hold(true, true))
        verify(!Transition.hold(true, false))
        verify(!Transition.hold(false, true))
        verify(!Transition.hold(false, false))
        // A preference the settings file never wrote reads as on.
        verify(Transition.hold(undefined, true))
    }

    function test_a_fixed_effect_is_used_as_is() {
        compare(Transition.spec("/pictures/a.png", "outline", 1600).kind, "outline")
        compare(Transition.spec("/pictures/b.png", "fade", 1600).kind, "fade")
    }

    function test_the_duration_follows_the_setting() {
        var spec = Transition.spec("/pictures/a.png", "ink", 2000)
        verify(spec.duration >= 1700 && spec.duration <= 2300)
    }

    function test_a_missing_duration_falls_back_to_the_default() {
        var spec = Transition.spec("/pictures/a.png", "ink", "")
        verify(spec.duration >= 1360 && spec.duration <= 1840)
    }

    function test_an_unknown_mode_reads_as_random() {
        var spec = Transition.spec("/pictures/a.png", "sparkle", 1600)
        verify(spec.kind === "ink" || spec.kind === "outline")
    }

    function test_the_ink_starts_inside_the_screen() {
        var spec = Transition.spec("/pictures/a.png", "ink", 1600)
        verify(spec.originX > 0.1 && spec.originX < 0.9)
        verify(spec.originY > 0.1 && spec.originY < 0.9)
        verify(spec.seed >= 0 && spec.seed < 1)
    }
}
