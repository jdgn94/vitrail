import QtQuick
import QtTest
import "../../bar/launcher/search.js" as Search

// Fuzzy matching, frecency and the final ranking.
TestCase {
    name: "LauncherSearch"

    readonly property real day: 86400000
    readonly property real now: 1000 * day

    function item(id, name, extra) {
        var fields = [{ text: name, weight: 1 }]
        if (extra)
            fields.push({ text: extra, weight: 0.6 })
        return { id: id, name: name, fields: fields }
    }

    function test_normalize_drops_case_and_accents() {
        compare(Search.normalize("Edición  Música"), "edicion  musica")
    }

    function test_exact_beats_prefix_beats_word_beats_substring_beats_fuzzy() {
        var exact = Search.score("fire", "Fire")
        var prefix = Search.score("fire", "Firefox")
        var word = Search.score("fire", "Mozilla Firefox")
        var inside = Search.score("fire", "Backfire")
        var fuzzy = Search.score("frfx", "Firefox")
        verify(exact > prefix, "exact > prefix")
        verify(prefix > word, "prefix > word")
        verify(word > inside, "word > substring")
        verify(inside > fuzzy, "substring > fuzzy")
        verify(fuzzy > 0, "fuzzy matches")
    }

    function test_no_match_is_zero() {
        compare(Search.score("xyz", "Firefox"), 0)
        compare(Search.score("fox", "Fo"), 0)
        compare(Search.score("", "Firefox"), 0)
    }

    function test_accents_do_not_matter() {
        verify(Search.score("musica", "Música") > 0.8)
    }

    function test_every_word_of_the_query_must_match() {
        verify(Search.score("visual code", "Visual Studio Code") > 0)
        compare(Search.score("visual zzz", "Visual Studio Code"), 0)
    }

    function test_fields_take_the_best_weighted_match() {
        var fields = [{ text: "Text Editor", weight: 1 }, { text: "kate notepad", weight: 0.7 }]
        var viaKeyword = Search.scoreFields("notepad", fields)
        var viaName = Search.scoreFields("editor", fields)
        verify(viaKeyword > 0)
        verify(viaName > viaKeyword, "name outranks keyword")
        compare(Search.scoreFields("zzz", fields), 0)
    }

    function test_each_launch_adds_one_and_older_ones_fade() {
        var first = Search.bump(undefined, now)
        compare(first.score, 1)
        var week = Search.bump(first, now + 7 * day)
        // One half-life later: 1 * 0.5 + 1
        verify(Math.abs(week.score - 1.5) < 0.01)
        compare(week.last, now + 7 * day)
    }

    function test_frecency_decays_with_time_since_last_use() {
        var entry = { score: 4, last: now }
        compare(Search.frecency(entry, now), 4)
        verify(Math.abs(Search.frecency(entry, now + 7 * day) - 2) < 0.01)
        compare(Search.frecency(undefined, now), 0)
    }

    function test_old_heavy_use_loses_to_recent_light_use() {
        var old = { score: 10, last: now - 60 * day }
        var recent = { score: 2, last: now }
        verify(Search.frecency(recent, now) > Search.frecency(old, now))
    }

    function test_rank_orders_by_match() {
        var items = [item("a", "Backfire"), item("b", "Firefox"), item("c", "Fire")]
        var ranked = Search.rank(items, "fire", { history: {}, favourites: [], now: now })
        compare(ranked.map(function (r) { return r.item.id }).join(""), "cba")
    }

    function test_frecency_breaks_ties_between_equal_matches() {
        var items = [item("a", "Fire One"), item("b", "Fire Two")]
        var history = { b: { score: 5, last: now } }
        var ranked = Search.rank(items, "fire", { history: history, favourites: [], now: now })
        compare(ranked[0].item.id, "b")
    }

    function test_a_favourite_is_boosted() {
        var items = [item("a", "Fire One"), item("b", "Fire Two")]
        var ranked = Search.rank(items, "fire", { history: {}, favourites: ["b"], now: now })
        compare(ranked[0].item.id, "b")
    }

    function test_usage_never_outranks_a_much_better_match() {
        var items = [item("a", "Firefox"), item("b", "Backfire")]
        var history = { b: { score: 500, last: now } }
        var ranked = Search.rank(items, "firefox", { history: history, favourites: ["b"], now: now })
        compare(ranked[0].item.id, "a")
        compare(ranked.length, 1)
    }

    function test_rank_honours_the_limit() {
        var items = [item("a", "Fire A"), item("b", "Fire B"), item("c", "Fire C")]
        compare(Search.rank(items, "fire", { history: {}, favourites: [], now: now, limit: 2 }).length, 2)
    }

    function test_recent_lists_used_items_most_frecent_first() {
        var items = [item("a", "A"), item("b", "B"), item("c", "C")]
        var history = { a: { score: 1, last: now }, c: { score: 3, last: now } }
        var recent = Search.recent(items, { history: history, now: now, limit: 5 })
        compare(recent.map(function (i) { return i.id }).join(""), "ca")
    }

    function test_recent_skips_what_the_caller_excludes() {
        var items = [item("a", "A"), item("b", "B")]
        var history = { a: { score: 1, last: now }, b: { score: 1, last: now } }
        var recent = Search.recent(items, { history: history, now: now, limit: 5, skip: ["a"] })
        compare(recent.length, 1)
        compare(recent[0].id, "b")
    }
}
