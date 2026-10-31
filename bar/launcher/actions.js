// Vitrail's own actions, offered by `:` and found by name in the mixed list.
// `label` is an i18n key; `keywords` are English words matched as well as the
// translated name. `run.kind` tells the launcher how to carry it out:
//   cli      vitrail python module, `args` after `-m vitrail.cli`
//   exec     a program, detached
//   settings the settings window on `category`
//   popup    a bar popout of that kind
//   session  the session menu
.pragma library

// Settings pages, with the i18n key of their name and their icon.
var PAGES = [
    { key: "appearance", label: "nav.appearance", icon: "contrast" },
    { key: "wallpaper", label: "section.wallpaper", icon: "wallpaper" },
    { key: "colors", label: "section.colors", icon: "palette" },
    { key: "design", label: "section.design", icon: "design_services" },
    { key: "bar", label: "section.bar", icon: "toolbar" },
    { key: "windows", label: "section.windows", icon: "view_quilt" },
    { key: "terminal", label: "section.terminal", icon: "terminal" },
    { key: "launcher", label: "section.launcher", icon: "apps" },
    { key: "input", label: "section.input", icon: "keyboard" },
    { key: "language", label: "section.language", icon: "translate" },
    { key: "datetime", label: "section.datetime", icon: "schedule" },
    { key: "plugins", label: "section.plugins", icon: "extension" }
]

var actions = [
    { key: "light", label: "launcher.action.light", icon: "light_mode", keywords: "light day theme appearance",
      run: { kind: "cli", args: ["set", "appearance", "light"] } },
    { key: "dark", label: "launcher.action.dark", icon: "dark_mode", keywords: "dark night theme appearance",
      run: { kind: "cli", args: ["set", "appearance", "dark"] } },
    { key: "auto", label: "launcher.action.auto", icon: "brightness_auto", keywords: "auto automatic theme appearance",
      run: { kind: "cli", args: ["set", "appearance", "auto"] } },
    { key: "glass", label: "launcher.action.glass", icon: "blur_on", keywords: "glass blur transparent surface",
      run: { kind: "cli", args: ["set", "surfaceStyle", "glass"] } },
    { key: "solid", label: "launcher.action.solid", icon: "blur_off", keywords: "solid opaque surface",
      run: { kind: "cli", args: ["set", "surfaceStyle", "solid"] } },
    { key: "wallpaper", label: "launcher.action.wallpaper", icon: "skip_next", keywords: "wallpaper background next change",
      run: { kind: "cli", args: ["wallpaper", "next"] } },
    { key: "lock", label: "launcher.action.lock", icon: "lock", keywords: "lock screen",
      run: { kind: "exec", command: ["hyprlock"] } },
    { key: "session", label: "launcher.action.session", icon: "power_settings_new", keywords: "session power logout shutdown reboot suspend",
      run: { kind: "session" } },
    { key: "network", label: "launcher.action.network", icon: "wifi", keywords: "network wifi ethernet internet",
      run: { kind: "popup", popup: "network" } },
    { key: "vpn", label: "launcher.action.vpn", icon: "vpn_lock", keywords: "vpn tunnel",
      run: { kind: "popup", popup: "vpn" } }
].concat(PAGES.map(function (page) {
    return { key: "settings." + page.key, label: "launcher.action.settings", detail: page.label, icon: page.icon,
             keywords: "settings preferences " + page.key, run: { kind: "settings", category: page.key } }
}))

// Items for the launcher, named in the user's language. `t` translates a key.
function toItems(t) {
    return actions.map(function (action) {
        var title = action.detail ? t(action.label) + ": " + t(action.detail) : t(action.label)
        var run = Object.assign({}, action.run)
        return {
            id: "action:" + action.key, group: "actions", title: title, subtitle: "", icon: action.icon, run: run,
            fields: [{ text: title, weight: 1 }, { text: action.keywords, weight: 0.6 }]
        }
    })
}
