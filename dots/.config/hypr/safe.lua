-- Vitrail safe mode: the smallest config that still gives a usable desktop.
-- Started with `vitrail safe-mode session` when the normal config is broken.
local home = os.getenv("HOME")

hl.config({
    general = { gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle" },
    decoration = { rounding = 0, blur = { enabled = false } },
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd(home .. "/.local/bin/vitrail-settings"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())

hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.local/bin/vitrail-bar")
end)
