import QtQuick
import QtTest
import "../../bar/launcher/wallpapers.js" as Wallpapers
import "../../bar/launcher/query.js" as Query
import "../../bar/launcher/engine.js" as Engine
import "../../bar/launcher/commands.js" as Commands

// The wallpaper mode: the library listing, the filter over pictures and
// effects, and the rows the launcher shows.
TestCase {
    name: "LauncherWallpapers"

    readonly property var listing: "/w/images/red-fox.png\n/w/images/blue-mountain.png\n/w/videos/rain.webm\n/w/svg/waves.svg\n/w/images/notes.txt\n/w/images/red-fox.png\n"

    function t(key) {
        return {
            "wallpaper.effect.none": "Ninguno",
            "wallpaper.effect.blur": "Desenfoque",
            "wallpaper.effect.sepia": "Sepia",
            "launcher.wallpaper.effect": "Efecto para toda la pantalla",
            "launcher.wallpaper.current": "En pantalla ahora",
            "launcher.wallpaper.image": "Imagen",
            "launcher.wallpaper.video": "Vídeo",
            "launcher.wallpaper.svg": "SVG adaptativo"
        }[key] || key
    }

    function files() {
        return Wallpapers.parse(listing)
    }

    function names(found) {
        return found.map(function (file) { return file.name }).join(",")
    }

    function test_the_listing_keeps_wallpapers_only() {
        var list = files()
        compare(list.length, 4)
        compare(names(list), "blue-mountain.png,rain.webm,red-fox.png,waves.svg")
    }

    function test_each_picture_knows_its_kind() {
        var kinds = {}
        files().forEach(function (file) { kinds[file.name] = file.kind })
        compare(kinds["red-fox.png"], "image")
        compare(kinds["rain.webm"], "video")
        compare(kinds["waves.svg"], "svg")
    }

    function test_the_filter_matches_a_name() {
        var found = Wallpapers.filter(files(), "mountain", t)
        compare(names(found.wallpapers), "blue-mountain.png")
        compare(found.effects.length, 0)
    }

    function test_the_filter_matches_an_effect_by_key_or_name() {
        compare(Wallpapers.filter(files(), "blur", t).effects.join(","), "blur")
        compare(Wallpapers.filter(files(), "desenfoque", t).effects.join(","), "blur")
        compare(Wallpapers.filter(files(), "sepi", t).effects.join(","), "sepia")
    }

    function test_the_filter_is_case_insensitive_and_ignores_spaces() {
        compare(names(Wallpapers.filter(files(), "  RED  ", t).wallpapers), "red-fox.png")
    }

    function test_nothing_typed_lists_everything() {
        var found = Wallpapers.filter(files(), "", t)
        compare(found.wallpapers.length, 4)
        compare(found.effects.length, 18)
    }

    function test_an_unknown_query_lists_nothing() {
        var found = Wallpapers.filter(files(), "zzz", t)
        compare(found.wallpapers.length, 0)
        compare(found.effects.length, 0)
    }

    // --- the mode ----------------------------------------------------------
    function build(text, extra) {
        var ctx = {
            wallpapers: { items: files(), busy: false },
            wallpaperEffect: "none", wallpaperCurrent: "/w/images/red-fox.png", t: t
        }
        for (var key in (extra || {}))
            ctx[key] = extra[key]
        return Engine.build(Query.parse(text, { enabled: Query.MODES, bangs: Query.bangs("") }), ctx)
    }

    function test_the_mode_is_a_word_prefix() {
        var parsed = Query.parse("wallpaper: blur", { enabled: Query.MODES })
        compare(parsed.mode, "wallpaper")
        compare(parsed.text, "blur")
        compare(Query.PREFIXES.wallpaper, "wallpaper:")
    }

    function test_the_mode_can_be_switched_to_and_away_from() {
        compare(Query.withMode("blur", "wallpaper"), "wallpaper:blur")
        compare(Query.withMode("wallpaper:blur", "all"), "blur")
        compare(Query.cycle("wallpaper:", Query.MODES, 1), "")
        compare(Query.cycle("wallpaper:", Query.MODES, -1), ";")
    }

    function test_a_disabled_wallpaper_mode_is_plain_text() {
        var parsed = Query.parse("wallpaper: blur", { enabled: ["web"] })
        compare(parsed.mode, "all")
        compare(parsed.text, "wallpaper: blur")
    }

    function test_the_mode_lists_the_effects_then_the_pictures() {
        var shown = build("wallpaper:")
        var groups = shown.list.map(function (result) { return result.group })
        compare(groups[0], "effect")
        compare(groups[groups.length - 1], "wallpaper")
        compare(shown.list.filter(function (r) { return r.group === "wallpaper" }).length, 4)
    }

    function test_an_effect_row_applies_it_to_the_whole_screen() {
        var shown = build("wallpaper:blur")
        compare(shown.list.length, 1)
        compare(shown.list[0].id, "effect:blur")
        compare(shown.list[0].run.kind, "effect")
        compare(shown.list[0].run.effect, "blur")
        compare(shown.list[0].title, "Desenfoque")
        compare(shown.list[0].subtitle, "Efecto para toda la pantalla")
    }

    function test_the_current_effect_is_marked() {
        var shown = build("wallpaper:", { wallpaperEffect: "sepia" })
        var sepia = shown.list.filter(function (r) { return r.id === "effect:sepia" })[0]
        compare(sepia.icon, "check")
    }

    function test_a_picture_row_carries_its_thumbnail_and_pick() {
        var shown = build("wallpaper:red")
        compare(shown.list.length, 1)
        var row = shown.list[0]
        compare(row.group, "wallpaper")
        compare(row.title, "red-fox.png")
        compare(row.thumbnail, "/w/images/red-fox.png")
        compare(row.subtitle, "En pantalla ahora")
        compare(row.run.kind, "wallpaper")
        compare(row.run.path, "/w/images/red-fox.png")
    }

    function test_a_video_has_no_thumbnail_and_says_what_it_is() {
        var row = build("wallpaper:rain").list[0]
        compare(row.thumbnail, "")
        compare(row.subtitle, "Vídeo")
    }

    function test_the_listing_command_reads_the_library_folder() {
        var command = Commands.wallpapers("/home/u/.config/vitrail/wallpapers")
        compare(command[0], "find")
        verify(command.indexOf("/home/u/.config/vitrail/wallpapers") > 0)
    }
}
