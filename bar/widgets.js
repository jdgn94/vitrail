// The widgets every surface draws, in the order a surface lists them. One
// registry for the bar, the notification panel, the desktop and (later) the
// lock screen: a surface stores only which ids it shows, in which order, and
// the size and style of each one (bar/layouts.js).
//
// shapes:
//   { id, surfaces, labelKey, icon, sizes, styles, interactive? }
// `surfaces` names every surface that may show the widget; `labelKey` is the
// i18n key its editor row shows; `sizes` / `styles` are the values that
// widget understands (the first size is the default when "md" is absent).
// `interactive` marks a desktop widget that takes the pointer.
.pragma library

var WIDGETS = [
    // --- the bar (bar → Editor)
    { id: "launcher", surfaces: ["bar"], group: "start", labelKey: "bar.widget.launcher", icon: "apps", sizes: [], styles: [] },
    { id: "workspaces", surfaces: ["bar"], group: "start", labelKey: "bar.widget.workspaces", icon: "view_column", sizes: [], styles: [] },
    { id: "notifications", surfaces: ["bar"], group: "start", labelKey: "bar.widget.notifications", icon: "notifications", sizes: [], styles: [] },
    { id: "title", surfaces: ["bar"], group: "center", labelKey: "bar.widget.title", icon: "desktop_windows", sizes: [], styles: [] },
    { id: "media", surfaces: ["bar"], group: "center", labelKey: "bar.widget.media", icon: "play_circle", sizes: [], styles: [] },
    { id: "clock", surfaces: ["bar"], group: "center", labelKey: "bar.widget.clock", icon: "schedule", sizes: [], styles: [] },
    { id: "capture", surfaces: ["bar"], group: "end", labelKey: "bar.widget.capture", icon: "screenshot_monitor", sizes: [], styles: [] },
    { id: "recording", surfaces: ["bar"], group: "end", labelKey: "bar.widget.recording", icon: "stop_circle", sizes: [], styles: [] },
    { id: "tray", surfaces: ["bar"], group: "end", labelKey: "bar.widget.tray", icon: "widgets", sizes: [], styles: [] },
    { id: "network", surfaces: ["bar"], group: "end", labelKey: "bar.widget.network", icon: "lan", sizes: [], styles: [] },
    { id: "bluetooth", surfaces: ["bar"], group: "end", labelKey: "bar.widget.bluetooth", icon: "bluetooth", sizes: [], styles: [] },
    { id: "vpn", surfaces: ["bar"], group: "end", labelKey: "bar.widget.vpn", icon: "shield", sizes: [], styles: [] },
    { id: "profile", surfaces: ["bar"], group: "end", labelKey: "bar.widget.profile", icon: "speed", sizes: [], styles: [] },
    { id: "battery", surfaces: ["bar"], group: "end", labelKey: "bar.widget.battery", icon: "battery_full", sizes: [], styles: [] },
    { id: "keyboard", surfaces: ["bar"], group: "end", labelKey: "bar.widget.keyboard", icon: "keyboard", sizes: [], styles: [] },
    { id: "power", surfaces: ["bar"], group: "end", labelKey: "bar.widget.power", icon: "power_settings_new", sizes: [], styles: [] },

    // --- the notification panel (bar → Editor → Panel)
    { id: "media", surfaces: ["panel", "desktop"], labelKey: "panel.widget.media", icon: "play_circle", sizes: ["sm", "md", "lg"], styles: ["disc", "cassette", "minimal"], interactive: true },
    { id: "toggles", surfaces: ["panel", "desktop"], labelKey: "panel.widget.toggles", icon: "toggle_on", sizes: ["sm", "md", "lg"], styles: [], interactive: true },
    { id: "capture", surfaces: ["panel"], labelKey: "panel.widget.capture", icon: "screenshot_monitor", sizes: ["sm", "md", "lg"], styles: [], interactive: true },
    { id: "notes", surfaces: ["panel", "desktop"], labelKey: "panel.widget.notes", icon: "edit_note", sizes: ["sm", "md", "lg"], styles: ["card", "plain", "minimal"], interactive: true },
    { id: "session", surfaces: ["panel"], labelKey: "panel.widget.session", icon: "power_settings_new", sizes: ["sm", "md", "lg"], styles: [], interactive: true },

    // --- the desktop (bar → Editor → Desktop)
    { id: "clock", surfaces: ["desktop"], labelKey: "panel.widget.clock", icon: "schedule", sizes: ["sm", "md", "lg"], styles: ["full", "compact", "minimal"], interactive: false },
    { id: "weather", surfaces: ["desktop"], labelKey: "panel.widget.weather", icon: "partly_cloudy_day", sizes: ["sm", "md", "lg"], styles: ["full", "compact"], interactive: false },
    { id: "resources", surfaces: ["desktop"], labelKey: "panel.widget.resources", icon: "monitor_heart", sizes: ["sm", "md", "lg"], styles: ["full", "compact"], interactive: false },
    { id: "pomodoro", surfaces: ["desktop"], labelKey: "panel.widget.pomodoro", icon: "timer", sizes: ["sm", "md", "lg"], styles: ["card", "plain"], interactive: true },
    { id: "timer", surfaces: ["desktop"], labelKey: "panel.widget.timer", icon: "av_timer", sizes: ["sm", "md", "lg"], styles: ["card", "plain"], interactive: true },
    { id: "calendar", surfaces: ["desktop"], labelKey: "panel.widget.calendar", icon: "calendar_month", sizes: ["sm", "md", "lg"], styles: ["full", "compact"], interactive: true },
    // The picture the wallpaper library chose: one of three frames.
    { id: "image", surfaces: ["desktop"], labelKey: "panel.widget.image", icon: "image", sizes: ["sm", "md", "lg"], styles: ["cover", "contain", "frame"], interactive: false }
]

// The same widget id may exist on more than one surface ("media" is on the bar,
// the panel and the desktop); `find` takes the surface to tell them apart.
function on(surface) {
    var name = surface || "panel"
    return WIDGETS.filter(function (widget) {
        return widget.surfaces.indexOf(name) >= 0
    })
}

function find(id, surface) {
    var list = on(surface)
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i]
    }
    return null
}

function defaultSize(widget) {
    if (!widget || !widget.sizes || widget.sizes.length === 0)
        return "md"
    return widget.sizes.indexOf("md") >= 0 ? "md" : widget.sizes[0]
}

// The natural width of a desktop widget at a size. It is a layout constant of
// the registry, so the editor canvas and the real background layer agree; the
// height always comes from the widget's content.
var DESKTOP_WIDTH = {
    clock: 280, calendar: 360, weather: 320, resources: 300,
    pomodoro: 300, timer: 300, media: 360, toggles: 380, notes: 300,
    image: 380
}

function widthOf(id, size) {
    var base = DESKTOP_WIDTH[id] || 300
    var factor = size === "sm" ? 0.85 : (size === "lg" ? 1.25 : 1)
    return Math.round(base * factor)
}

// The registry size closest to a width: the in-place editor turns a corner
// drag into one of the widget's own sizes, so a widget is never a size the
// registry does not know.
function sizeForWidth(id, width) {
    var widget = find(id, "desktop")
    if (!widget || !widget.sizes || widget.sizes.length === 0)
        return "md"
    var best = widget.sizes[0]
    var distance = Infinity
    for (var i = 0; i < widget.sizes.length; i++) {
        var current = Math.abs(widthOf(id, widget.sizes[i]) - width)
        if (current < distance) {
            distance = current
            best = widget.sizes[i]
        }
    }
    return best
}
