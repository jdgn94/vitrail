import QtQuick
import QtTest
import "../../bar/launcher/query.js" as Query

// Prefix modes, bangs, URLs and the user's own bangs.
TestCase {
    name: "LauncherQuery"

    readonly property var all: ["web", "calc", "run", "files", "windows", "actions", "clipboard"]

    function parse(text, enabled) {
        return Query.parse(text, { enabled: enabled || all, bangs: Query.bangs("") })
    }

    function test_plain_text_is_the_mixed_mode() {
        var parsed = parse("firefox")
        compare(parsed.mode, "all")
        compare(parsed.text, "firefox")
    }

    function test_each_prefix_picks_its_mode_and_is_stripped() {
        var cases = { "?": "web", "=": "calc", ">": "run", "/": "files", "@": "windows", ":": "actions", ";": "clipboard" }
        for (var prefix in cases) {
            var parsed = parse(prefix + " thing")
            compare(parsed.mode, cases[prefix], prefix)
            compare(parsed.text, "thing", prefix)
        }
    }

    function test_a_prefix_without_a_space_still_counts() {
        compare(parse("=2^10").mode, "calc")
        compare(parse("=2^10").text, "2^10")
        compare(parse(":oscuro").text, "oscuro")
    }

    function test_a_disabled_mode_is_plain_text() {
        var parsed = parse("=2+2", ["web"])
        compare(parsed.mode, "all")
        compare(parsed.text, "=2+2")
    }

    function test_a_bang_is_a_web_search_with_its_own_site() {
        var parsed = parse("!yt lofi beats")
        compare(parsed.mode, "web")
        compare(parsed.text, "lofi beats")
        compare(parsed.bang.key, "yt")
        verify(parsed.bang.url.indexOf("youtube") > 0)
    }

    function test_every_builtin_bang_exists() {
        var keys = Query.bangs("").map(function (bang) { return bang.key }).sort()
        compare(keys.join(","), ["aur", "aw", "ddg", "g", "gh", "w", "yt"].join(","))
    }

    function test_an_unknown_bang_is_plain_text() {
        var parsed = parse("!zzz hello")
        compare(parsed.mode, "all")
        compare(parsed.bang, null)
    }

    function test_a_bang_alone_has_no_text() {
        var parsed = parse("!g")
        compare(parsed.mode, "web")
        compare(parsed.text, "")
        compare(parsed.bang.key, "g")
    }

    function test_user_bangs_are_added_and_override_builtins() {
        var stored = Query.serializeBangs([
            { key: "nix", name: "Nix packages", url: "https://search.nixos.org/packages?query=%s" },
            { key: "g", name: "Brave", url: "https://search.brave.com/search?q=%s" }
        ])
        var list = Query.bangs(stored)
        var byKey = {}
        list.forEach(function (bang) { byKey[bang.key] = bang })
        compare(byKey.nix.name, "Nix packages")
        compare(byKey.g.name, "Brave")
        compare(list.length, 8)
    }

    function test_user_bangs_survive_the_round_trip_with_odd_characters() {
        var bangs = [{ key: "q", name: "A, B | C * D", url: "https://x.test/?a=1&q=%s;z" }]
        var back = Query.parseBangs(Query.serializeBangs(bangs))
        compare(back.length, 1)
        compare(back[0].name, bangs[0].name)
        compare(back[0].url, bangs[0].url)
    }

    function test_garbage_user_bangs_are_ignored() {
        compare(Query.parseBangs("").length, 0)
        compare(Query.parseBangs("no-fields").length, 0)
        compare(Query.parseBangs("x*Name*").length, 0)
    }

    function test_search_url_encodes_the_text() {
        compare(Query.searchUrl("https://ex.test/?q=%s", "a b&c"), "https://ex.test/?q=a%20b%26c")
    }

    function test_the_default_engine_is_duckduckgo_and_falls_back_to_it() {
        verify(Query.engineUrl("duckduckgo").indexOf("duckduckgo.com") > 0)
        compare(Query.engineUrl("unknown"), Query.engineUrl("duckduckgo"))
        verify(Query.engineUrl("google").indexOf("google.com") > 0)
    }

    function test_tab_cycles_through_the_enabled_modes() {
        var enabled = ["web", "calc"]
        compare(Query.cycle("", enabled, 1), "?")
        compare(Query.cycle("?", enabled, 1), "=")
        compare(Query.cycle("=2+2", enabled, 1), "2+2")
        compare(Query.cycle("hello", enabled, 1), "?hello")
        compare(Query.cycle("", enabled, -1), "=")
        compare(Query.cycle("?x", enabled, -1), "x")
    }

    function test_open_mode_replaces_the_prefix() {
        compare(Query.withMode("=1+1", "windows"), "@1+1")
        compare(Query.withMode("hello", "actions"), ":hello")
        compare(Query.withMode(">ls", "all"), "ls")
    }

    function test_urls() {
        compare(Query.urlOf("https://example.com/a"), "https://example.com/a")
        compare(Query.urlOf("example.com"), "https://example.com")
        compare(Query.urlOf("www.example.org/x?y=1"), "https://www.example.org/x?y=1")
        compare(Query.urlOf("github.com/a/b"), "https://github.com/a/b")
        compare(Query.urlOf("localhost:8080"), "http://localhost:8080")
        compare(Query.urlOf("192.168.1.1"), "http://192.168.1.1")
    }

    function test_things_that_are_not_urls() {
        compare(Query.urlOf("main.py"), "")
        compare(Query.urlOf("notes.txt"), "")
        compare(Query.urlOf("hello world.com"), "")
        compare(Query.urlOf("firefox"), "")
        compare(Query.urlOf("3.14"), "")
        compare(Query.urlOf(""), "")
    }

    function test_math_detection() {
        verify(Query.looksLikeMath("2+2"))
        verify(Query.looksLikeMath("10 usd to eur"))
        verify(Query.looksLikeMath("5 km in miles"))
        verify(Query.looksLikeMath("(3+4)*2"))
        verify(Query.looksLikeMath("2^10"))
        verify(!Query.looksLikeMath("7zip"))
        verify(!Query.looksLikeMath("firefox"))
        verify(!Query.looksLikeMath("1password"))
        verify(!Query.looksLikeMath(""))
    }
}
