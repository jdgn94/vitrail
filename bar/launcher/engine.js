// What each mode lists for a query: the one place that turns what was typed,
// the apps, windows and the async searches into result rows.
//
// A result: { id, group, title, subtitle, icon (Material), appIcon (theme),
// run, busy }. `run.kind` is app, action kinds (see actions.js), web, calc,
// run, file, window, clip, wallpaper, effect or fill (put `text` in the field).
.pragma library
.import "query.js" as Query
.import "search.js" as Search
.import "results.js" as Results
.import "wallpapers.js" as Wallpapers

// Below this a match is noise in the mixed list.
var MIN_APP = 0.3
var MIN_OTHER = 0.6
// Rows of each group in the mixed list.
var MIXED_CAPS = { apps: 6, actions: 3, windows: 3 }
var MAX_CLIPS = 50

function windowItem(address, title, klass, workspace) {
    var name = title || klass
    return {
        id: address, title: name, subtitle: klass + (workspace ? " · " + workspace : ""), appIcon: String(klass).toLowerCase(),
        fields: [{ text: name, weight: 1 }, { text: klass, weight: 0.6 }]
    }
}

function homeShort(path, home) {
    return path === home ? "~" : path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path
}

function appResult(item) {
    return {
        id: "app:" + item.id, group: "apps", title: item.name, subtitle: item.genericName || item.comment,
        appIcon: item.icon, run: { kind: "app", item: item }, item: item
    }
}

function windowResult(item) {
    return {
        id: "window:" + item.id, group: "windows", title: item.title, subtitle: item.subtitle, appIcon: item.appIcon,
        icon: "web_asset", run: { kind: "window", address: item.id }
    }
}

function webResult(ctx, text, bang) {
    var name = bang ? bang.name : Query.engineName(ctx.engine)
    var template = bang ? bang.url : Query.engineUrl(ctx.engine)
    return {
        id: "web:" + (bang ? bang.key : "search"), group: "web", title: ctx.t("launcher.searchOn").replace("%1", name),
        subtitle: text, icon: "search", run: { kind: "web", url: Query.searchUrl(template, text) }
    }
}

function calcResult(ctx, text) {
    var fresh = ctx.calc.query === text
    var busy = !fresh || ctx.calc.busy
    var shown = busy ? ctx.t("launcher.calculating") : (ctx.calc.text || ctx.t("launcher.noResult"))
    return {
        id: "calc", group: "calc", title: shown, subtitle: text, icon: "calculate", busy: busy,
        run: { kind: "calc", text: busy ? "" : ctx.calc.text }
    }
}

function ranked(items, text, ctx, minimum, limit) {
    return Search.rank(items, text, { history: ctx.history, favourites: ctx.favourites, now: ctx.now })
        .filter(function (entry) { return entry.match >= minimum }).slice(0, limit || 1000)
}

function everything(items, text, ctx) {
    return text === "" ? items : ranked(items, text, ctx, 0).map(function (entry) { return entry.item })
}

// The mixed list: apps, actions, windows, then what the text itself is (a
// link, a sum) and the web fallback.
function mixed(text, ctx) {
    var out = []
    var order = Results.GROUPS
    var url = Query.urlOf(text)
    if (url) {
        out.push({ id: "web:url", group: "web", title: ctx.t("launcher.openUrl"), subtitle: url, icon: "open_in_new",
                   run: { kind: "web", url: url } })
        order = ["web"].concat(order)
    }
    if (Query.looksLikeMath(text)) {
        out.push(calcResult(ctx, text))
        order = ["calc"].concat(order)
    }
    ranked(ctx.apps, text, ctx, MIN_APP).forEach(function (entry) { out.push(appResult(entry.item)) })
    ranked(ctx.actions, text, ctx, MIN_OTHER).forEach(function (entry) { out.push(entry.item) })
    ranked(ctx.windows, text, ctx, MIN_OTHER).forEach(function (entry) { out.push(windowResult(entry.item)) })
    out.push(webResult(ctx, text, null))
    return Results.sections(out, order, MIXED_CAPS)
}

// -> { rows, list } as Results.sections. `parsed` is Query.parse's answer.
function build(parsed, ctx) {
    var text = parsed.text
    var out = []
    switch (parsed.mode) {
    case "all":
        return text === "" ? { rows: [], list: [] } : mixed(text, ctx)
    case "web":
        if (parsed.bang) {
            if (text !== "")
                out.push(webResult(ctx, text, parsed.bang))
        } else if (text === "") {
            ctx.bangs.forEach(function (bang) {
                out.push({ id: "bang:" + bang.key, group: "web", title: "!" + bang.key, subtitle: bang.name, icon: "travel_explore",
                           run: { kind: "fill", text: "!" + bang.key + " " } })
            })
        } else {
            out.push(webResult(ctx, text, null))
        }
        break
    case "calc":
        if (text !== "")
            out.push(calcResult(ctx, text))
        break
    case "run":
        if (text !== "")
            out.push({ id: "run", group: "run", title: text, subtitle: ctx.t("launcher.runHint"), icon: "terminal",
                       run: { kind: "run", command: text } })
        break
    case "files":
        if (ctx.files.query === text) {
            ctx.files.items.forEach(function (path) {
                var name = path.slice(path.lastIndexOf("/") + 1)
                var dir = path.slice(0, Math.max(path.lastIndexOf("/"), 0))
                out.push({ id: "file:" + path, group: "files", title: name, subtitle: homeShort(dir, ctx.home),
                           icon: "draft", run: { kind: "file", path: path } })
            })
        }
        break
    case "windows":
        everything(ctx.windows, text, ctx).forEach(function (item) { out.push(windowResult(item)) })
        break
    case "actions":
        everything(ctx.actions, text, ctx).forEach(function (item) { out.push(item) })
        break
    case "clipboard":
        ctx.clips.filter(function (clip) {
            return text === "" || Search.score(text, clip.preview) > 0
        }).slice(0, MAX_CLIPS).forEach(function (clip) {
            out.push({ id: "clip:" + clip.id, group: "clipboard", title: clip.preview, subtitle: "", icon: "content_paste",
                       run: { kind: "clip", id: clip.id } })
        })
        break
    case "wallpaper":
        var found = Wallpapers.filter(ctx.wallpapers ? ctx.wallpapers.items : [], text, ctx.t)
        found.effects.forEach(function (name) {
            var chosen = name === ctx.wallpaperEffect
            out.push({
                id: "effect:" + name, group: "effect", title: ctx.t("wallpaper.effect." + name),
                subtitle: ctx.t("launcher.wallpaper.effect"), icon: chosen ? "check" : "auto_awesome",
                run: { kind: "effect", effect: name }
            })
        })
        found.wallpapers.forEach(function (file) {
            var now = file.path === ctx.wallpaperCurrent
            out.push({
                id: "wallpaper:" + file.path, group: "wallpaper", title: file.name,
                subtitle: now ? ctx.t("launcher.wallpaper.current") : ctx.t("launcher.wallpaper." + file.kind),
                icon: file.kind === "video" ? "movie" : "image",
                thumbnail: file.kind === "image" ? file.path : "",
                run: { kind: "wallpaper", path: file.path }
            })
        })
        break
    }
    return Results.sections(out, Results.GROUPS, {}, true)
}
