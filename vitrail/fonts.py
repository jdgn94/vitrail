"""Fonts, icon packs and cursor: what the machine has and how to apply a choice.

The settings window cannot run commands, so this module does both halves:

    python3 -m vitrail.fonts state            the installed lists, as JSON
    python3 -m vitrail.fonts apply            applies `fonts.ini`
    python3 -m vitrail.fonts console-family   the validated kitty family

`bin/vitrail-settings` injects `state` at launch; `scripts/apply-settings.sh`
runs `apply` when a preference changes. Nothing is curated here: the page
offers what fontconfig and the theme folders report.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable
from xml.sax.saxutils import escape

from . import prefs
from .system_theme import set_ini_key, take_file

MONO_SPACING = {100, 110}
# A hung fontconfig must not hang the settings watcher.
READ_TIMEOUT = 5

DEFAULT_FONT = "Roboto"
DEFAULT_CONSOLE = "JetBrainsMono Nerd Font"
DEFAULT_ICON_THEME = "Adwaita"
DEFAULT_CURSOR = "Adwaita"
DEFAULT_CURSOR_SIZE = 24
CURSOR_SIZES = (16, 64)
# The shell draws its icons as Material Symbol ligatures: only these three
# families keep every glyph name.
ICON_VARIANTS = ("rounded", "sharp", "outlined")

DEFAULT_ROOTS = [
    Path("/usr/share/icons"),
    Path.home() / ".icons",
    Path.home() / ".local/share/icons",
]

Runner = Callable[[list[str]], str | None]


def log(message: str) -> None:
    print(f"vitrail-fonts: {message}", file=sys.stderr, flush=True)


def font_query() -> list[str]:
    """The one call: every family alias and its spacing class (100 mono)."""
    return ["fc-list", "--format", "%{family}\t%{spacing}\n"]


def run_text(argv: list[str], timeout: int = READ_TIMEOUT) -> str | None:
    """A command's stdout, or None when it is missing, failed or timed out."""
    try:
        found = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return found.stdout if found.returncode == 0 else None


def _faces(text: str) -> list[tuple[str, int]]:
    """(family, spacing) for every line of an `fc-list --format` answer."""
    faces: list[tuple[str, int]] = []
    for line in text.splitlines():
        aliases, _tab, spacing = line.partition("\t")
        try:
            number = int(spacing.strip())
        except ValueError:
            number = 0
        for name in aliases.split(","):
            name = name.strip()
            if name:
                faces.append((name, number))
    return faces


def _names(text: str, mono: bool | None = None) -> list[str]:
    """The distinct families, deduped case-insensitively and sorted."""
    seen: dict[str, str] = {}
    for name, spacing in _faces(text):
        if mono is not None and (spacing in MONO_SPACING) is not mono:
            continue
        seen.setdefault(name.casefold(), name)
    return sorted(seen.values(), key=str.casefold)


def families(text: str) -> list[str]:
    """Every installed family."""
    return _names(text)


def monospace(text: str) -> list[str]:
    """The families fontconfig calls monospace."""
    return _names(text, mono=True)


def themes(roots: list[Path]) -> tuple[list[str], list[str]]:
    """(icon themes, cursor themes) found one level under `roots`."""
    icons: dict[str, str] = {}
    cursors: dict[str, str] = {}
    for root in roots:
        try:
            entries = sorted(root.iterdir())
        except OSError:
            continue
        for path in entries:
            if not path.is_dir() or not (path / "index.theme").is_file():
                continue
            try:
                folders = [child.name for child in path.iterdir() if child.is_dir()]
            except OSError:
                continue
            # A name with a control character would split the line it is
            # written to (environment.d, gtk settings.ini).
            if any(ord(char) < 32 for char in path.name):
                continue
            if "cursors" in folders:
                cursors.setdefault(path.name.casefold(), path.name)
            if any(name != "cursors" for name in folders):
                icons.setdefault(path.name.casefold(), path.name)
    return (sorted(icons.values(), key=str.casefold), sorted(cursors.values(), key=str.casefold))


def state(run: Runner = run_text, roots: list[Path] | None = None) -> dict:
    """The lists the settings window offers: fonts, packs and cursors."""
    text = run(font_query()) or ""
    icons, cursors = themes(list(roots) if roots is not None else DEFAULT_ROOTS)
    return {
        "fonts": families(text),
        "monospace": monospace(text),
        "iconThemes": icons,
        "cursorThemes": cursors,
    }


def config_home() -> Path:
    return prefs.config_dir().parent


# --- applying ----------------------------------------------------------------


def font_name(text: str, family: str) -> str:
    """The gsettings font-name for `family`, keeping the size already set.

    `gsettings get` prints the value quoted ("Sans 11"), so the quotes come off
    before the size is read: font size is the user's, not Vitrail's.
    """
    parts = text.strip().strip("'").rsplit(" ", 1)
    if len(parts) == 2 and parts[1].replace(".", "", 1).isdigit():
        return f"{family} {parts[1]}"
    return f"{family} 11"


def console_family(name: str, run: Runner = run_text) -> str:
    """`name` when it is installed, else empty (and a line saying why)."""
    if not name:
        return ""
    text = run(font_query())
    if text is None:
        log("refused: could not list the installed fonts")
        return ""
    if name in families(text):
        return name
    log(f"refused: console font {name!r} is not installed")
    return ""


def _fontconf(family: str) -> str:
    """The fontconfig aliases: every app asking for the generic gets ours."""
    name = escape(family)
    aliases = "".join(
        f'  <alias binding="same"><family>{generic}</family><prefer><family>{name}</family></prefer></alias>\n'
        for generic in ("sans-serif", "system-ui")
    )
    return (
        '<?xml version="1.0"?>\n'
        '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n'
        "<!-- Generated by Vitrail -->\n"
        f"<fontconfig>\n{aliases}</fontconfig>\n"
    )


def _cursor_size(value: object) -> tuple[int, bool]:
    """(size, replaced): a number inside the range, or the default."""
    if isinstance(value, str) and value.strip().isdigit():
        value = int(value.strip())
    if isinstance(value, bool) or not isinstance(value, int) or not CURSOR_SIZES[0] <= value <= CURSOR_SIZES[1]:
        log(f"refused: cursor size {value!r} is not {CURSOR_SIZES[0]}–{CURSOR_SIZES[1]}")
        return DEFAULT_CURSOR_SIZE, True
    return value, False


def apply(
    values: dict, config: Path, run: Runner = run_text, roots: list[Path] | None = None, hyprland: bool | None = None
) -> int:
    """Applies `fonts.ini` system-wide.

    0 when every value was used, 1 when a field fell back to its default, 2
    when fontconfig listed nothing and nothing could be validated (nothing is
    written then: defaults would overwrite a working configuration).
    """
    live = state(run=run, roots=roots)
    if not live["fonts"]:
        log("refused: fc-list listed no families; nothing was applied")
        return 2

    replaced = False

    def pick(value: object, allowed: list[str], default: str, what: str) -> str:
        nonlocal replaced
        if isinstance(value, str) and value in allowed:
            return value
        if value not in (None, ""):
            log(f"refused: {what} {value!r} is not installed; using {default}")
            replaced = True
        return default

    family = pick(values.get("fontSystem"), live["fonts"], DEFAULT_FONT, "font")
    # A group whose own list is empty cannot be validated: it is skipped and
    # the other groups still apply.
    icons = ""
    if live["iconThemes"]:
        icons = pick(values.get("iconTheme"), live["iconThemes"], DEFAULT_ICON_THEME, "icon theme")
    else:
        log("skipped: no icon theme found")
    cursor = ""
    if live["cursorThemes"]:
        cursor = pick(values.get("cursorTheme"), live["cursorThemes"], DEFAULT_CURSOR, "cursor theme")
    else:
        log("skipped: no cursor theme found")
    size, replaced_size = _cursor_size(values.get("cursorSize", DEFAULT_CURSOR_SIZE))
    replaced = replaced or replaced_size
    variant = values.get("uiIcons")
    if variant not in (None, "", *ICON_VARIANTS):
        log(f"refused: UI icons {variant!r} is not one of {', '.join(ICON_VARIANTS)}")
        replaced = True

    take_file(config / "fontconfig" / "conf.d" / "50-vitrail-font.conf", _fontconf(family))
    if icons:
        set_ini_key(config / "gtk-3.0" / "settings.ini", "Settings", "gtk-icon-theme-name", icons)
        qt = config / "qt6ct" / "qt6ct.conf"
        if qt.parent.is_dir():
            set_ini_key(qt, "Appearance", "icon_theme", icons)
    if cursor:
        env = config / "environment.d" / "20-vitrail-cursor.conf"
        env.parent.mkdir(parents=True, exist_ok=True)
        env.write_text(f"XCURSOR_THEME={cursor}\nXCURSOR_SIZE={size}\n", encoding="utf-8")

    current = run(["gsettings", "get", "org.gnome.desktop.interface", "font-name"]) or ""
    run(["gsettings", "set", "org.gnome.desktop.interface", "font-name", font_name(current, family)])
    if icons:
        run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", icons])
    if cursor:
        run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", cursor])
        run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)])
        if hyprland is None:
            hyprland = bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) and bool(shutil.which("hyprctl"))
        if hyprland:
            run(["hyprctl", "setcursor", cursor, str(size)])
    return 1 if replaced else 0


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(run=run), separators=(",", ":")))
        return 0
    if args == ["apply"]:
        return apply(prefs.read_prefs(prefs.config_dir()), config_home(), run=run)
    if args == ["console-family"]:
        name = prefs.read_prefs(prefs.config_dir()).get("fontConsole") or DEFAULT_CONSOLE
        family = console_family(name, run=run)
        if family:
            print(family)
        return 0
    print("usage: fonts state | apply | console-family", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
