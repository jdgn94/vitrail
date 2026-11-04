-- Vitrail Hyprland configuration.
--
-- Hyprland 0.56 reads Lua natively (hl.* API). Runtime values that the
-- settings panel owns (rounding, borders, opacity, blur, keyboard) are applied
-- with `hyprctl eval` by scripts/apply-settings.sh, so this file only sets the
-- defaults for a fresh session.

local home = os.getenv("HOME")

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        resize_on_border = true,
        layout = "dwindle",
        col = {
            active_border = "rgba(a8c7faee)",
            inactive_border = "rgba(00000000)",
        },
    },
    decoration = {
        rounding = 14,
        rounding_power = 2,
        active_opacity = 0.97,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            ignore_opacity = false,
            new_optimizations = true,
        },
        shadow = { enabled = true, range = 12, render_power = 3 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = { focus_on_activate = false },
    input = {
        follow_mouse = 1,
        kb_layout = "us",
        kb_options = "grp:alt_shift_toggle",
        numlock_by_default = true,
        touchpad = { natural_scroll = true },
    },
})

-- Animations live with the style, as the design system requires.
hl.curve("vitrail", { type = "bezier", points = { { 0.2, 0 }, { 0.2, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "vitrail" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "vitrail" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "vitrail" })

-- Monitors: let Hyprland use its defaults until the panel manages them.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

local mod = "SUPER"

-- Windows.
hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "window/close" })
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "window/float" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(), { description = "window/fullscreen" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit(), { description = "shell/exit" })

-- Applications.
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("kitty"), { description = "apps/terminal" })
-- Super pressed and released on its own is the only launcher key, like the
-- bar button. Super + Space stays with the keyboard layout switch.
local launcher = home .. "/.local/bin/vitrail-bar ipc call launcher toggle"
hl.bind(mod .. " + SUPER_L", hl.dsp.exec_cmd(launcher), { release = true, description = "apps/launcher" })
hl.bind(mod .. " + comma", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-settings"), { description = "shell/settings" })
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"), { description = "shell/lock" })
hl.bind(mod .. " + period", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call clipboard toggle"), { description = "shell/clipboard" })
hl.bind(mod .. " + SHIFT + period", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call clipboard emoji"), { description = "shell/clipboard-emoji" })
hl.bind(mod .. " + ALT + period", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call clipboard colors"), { description = "shell/clipboard-colors" })
hl.bind(mod .. " + CTRL + period", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call clipboard pick"), { description = "shell/clipboard-pick" })
hl.bind(mod .. " + P", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call panel toggle full"), { description = "shell/panel" })
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call panel toggle overlay"), { description = "shell/panel-overlay" })

-- Focus.
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "focus/left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "focus/right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "focus/up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "focus/down" })

-- Move windows.
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "move/left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "move/right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "move/up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "move/down" })

-- Workspaces.
for workspace = 1, 9 do
    hl.bind(mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }), { description = "workspace/" .. workspace })
    hl.bind(mod .. " + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }), { description = "workspace/move-" .. workspace })
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "workspace/next" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "workspace/prev" })

-- Mouse.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "mouse/drag" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "mouse/resize" })

-- Media keys. Volume, microphone and brightness go through the bar's OSD
-- (`osd` IPC), which changes the value and shows its slider; without the bar
-- the same key falls back to wpctl / brightnessctl. playerctl drives
-- playback. They work with the lid closed and the session locked.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd volume up || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "media/volume-up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd volume down || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "media/volume-down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd volume mute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true, description = "media/mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd mic mute || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true, description = "media/mic-mute" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "media/play-pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "media/play-pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "media/next" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "media/prev" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "media/stop" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd brightness up || brightnessctl --class=backlight set +5%"), { locked = true, repeating = true, description = "media/brightness-up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-bar ipc call osd brightness down || brightnessctl --class=backlight set 5%-"), { locked = true, repeating = true, description = "media/brightness-down" })

-- Screenshots.
hl.bind("PRINT", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"), { description = "screenshot/region" })
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("grim - | wl-copy"), { description = "screenshot/screen" })

-- Vitrail's own windows (settings, gallery) run on the QML runtime, whose
-- class is generic. They open floating, centred: the class is matched alone
-- because the title is set after the window maps, too late for the rule.
hl.window_rule({
    name = "vitrail-float",
    match = { class = "^org\\.qt-project\\.qml$" },
    float = true,
    center = true,
})

-- A terminal is a normal tiled window, never a floating card.
hl.window_rule({
    name = "kitty-tile",
    match = { class = "^kitty$" },
    float = false,
})

-- Glass: every Vitrail surface is a Quickshell layer, and Hyprland blurs a
-- layer only through a rule. ignore_alpha keeps the fully transparent pixels
-- of these full-screen layers out of the blur, so only the drawn surfaces get
-- it. scripts/apply-settings.sh redefines this rule (same name) with blur off
-- when the surface style is solid.
hl.layer_rule({
    name = "vitrail-glass",
    match = { namespace = "^vitrail-(bar|popup|notifications|dialog|session|tooltip|launcher|osd|clipboard)$" },
    blur = true,
    ignore_alpha = 0.01,
})


-- Autostart. The bar is also the notification daemon. cliphist keeps what is
-- copied (text and images) for the launcher's clipboard mode (`;`).
hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.local/bin/vitrail-bar")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- The saved monitor layout, so it survives a logout. --force: the stamp
    -- that keeps other preference writes from re-applying it does not know
    -- this is a new session.
    hl.exec_cmd(home .. "/.local/bin/vitrail-monitors apply --force")
end)
