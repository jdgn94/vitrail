# Tab bar for Vitrail's kitty, in three styles that mirror the prompt header:
#
#   capsule  a rounded pill per tab, in the tab's own fill
#   tonal    coloured text, tabs divided by a thin rule
#   minimal  muted text, the active tab underlined
#
# kitty only calls this for tab_bar_style custom. Every tab shows a process icon,
# an optional number and a close icon. The icon is not clickable on its own —
# kitty has no click targets inside a tab — so the TabManager mouse handler is
# wrapped below: a left-click over the icon closes the tab, and hovering it
# turns it into the error colour.
#
# Settings come from ~/.config/vitrail-vpn/header.conf (written by the Terminal
# settings page) and roles from the generated prompt palette, both re-read when
# their mtime changes. Defaults here must equal terminal-header.ts's.
import json
import os
from kitty.fast_data_types import (
    GLFW_MOUSE_BUTTON_LEFT,
    GLFW_RELEASE,
    Screen,
    get_boss,
    set_tab_being_dragged,
)
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title
from kitty.tabs import TabManager

LEFT_CAP = ""
RIGHT_CAP = ""
RULE = "│"
DOT = "\u00b7"
CLOSE = ""
NEW_TAB = ""

DEFAULTS = {
    "tabStyle": "capsule",
    "tabIcons": "1",
    "tabNumbers": "0",
    "colorScheme": "light",
}
_HERE = os.path.dirname(os.path.realpath(__file__))
_CONF = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "vitrail",
    "header.conf",
)
_CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "vitrail",
    "generated",
)
# Roles the tab bar needs, mapped to the Material names in theme.json.
_ROLE_KEYS = {
    "on-surface": "on_surface",
    "outline-variant": "outline_variant",
    "error": "error",
}

_files: dict[str, tuple[float, object]] = {}


def _cached(path: str, parse):
    try:
        mtime = os.stat(path).st_mtime
    except OSError:
        return parse(None)
    hit = _files.get(path)
    if hit and hit[0] == mtime:
        return hit[1]
    try:
        with open(path) as f:
            value = parse(f.read())
    except OSError:
        value = parse(None)
    _files[path] = (mtime, value)
    return value


def _parse_conf(text):
    out = dict(DEFAULTS)
    for line in (text or "").splitlines():
        key, sep, value = line.partition("=")
        if sep and key in DEFAULTS:
            out[key] = value.strip().strip('"')
    return out


def _parse_palette(text):
    try:
        colors = json.loads(text or "{}").get("colors", {})
    except ValueError:
        colors = {}
    return {role: colors.get(key) for role, key in _ROLE_KEYS.items()}


def _settings():
    return _cached(_CONF, _parse_conf)


def _role(name: str, fallback: int) -> int:
    # The terminal's own light/dark (header.conf's resolved colorScheme), which
    # may differ from the desktop's.
    scheme = "dark" if _settings()["colorScheme"] == "dark" else "light"
    palette = os.path.join(_CACHE_DIR, f"theme-{scheme}.json")
    hex_ = (_cached(palette, _parse_palette).get(name) or "").lstrip("#")
    return as_rgb(int(hex_, 16)) if hex_ else fallback


# Foreground process -> glyph. Unknown processes get the cube.
ICONS = {
    "zsh": "",
    "bash": "",
    "fish": "",
    "sh": "",
    "nvim": "",
    "vim": "",
    "vi": "",
    "git": "",
    "lazygit": "",
    "tig": "",
    "ssh": "",
    "mosh": "",
    "python": "",
    "python3": "",
    "ipython": "",
    "node": "",
    "npm": "",
    "pnpm": "",
    "yarn": "",
    "bun": "",
    "docker": "",
    "podman": "",
    "cargo": "",
    "rustc": "",
    "go": "",
    "htop": "",
    "btop": "",
    "top": "",
    "man": "",
    "less": "",
    "yazi": "",
    "ranger": "",
    "lf": "",
    "mc": "",
    "claude": "",
}
UNKNOWN_ICON = ""


def _icon_for(tab: TabBarData) -> str:
    try:
        t = get_boss().tab_for_id(tab.tab_id)
        procs = t.active_window.child.foreground_processes
        name = os.path.basename(procs[-1]["cmdline"][0]).lstrip("-")
    except Exception:
        return ICONS["zsh"]
    return ICONS.get(name, UNKNOWN_ICON)


# (os_window_id, tab_id) -> cell column of the close icon
_close_cells: dict[tuple[int, int], int] = {}
_hover: tuple[int, int] | None = None

_orig_handle_tab_bar_mouse = TabManager.handle_tab_bar_mouse


def _over_icon(tm, x, y):
    tab_id = tm.tab_bar.tab_id_at(int(x), int(y))
    icon = _close_cells.get((tm.os_window_id, tab_id))
    if icon is None:
        return None
    g = tm.tab_bar.window_geometry
    cell = (int(x) - g.left) // tm.tab_bar.cell_width
    return tab_id if abs(cell - icon) <= 1 else None


def _handle_tab_bar_mouse(self, x, y, button, modifiers, action):
    global _hover
    if button == -1:
        tab_id = _over_icon(self, x, y)
        new = (self.os_window_id, tab_id) if tab_id else None
        if new != _hover:
            _hover = new
            self.update_tab_bar_data()
            self.mark_tab_bar_dirty()
    elif button == GLFW_MOUSE_BUTTON_LEFT and action == GLFW_RELEASE:
        tab_id = _over_icon(self, x, y)
        if tab_id and (tab := self.tab_for_id(tab_id)):
            _hover = None
            set_tab_being_dragged()
            self.recent_tab_bar_mouse_events.clear()
            get_boss().close_tab(tab)
            return
    _orig_handle_tab_bar_mouse(self, x, y, button, modifiers, action)


TabManager.handle_tab_bar_mouse = _handle_tab_bar_mouse


def _fit_title(draw_data, screen, tab, index, budget):
    start = screen.cursor.x
    draw_title(draw_data, screen, tab, index, budget)
    if screen.cursor.x - start > budget:
        screen.cursor.x = start + max(budget - 1, 0)
        screen.draw("…")


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    cfg = _settings()
    style = cfg["tabStyle"]
    tab_bg = screen.cursor.bg
    tab_fg = screen.cursor.fg
    bar_bg = as_rgb(int(draw_data.default_bg))
    primary = as_rgb(int(draw_data.active_bg))
    muted = as_rgb(int(draw_data.inactive_fg))
    rule = _role("outline-variant", muted)
    on_surface = _role("on-surface", tab_fg)
    error = _role("error", tab_fg)
    synthetic = tab.tab_id < 0

    prefix = ""
    if not synthetic:
        if cfg["tabIcons"] == "1":
            prefix += _icon_for(tab) + " "
        if cfg["tabNumbers"] == "1":
            prefix += f"{index} "

    def fg_for_text():
        if style == "capsule":
            return tab_fg
        if style == "tonal":
            return primary if tab.is_active else muted
        return on_surface if tab.is_active else muted

    hovered = _hover == (tab.os_window_id, tab.tab_id)
    close_fg = error if hovered else (tab_fg if style == "capsule" else muted)
    close_cells = 0 if synthetic else 3

    if synthetic:
        prefix = NEW_TAB + " "
    lead = 2 if style == "capsule" else (3 if index > 1 else 1)
    trail = close_cells + (1 if style == "capsule" else 0)
    budget = max_tab_length - lead - trail - len(prefix)

    if max_tab_length < 8 and not synthetic:
        screen.draw("…")
        return screen.cursor.x

    screen.cursor.bold = tab.is_active
    if style == "capsule":
        screen.cursor.fg = tab_bg
        screen.cursor.bg = bar_bg
        screen.draw(LEFT_CAP)
        screen.cursor.fg = fg_for_text()
        screen.cursor.bg = tab_bg
        screen.draw(" ")
    else:
        screen.cursor.bg = bar_bg
        if index > 1:
            screen.cursor.fg = rule
            screen.draw(" " + (DOT if style == "minimal" else RULE) + " ")
        else:
            screen.draw(" ")
        screen.cursor.fg = fg_for_text()

    if style == "minimal" and tab.is_active:
        screen.cursor.decoration = 1
        screen.cursor.decoration_fg = primary

    screen.draw(prefix)
    if synthetic:
        screen.cursor.decoration = 0
        screen.cursor.bold = False
        if style == "capsule":
            screen.cursor.fg = tab_bg
            screen.cursor.bg = bar_bg
            screen.draw(RIGHT_CAP)
            screen.cursor.bg = bar_bg
            screen.draw(" ")
        return screen.cursor.x
    _fit_title(draw_data, screen, tab, index, budget)
    screen.cursor.decoration = 0
    screen.cursor.fg = fg_for_text()
    screen.cursor.bg = tab_bg if style == "capsule" else bar_bg

    screen.draw(" ")
    if not extra_data.for_layout:
        _close_cells[(tab.os_window_id, tab.tab_id)] = screen.cursor.x
    screen.cursor.fg = close_fg
    screen.draw(CLOSE)
    screen.cursor.bold = False
    screen.cursor.fg = fg_for_text()
    screen.draw(" ")

    if style == "capsule":
        screen.cursor.fg = tab_bg
        screen.cursor.bg = bar_bg
        screen.draw(RIGHT_CAP)
    end = screen.cursor.x

    screen.cursor.bg = bar_bg
    if style == "capsule" and end < screen.columns:
        screen.draw(" ")
    return end
