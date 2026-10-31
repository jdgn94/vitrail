import QtQuick
import QtTest
import "../../bar/launcher/engine.js" as Engine
import "../../bar/launcher/query.js" as Query
import "../../bar/launcher/actions.js" as Actions
import "../../bar/launcher/commands.js" as Commands
import "../../bar/launcher/apps.js" as Apps

// What each mode lists for a query, and the commands behind the results.
TestCase {
    name: "LauncherEngine"

    readonly property real now: 1000 * 86400000
    readonly property var enabled: ["web", "calc", "run", "files", "windows", "actions", "clipboard"]

    function app(id, name, categories, extra) {
        var base = {
            id: id, name: name, genericName: "", comment: "", icon: id, noDisplay: false,
            keywords: [], categories: categories || [], actions: [], execString: id
        }
        for (var key in (extra || {}))
            base[key] = extra[key]
        return base
    }

    function t(key) {
        return { "launcher.action.dark": "Tema oscuro", "launcher.action.light": "Tema claro",
                 "launcher.action.auto": "Tema automatico", "launcher.action.wallpaper": "Siguiente fondo",
                 "launcher.action.lock": "Bloquear", "launcher.action.session": "Menu de sesion",
                 "launcher.action.network": "Red", "launcher.action.vpn": "VPN",
                 "launcher.action.glass": "Superficie cristal", "launcher.action.solid": "Superficie solida",
                 "launcher.action.settings": "Ajustes", "nav.appearance": "Apariencia",
                 "launcher.web": "Buscar", "launcher.openUrl": "Abrir" }[key] || key
    }

    function context(extra) {
        var ctx = {
            apps: Apps.items([
                app("firefox", "Firefox", ["Network"], { genericName: "Web Browser", keywords: ["internet"] }),
                app("kitty", "kitty", ["System"], { genericName: "Terminal" }),
                app("gimp", "GIMP", ["Graphics"], { comment: "Image editor" })
            ], []),
            actions: Actions.toItems(t),
            windows: [
                { id: "0xa1", title: "Mozilla Firefox", subtitle: "firefox", fields: [{ text: "Mozilla Firefox", weight: 1 }, { text: "firefox", weight: 0.6 }] },
                { id: "0xb2", title: "~/dev", subtitle: "kitty", fields: [{ text: "~/dev", weight: 1 }, { text: "kitty", weight: 0.6 }] }
            ],
            history: {}, favourites: [], now: now, engine: "duckduckgo", bangs: Query.bangs(""),
            calc: { query: "", text: "", busy: false }, files: { query: "", items: [], busy: false },
            clips: [], t: t, home: "/home/u"
        }
        for (var key in (extra || {}))
            ctx[key] = extra[key]
        return ctx
    }

    function build(text, extra) {
        var ctx = context(extra)
        return Engine.build(Query.parse(text, { enabled: enabled, bangs: ctx.bangs }), ctx)
    }

    function ids(shown) {
        return shown.list.map(function (r) { return r.id })
    }

    function test_nothing_typed_lists_nothing() {
        compare(build("").list.length, 0)
    }

    function test_mixed_mode_finds_apps_by_name_and_keyword() {
        var shown = build("fire")
        compare(shown.list[0].group, "apps")
        compare(shown.list[0].title, "Firefox")
        compare(build("internet").list[0].title, "Firefox")
        compare(build("image").list[0].title, "GIMP")
    }

    function test_mixed_mode_adds_matching_windows_and_a_web_fallback() {
        var shown = build("firefox")
        var groups = shown.list.map(function (r) { return r.group })
        verify(groups.indexOf("apps") >= 0)
        verify(groups.indexOf("windows") >= 0)
        compare(groups[groups.length - 1], "web")
        var web = shown.list[shown.list.length - 1]
        verify(web.run.url.indexOf("duckduckgo.com") > 0)
        verify(web.run.url.indexOf("firefox") > 0)
    }

    function test_mixed_mode_finds_vitrail_actions_by_translated_name() {
        var shown = build("oscuro")
        var action = shown.list.filter(function (r) { return r.group === "actions" })[0]
        verify(action !== undefined)
        compare(action.id, "action:dark")
    }

    function test_a_url_goes_first_and_opens_directly() {
        var shown = build("github.com/a/b")
        compare(shown.list[0].group, "web")
        compare(shown.list[0].run.url, "https://github.com/a/b")
    }

    function test_math_shows_the_calculator_first() {
        var pending = build("2+2")
        compare(pending.list[0].group, "calc")
        verify(pending.list[0].busy)
        var done = build("2+2", { calc: { query: "2+2", text: "4", busy: false } })
        compare(done.list[0].title, "4")
        compare(done.list[0].run.text, "4")
        verify(!done.list[0].busy)
    }

    function test_calc_mode_waits_for_qalc() {
        var shown = build("=2^10")
        compare(shown.list.length, 1)
        verify(shown.list[0].busy)
        var done = build("=2^10", { calc: { query: "2^10", text: "1024", busy: false } })
        compare(done.list[0].title, "1024")
        compare(done.list[0].subtitle, "2^10")
        compare(build("=").list.length, 0)
    }

    function test_a_stale_calc_result_is_not_shown() {
        var shown = build("=3*3", { calc: { query: "2^10", text: "1024", busy: false } })
        verify(shown.list[0].busy)
    }

    function test_a_bang_searches_that_site() {
        var shown = build("!yt lofi beats")
        compare(shown.list.length, 1)
        compare(shown.list[0].run.url, "https://www.youtube.com/results?search_query=lofi%20beats")
    }

    function test_the_default_engine_is_configurable() {
        var shown = build("?cats", { engine: "google" })
        verify(shown.list[0].run.url.indexOf("google.com") > 0)
    }

    function test_web_mode_without_text_lists_the_bangs_to_fill_in() {
        var shown = build("?")
        compare(shown.list.length, Query.bangs("").length)
        compare(shown.list[0].run.kind, "fill")
        verify(shown.list[0].run.text.charAt(0) === "!")
    }

    function test_run_mode_has_one_row_for_the_command() {
        var shown = build(">htop -d 5")
        compare(shown.list.length, 1)
        compare(shown.list[0].run.kind, "run")
        compare(shown.list[0].run.command, "htop -d 5")
        compare(build(">").list.length, 0)
    }

    function test_files_mode_lists_what_the_search_found() {
        var found = { query: "notes", busy: false, items: ["/home/u/notes.txt", "/home/u/docs/notes.md"] }
        var shown = build("/notes", { files: found })
        compare(shown.list.length, 2)
        compare(shown.list[0].title, "notes.txt")
        compare(shown.list[0].subtitle, "~")
        compare(shown.list[1].subtitle, "~/docs")
        compare(shown.list[0].run.path, "/home/u/notes.txt")
    }

    function test_files_mode_ignores_results_of_another_query() {
        var found = { query: "old", busy: false, items: ["/home/u/old.txt"] }
        compare(build("/notes", { files: found }).list.length, 0)
    }

    function test_windows_mode_lists_all_then_filters() {
        compare(build("@").list.length, 2)
        var shown = build("@kitty")
        compare(shown.list.length, 1)
        compare(shown.list[0].run.address, "0xb2")
    }

    function test_actions_mode_lists_all_then_filters() {
        verify(build(":").list.length >= 10)
        var shown = build(":oscuro")
        compare(shown.list[0].id, "action:dark")
    }

    function test_clipboard_mode_filters_entries() {
        var clips = [{ id: "12", preview: "hello world" }, { id: "11", preview: "another thing" }]
        compare(build(";", { clips: clips }).list.length, 2)
        var shown = build(";hello", { clips: clips })
        compare(shown.list.length, 1)
        compare(shown.list[0].run.id, "12")
    }

    function test_frecency_reorders_apps() {
        var history = { kitty: { score: 9, last: now } }
        var apps = Apps.items([app("kit-a", "Kit Alpha", []), app("kitty", "Kit Beta", [])], [])
        var shown = build("kit", { apps: apps, history: history })
        compare(shown.list[0].title, "Kit Beta")
    }

    // --- actions -----------------------------------------------------------

    function test_every_action_is_complete_and_unique() {
        var seen = {}
        Actions.actions.forEach(function (action) {
            verify(action.key && action.label && action.icon && action.run && action.run.kind, action.key)
            verify(!seen[action.key], "duplicate " + action.key)
            seen[action.key] = true
        })
    }

    function test_settings_pages_are_actions() {
        var keys = Actions.actions.map(function (a) { return a.key })
        verify(keys.indexOf("settings.launcher") >= 0)
        verify(keys.indexOf("settings.appearance") >= 0)
    }

    function test_actions_cover_the_requested_ones() {
        var keys = Actions.actions.map(function (a) { return a.key })
        var wanted = ["light", "dark", "auto", "wallpaper", "lock", "session", "network", "vpn", "glass", "solid"]
        wanted.forEach(function (key) { verify(keys.indexOf(key) >= 0, key) })
    }

    function test_action_items_carry_translated_search_fields() {
        var item = Actions.toItems(t).filter(function (i) { return i.id === "action:dark" })[0]
        compare(item.title, "Tema oscuro")
        verify(item.fields.some(function (f) { return f.text === "Tema oscuro" }))
        verify(item.fields.some(function (f) { return f.text.indexOf("dark") >= 0 }))
    }

    function test_the_settings_action_names_its_page() {
        var item = Actions.toItems(t).filter(function (i) { return i.id === "action:settings.appearance" })[0]
        compare(item.title, "Ajustes: Apariencia")
        compare(item.run.category, "appearance")
    }

    // --- commands ----------------------------------------------------------

    function test_calc_uses_qalc_in_terse_mode() {
        compare(Commands.calc("2^10").join(" "), "qalc -t 2^10")
    }

    function test_an_expression_cannot_become_an_option() {
        compare(Commands.calc("-h")[2], " -h")
    }

    function test_file_search_prefers_plocate_and_falls_back_to_fd() {
        var located = Commands.files("plocate", "notes", 30, "/home/u")
        compare(located[0], "plocate")
        verify(located.indexOf("notes") > 0)
        var found = Commands.files("fd", "notes", 30, "/home/u")
        compare(found[0], "fd")
        compare(found[found.length - 1], "/home/u")
        verify(found.indexOf("30") > 0)
    }

    function test_plocate_output_is_limited_to_home_and_capped() {
        var out = "/home/u/a.txt\n/etc/a.conf\n/home/u/b.txt\n/home/user2/c.txt\n/home/u/d.txt\n"
        compare(Commands.parseFiles(out, "/home/u", 2).join(","), "/home/u/a.txt,/home/u/b.txt")
        compare(Commands.parseFiles("", "/home/u", 5).length, 0)
    }

    function test_open_commands() {
        compare(Commands.open("/home/u/a b.txt").join("|"), "xdg-open|/home/u/a b.txt")
        compare(Commands.openFolder("/home/u/a b.txt").join("|"), "xdg-open|/home/u")
        compare(Commands.openFolder("/a.txt").join("|"), "xdg-open|/")
    }

    function test_copy_uses_wl_copy_and_cannot_be_an_option() {
        compare(Commands.copy("-n").join("|"), "wl-copy|--|-n")
    }

    function test_run_in_a_terminal_or_detached() {
        compare(Commands.runInTerminal("htop").join("|"), "kitty|--hold|sh|-c|htop")
        compare(Commands.runDetached("htop").join("|"), "sh|-c|htop")
    }

    function test_clipboard_history_commands() {
        compare(Commands.clipList().join(" "), "cliphist list")
        var copy = Commands.clipCopy("42")
        compare(copy[0], "sh")
        verify(copy[2].indexOf("cliphist decode") >= 0 && copy[2].indexOf("wl-copy") > 0)
        compare(copy[copy.length - 1], "42")
        var parsed = Commands.parseClips("12\thello world\n11\tbinary data\n\nbad\n", 10)
        compare(parsed.length, 2)
        compare(parsed[0].id, "12")
        compare(parsed[0].preview, "hello world")
        compare(Commands.parseClips("1\ta\n2\tb\n3\tc\n", 2).length, 2)
    }

    function test_the_containing_folder_of_a_program() {
        var command = Commands.openProgramFolder("firefox")
        compare(command[0], "sh")
        compare(command[command.length - 1], "firefox")
    }

    function test_settings_command_uses_the_category_flag() {
        compare(Commands.settings("/h/.local/bin", "bar").join("|"), "/h/.local/bin/vitrail-settings|--category|bar")
    }

    function test_cli_commands_run_the_python_module() {
        compare(Commands.cli(["set", "appearance", "dark"]).join(" "), "python3 -m vitrail.cli set appearance dark")
    }
}
