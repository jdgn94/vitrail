import QtQuick
import QtTest
import "../../bar/clipboard/emoji.js" as Emoji

// The emoji tab's rules: what the search keeps and how the groups count.
TestCase {
    name: "Emoji"

    readonly property var entries: [
        { e: "😀", n: "grinning face", g: "Smileys & Emotion", k: "grinning face grin happy cara feliz" },
        { e: "😢", n: "crying face", g: "Smileys & Emotion", k: "crying face sad cara triste" },
        { e: "🐶", n: "dog face", g: "Animals & Nature", k: "dog face perro cara" },
        { e: "🍕", n: "pizza", g: "Food & Drink", k: "pizza food comida" }
    ]

    function test_a_blank_search_keeps_the_group() {
        compare(Emoji.filter(entries, "", "all").length, 4)
        compare(Emoji.filter(entries, "  ", "Smileys & Emotion").length, 2)
    }

    function test_the_search_matches_english_and_spanish() {
        compare(Emoji.filter(entries, "happy", "all")[0].e, "😀")
        compare(Emoji.filter(entries, "TRISTE", "all")[0].e, "😢")
        compare(Emoji.filter(entries, "perro", "all")[0].e, "🐶")
        compare(Emoji.filter(entries, "nada", "all").length, 0)
    }

    function test_the_group_filter_narrows_the_search() {
        compare(Emoji.filter(entries, "cara", "Smileys & Emotion").length, 2)
        compare(Emoji.filter(entries, "cara", "Animals & Nature")[0].e, "🐶")
        compare(Emoji.filter(entries, "pizza", "Smileys & Emotion").length, 0)
    }

    function test_the_counts_feed_the_category_pills() {
        var counts = Emoji.counts(entries)
        compare(counts.all, 4)
        compare(counts["Smileys & Emotion"], 2)
        compare(counts["Food & Drink"], 1)
    }

    function test_the_groups_are_the_nine_unicode_ones() {
        compare(Emoji.GROUPS.length, 9)
        compare(Emoji.GROUPS[0], "Smileys & Emotion")
        compare(Emoji.GROUPS[8], "Flags")
    }
}
