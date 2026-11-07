// The workspaces the bar's pills draw: one entry per existing workspace, the
// app it holds (by the active window's class) and what the pointer reads.
//
// Nothing here touches a Quickshell type: the component maps
// `Hyprland.workspaces.values` to the plain objects this file takes, so the
// rules can be tested offscreen (tests/qml/tst_bar_workspaces_title.qml).
.pragma library

function text(value) {
    return String(value === undefined || value === null ? "" : value)
}

// The raw model list, whether it is an array or an ObjectModel's `values`.
function listOf(source) {
    if (Array.isArray(source))
        return source
    return source && Array.isArray(source.values) ? source.values : []
}

// The windows of one workspace, as the plain toplevels Hyprland hands out.
function windowsOf(workspace) {
    if (!workspace)
        return []
    return listOf(workspace.toplevels)
}

// The app class of a toplevel: Hyprland keeps it in the IPC object.
function classOf(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
    return text(ipc["class"] || (toplevel && toplevel["class"]))
}

function titleOf(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
    return text((toplevel && toplevel.title) || ipc.title)
}

// The window that names a workspace: the one with the focus when it has it,
// otherwise the last window, which is what Hyprland itself calls the last one.
function namedWindow(windows, activeAddress) {
    var chosen = null
    var wanted = text(activeAddress)
    for (var i = 0; i < windows.length; i++) {
        var window = windows[i]
        if (classOf(window) === "" && titleOf(window) === "")
            continue
        chosen = window
        if (wanted !== "" && text(window.address) === wanted)
            return window
    }
    return chosen
}

// One entry per workspace Hyprland knows (special workspaces have a negative
// id and cannot be dispatched by number, so they stay out of the pills).
// `focused` wins over `active`; `active` is the fallback for a model that only
// carries one of the two. `occupied` is a window count, from the toplevels or
// the workspace's own `windows`.
function collect(workspaces, activeAddress) {
    var out = []
    var list = Array.isArray(workspaces) ? workspaces : []
    for (var i = 0; i < list.length; i++) {
        var workspace = list[i]
        if (!workspace)
            continue
        var id = Number(workspace.id)
        if (!isFinite(id) || id <= 0)
            continue
        var windows = windowsOf(workspace)
        var chosen = namedWindow(windows, activeAddress)
        out.push({
            id: id,
            name: text(workspace.name) || String(id),
            label: text(workspace.name) || String(id),
            active: workspace.focused === true
                    || (workspace.focused === undefined && workspace.active === true),
            occupied: windows.length > 0 || Number(workspace.windows) > 0,
            klass: classOf(chosen),
            title: titleOf(chosen)
        })
    }
    out.sort(function (a, b) { return a.id - b.id })
    return out
}

// The key an app class and a desktop id meet on: the dock's own rule
// (bar/dock/dock.js), so a pill and the dock agree on what one app is.
function appKey(value) {
    return text(value).trim().toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
}

// The icon of the desktop entry a window class belongs to. The class, the
// entry's startup class and its name all meet on `appKey`; without a match the
// class itself is an icon name (the launcher's fallback), which the caller
// turns into a path. An empty icon name means no icon.
function iconFor(entries, klass) {
    var wanted = appKey(klass)
    if (wanted === "")
        return ""
    var list = entries || []
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (!entry)
            continue
        if (appKey(entry.id) === wanted || appKey(entry.startupClass) === wanted
                || appKey(entry.name) === wanted)
            return text(entry.icon)
    }
    return text(klass).trim().toLowerCase()
}

// What the pointer reads on a pill: the workspace, and the app it holds (or
// what a click does when it is empty).
function tooltip(entry, strings) {
    var words = strings || ({})
    var template = words["bar.widget.workspaces.tooltip"] || "Workspace %1"
    return template.replace("%1", entry ? entry.label : "")
}

function tooltipDetail(entry, strings) {
    var app = entry ? [entry.klass, entry.title].filter(function (part) {
        return part !== ""
    }).join(" · ") : ""
    if (app !== "")
        return app
    return Object.prototype.hasOwnProperty.call(strings || ({}), "bar.widget.workspaces.help")
           ? strings["bar.widget.workspaces.help"] : ""
}
