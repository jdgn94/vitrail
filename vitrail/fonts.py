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
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path
from typing import Callable
from xml.sax.saxutils import escape

from . import cursor as cursor_engine
from . import icons as icon_engine
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

# The icons a pack's mosaic cell shows: common enough to exist in every theme.
ICON_PREVIEWS = [
    "folder",
    "user-home",
    "text-x-generic",
    "image-x-generic",
    "applications-system",
    "web-browser",
    "utilities-terminal",
    "user-trash",
]
PREVIEW_SIZE = 48
# An Xcursor's image chunks are named by nominal size; a 32 px arrow reads best.
CURSOR_PREVIEW_SIZE = 32
XCURSOR_IMAGE = 0xFFFD0002
# The shapes a mosaic cell shows per cursor theme, in this order. Themes name
# them differently; the first file that exists wins.
CURSOR_SHAPES = [
    ("arrow", ("default", "left_ptr")),
    ("hand", ("hand2", "hand1", "pointer", "pointing_hand")),
    ("text", ("xterm", "text", "ibeam")),
    ("resize-h", ("sb_h_double_arrow", "ew-resize", "size_hor")),
    ("resize-v", ("sb_v_double_arrow", "ns-resize", "size_ver")),
    ("move", ("fleur", "move", "all-scroll")),
    ("help", ("help", "question_arrow", "left_ptr_help", "whats_this")),
    ("progress", ("progress", "wait", "left_ptr_watch", "half-busy")),
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
            # `cursors` and `cursors_scalable` are both pointer content.
            if any(name.startswith("cursors") for name in folders):
                cursors.setdefault(path.name.casefold(), path.name)
            if any(not name.startswith("cursors") for name in folders):
                icons.setdefault(path.name.casefold(), path.name)
    return (sorted(icons.values(), key=str.casefold), sorted(cursors.values(), key=str.casefold))


def preview_cache() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "vitrail" / "fonts"


# --- previews ----------------------------------------------------------------


def _sections(path: Path) -> dict[str, dict[str, str]]:
    """An index.theme as {section: {key: value}}."""
    sections: dict[str, dict[str, str]] = {}
    current: dict[str, str] | None = None
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return sections
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = sections.setdefault(line[1:-1], {})
        elif current is not None and "=" in line and not line.startswith("#"):
            key, _, value = line.partition("=")
            current[key.strip()] = value.strip()
    return sections


def theme_dir(name: str, roots: list[Path]) -> Path | None:
    """The first folder in `roots` that holds the named theme."""
    for root in roots:
        candidate = root / name
        if (candidate / "index.theme").is_file():
            return candidate
    return None


def _theme_chain(theme: Path, roots: list[Path]) -> list[Path]:
    """The theme and every theme it inherits from, parents last."""
    seen: set[str] = set()
    chain: list[Path] = []
    pending = [theme]
    while pending:
        current = pending.pop(0)
        if current.name in seen or not (current / "index.theme").is_file():
            continue
        seen.add(current.name)
        chain.append(current)
        inherits = _sections(current / "index.theme").get("Icon Theme", {}).get("Inherits", "")
        for name in (part.strip() for part in inherits.split(",")):
            if name:
                parent = theme_dir(name, roots)
                if parent is not None:
                    pending.append(parent)
    return chain


def _dir_size(name: str, section: dict[str, str]) -> int:
    raw = section.get("Size", "")
    if raw.isdigit():
        return int(raw)
    digits = re.match(r"(\d+)", name)
    return int(digits.group(1)) if digits else 9999


def icon_previews(theme: Path, names: list[str], roots: list[Path]) -> dict[str, str]:
    """The theme's own file for each name, nearest 48 px first."""
    found: dict[str, str] = {}
    for current in _theme_chain(theme, roots):
        sections = _sections(current / "index.theme")
        directories = [
            part.strip() for part in sections.get("Icon Theme", {}).get("Directories", "").split(",") if part.strip()
        ]
        # Vector first (sharp at any size), then the size nearest the preview.
        ranked = sorted(
            directories,
            key=lambda name: ("scalable" not in name, abs(_dir_size(name, sections.get(name, {})) - PREVIEW_SIZE)),
        )
        for name in names:
            if name in found:
                continue
            for directory in ranked:
                for suffix in (".svg", ".png"):
                    path = current / directory / (name + suffix)
                    if path.is_file():
                        found[name] = str(path)
                        break
                if name in found:
                    break
    return found


def _png(width: int, height: int, pixels: bytes) -> bytes:
    """A straight-alpha RGBA PNG from Xcursor's premultiplied ARGB words."""
    rows = bytearray()
    for y in range(height):
        rows.append(0)  # no filter
        for x in range(width):
            value = struct.unpack_from("<I", pixels, (y * width + x) * 4)[0]
            alpha = (value >> 24) & 0xFF
            red, green, blue = (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF
            if 0 < alpha < 255:
                red = min(255, red * 255 // alpha)
                green = min(255, green * 255 // alpha)
                blue = min(255, blue * 255 // alpha)
            rows += bytes((red, green, blue, alpha))

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


def xcursor_png(data: bytes) -> bytes | None:
    """The PNG of the Xcursor image closest to 32 px, or None."""
    if len(data) < 16 or data[:4] != b"Xcur":
        return None
    try:
        _magic, header, _version, count = struct.unpack_from("<IIII", data, 0)
    except struct.error:
        return None
    best: tuple[int, int, int, int] | None = None
    for index in range(count):
        try:
            kind, subtype, position = struct.unpack_from("<III", data, header + index * 12)
        except struct.error:
            break
        if kind != XCURSOR_IMAGE:
            continue
        try:
            _h, _k, _s, _v, width, height, _xh, _yh, _delay = struct.unpack_from("<IIIIIIIII", data, position)
        except struct.error:
            continue
        if not (0 < width <= 512 and 0 < height <= 512):
            continue
        if position + 36 + width * height * 4 > len(data):
            continue
        distance = abs(subtype - CURSOR_PREVIEW_SIZE)
        if best is None or distance < best[0]:
            best = (distance, width, height, position)
    if best is None:
        return None
    _distance, width, height, position = best
    return _png(width, height, data[position + 36 : position + 36 + width * height * 4])


def cursor_previews(theme: Path, cache: Path) -> list[str]:
    """A cached PNG per shape the theme has, for the mosaic cell."""
    files = theme / "cursors"
    if not files.is_dir():
        return []
    found: list[str] = []
    for shape, names in CURSOR_SHAPES:
        source = next((files / name for name in names if (files / name).is_file()), None)
        if source is None:
            continue
        target = cache / f"{theme.name}-{shape}.png"
        try:
            if target.is_file() and target.stat().st_mtime >= source.stat().st_mtime:
                found.append(str(target))
                continue
            image = xcursor_png(source.read_bytes())
        except OSError:
            continue
        if image is None:
            continue
        try:
            cache.mkdir(parents=True, exist_ok=True)
            target.write_bytes(image)
        except OSError:
            continue
        found.append(str(target))
    return found


def state(
    run: Runner = run_text,
    roots: list[Path] | None = None,
    cache: Path | None = None,
    user_roots: list[Path] | None = None,
) -> dict:
    """The lists the settings window offers: fonts, packs and cursors."""
    roots = list(roots) if roots is not None else DEFAULT_ROOTS
    cache = cache or preview_cache()
    text = run(font_query()) or ""
    icons, cursors = themes(roots)
    writable = list(user_roots) if user_roots is not None else icon_engine.user_roots()
    icon_files: dict[str, list[str]] = {}
    for name in icons:
        directory = theme_dir(name, roots)
        if directory is not None:
            found = icon_previews(directory, ICON_PREVIEWS, roots)
            icon_files[name] = [found[icon] for icon in ICON_PREVIEWS if icon in found]
    cursor_files: dict[str, list[str]] = {}
    for name in cursors:
        directory = theme_dir(name, roots)
        if directory is not None:
            paths = cursor_previews(directory, cache)
            if paths:
                cursor_files[name] = paths

    # The packs a Vitrail design can be built from: every installed theme that
    # is not itself generated.
    designs = [name for name in cursors if not name.startswith(cursor_engine.PREFIX)]
    icon_designs = [name for name in icons if not name.startswith(icon_engine.PREFIX)]

    return {
        "fonts": families(text),
        "monospace": monospace(text),
        "iconThemes": icons,
        "cursorThemes": cursors,
        "cursorDesigns": designs,
        "iconDesigns": icon_designs,
        "iconUser": [name for name in icons if any((root / name / "index.theme").is_file() for root in writable)],
        "iconPreviews": icon_files,
        "cursorPreviews": cursor_files,
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


def _truthy(value: object) -> bool:
    """A stored boolean, which arrives as a string from the INI files."""
    return str(value if value is not None else "").strip().lower() in ("true", "1", "yes", "on")


def active_mode(appearance: str | None = None) -> str:
    """The session's light/dark mode: the choice or the clock's guess."""
    if appearance is None:
        appearance = prefs.read_prefs(prefs.config_dir()).get("appearance", "auto")
    return (
        appearance if appearance in ("light", "dark") else ("light" if 7 <= time.localtime().tm_hour < 19 else "dark")
    )


def active_palette() -> dict:
    """The palette the wallpaper produced for the current light/dark mode."""
    path = preview_cache().parent / "generated" / f"theme-{active_mode()}.json"
    try:
        return json.loads(path.read_text(encoding="utf-8")).get("colors", {})
    except (OSError, ValueError):
        return {}


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


def _request_parts(value: object) -> tuple[str, str]:
    """(nonce, path or name) of a request written as "<nonce>|value"."""
    nonce, _bar, rest = str(value or "").partition("|")
    return nonce.strip(), rest.strip()


def _write_icons_result(cache: Path, result: dict) -> None:
    path = cache.parent / "icons-result.json"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(result, separators=(",", ":")), encoding="utf-8")
    except OSError:
        pass


def _write_fonts_state(run: Runner, roots: list[Path], cache: Path, data_home: Path | None) -> None:
    """Refreshes the file the settings window reads after an icon change."""
    live = state(
        run=run,
        roots=roots,
        cache=cache,
        user_roots=icon_engine.user_roots(data_home),
    )
    try:
        path = cache.parent / "fonts-state.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(live, separators=(",", ":")), encoding="utf-8")
    except OSError:
        pass


def _apply_icon_requests(
    values: dict,
    config: Path,
    run: Runner,
    roots: list[Path],
    cache: Path,
    data_home: Path | None,
) -> tuple[bool, bool]:
    """(handled, failed): imports or deletes what the window asked for."""
    import_nonce, imports = _request_parts(values.get("iconImport"))
    remove_nonce, removals = _request_parts(values.get("iconRemove"))
    if not imports and not removals:
        return False, False
    handled = True
    failed = False
    prefs_dir = config / "vitrail"
    if imports:
        try:
            target = icon_engine.import_zip(imports, data_home=data_home)
        except (OSError, ValueError) as error:
            failed = True
            log(f"icon import failed: {error}")
            _write_icons_result(
                cache,
                {"action": "import", "ok": False, "nonce": import_nonce, "message": str(error)},
            )
        else:
            log(f"icon import installed {target.name}")
            _write_icons_result(
                cache,
                {"action": "import", "ok": True, "nonce": import_nonce, "name": target.name, "message": ""},
            )
        try:
            prefs.write_pref(prefs_dir, "iconImport", "")
        except OSError:
            pass
    if removals:
        try:
            target = icon_engine.remove_pack(removals, data_home=data_home)
        except (OSError, ValueError) as error:
            failed = True
            log(f"icon removal failed: {error}")
            _write_icons_result(
                cache,
                {"action": "remove", "ok": False, "nonce": remove_nonce, "message": str(error)},
            )
        else:
            log(f"icon pack removed: {target.name}")
            _write_icons_result(
                cache,
                {"action": "remove", "ok": True, "nonce": remove_nonce, "name": target.name, "message": ""},
            )
        try:
            prefs.write_pref(prefs_dir, "iconRemove", "")
        except OSError:
            pass
    _write_fonts_state(run, roots, cache, data_home)
    return handled, failed


def apply(
    values: dict,
    config: Path,
    run: Runner = run_text,
    roots: list[Path] | None = None,
    hyprland: bool | None = None,
    palette: dict | None = None,
    data_home: Path | None = None,
    cache: Path | None = None,
    x11: bool | None = None,
    render=None,
    mode: str | None = None,
) -> int:
    """Applies `fonts.ini` system-wide.

    0 when every value was used, 1 when a field fell back to its default, 2
    when fontconfig listed nothing and nothing could be validated (nothing is
    written then: defaults would overwrite a working configuration).
    """
    cache = cache or preview_cache()
    explicit_roots = roots is not None
    roots = list(roots) if explicit_roots else list(DEFAULT_ROOTS)
    # The default list does not carry a custom XDG data folder; add it so an
    # imported pack is selectable in the same apply that installed it.
    if not explicit_roots:
        data_root = (
            data_home / "icons"
            if data_home is not None
            else Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "icons"
        )
        if data_root not in roots:
            roots = [*roots, data_root]
    _requests, request_failed = _apply_icon_requests(values, config, run, roots, cache, data_home)
    live = state(run=run, roots=roots, cache=cache)
    if not live["fonts"]:
        log("refused: fc-list listed no families; nothing was applied")
        return 2

    replaced = request_failed

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
        icon_designs = [
            icon_engine.design_name(name, style) for name in live.get("iconDesigns", []) for style in icon_engine.STYLES
        ]
        icons = pick(values.get("iconTheme"), live["iconThemes"] + icon_designs, DEFAULT_ICON_THEME, "icon theme")
        pack, style = icon_engine.split_design(icons)
        if pack:
            source = theme_dir(pack, roots or DEFAULT_ROOTS)
            if source is None:
                log(f"refused: the pack {pack!r} of {icons!r} is not installed")
                icons = DEFAULT_ICON_THEME
                replaced = True
            else:
                target = ((data_home / "icons") if data_home else icon_engine.output_root()) / icons
                icon_engine.build(
                    source,
                    target,
                    palette if palette is not None else active_palette(),
                    cache / "icon-themes",
                    roots or DEFAULT_ROOTS,
                    style=style,
                )
    else:
        log("skipped: no icon theme found")
    cursor = ""
    designs = [cursor_engine.design_name(name) for name in live.get("cursorDesigns", [])]
    if live["cursorThemes"] or designs:
        active = active_mode() if mode not in ("light", "dark") else mode
        requested = values.get("cursorTheme")
        if _truthy(values.get("cursorThemeSplit")):
            # The split can leave one mode empty: that mode follows the shared
            # pack again, and the active mode decides which row is in force.
            requested = values.get("cursorThemeLight" if active == "light" else "cursorThemeDark") or requested
        cursor = pick(
            requested,
            live["cursorThemes"] + designs,
            DEFAULT_CURSOR,
            f"cursor theme ({active})",
        )
        pack = cursor_engine.source_of(cursor)
        if pack:
            source = theme_dir(pack, roots or DEFAULT_ROOTS)
            if source is None:
                log(f"refused: the pack {pack!r} of {cursor!r} is not installed")
                cursor = DEFAULT_CURSOR
                replaced = True
            else:
                target = ((data_home / "icons") if data_home else cursor_engine.output_root()) / cursor
                cursor_engine.build(
                    source,
                    target,
                    palette if palette is not None else active_palette(),
                    cache / "themes",
                    spinner=False,
                    render=render,
                )
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
        # X11: the theme for the X server's own cursor, GTK's settings, and the
        # XSETTINGS daemon GTK apps on X11 watch.
        resources = config / "X11" / "vitrail-cursor.Xresources"
        take_file(resources, f"# Generated by Vitrail\nXcursor.theme: {cursor}\nXcursor.size: {size}\n")
        set_ini_key(config / "gtk-3.0" / "settings.ini", "Settings", "gtk-cursor-theme-name", cursor)
        set_ini_key(config / "gtk-3.0" / "settings.ini", "Settings", "gtk-cursor-theme-size", str(size))
        cursor_engine.update_xsettings(config / "xsettingsd" / "xsettingsd.conf", cursor, size)

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
        # X11 clients: the X server's resources carry the theme for new cursors,
        # and xsettingsd (when it runs) tells GTK apps without a restart.
        if x11 is None:
            x11 = bool(os.environ.get("DISPLAY")) and bool(shutil.which("xrdb"))
        if x11:
            run(["xrdb", "-merge", str(resources)])
            run(["pkill", "-HUP", "-x", "xsettingsd"])
    return 1 if replaced else 0


def main(argv: list[str] | None = None, run: Runner = run_text, cache: Path | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(run=run, cache=cache), separators=(",", ":")))
        return 0
    if args == ["apply"]:
        return apply(prefs.read_prefs(prefs.config_dir()), config_home(), run=run, palette=active_palette())
    if args == ["console-family"]:
        name = prefs.read_prefs(prefs.config_dir()).get("fontConsole") or DEFAULT_CONSOLE
        family = console_family(name, run=run)
        if family:
            print(family)
        return 0
    if len(args) == 2 and args[0] == "import":
        try:
            print(icon_engine.import_zip(args[1]))
        except (OSError, ValueError) as error:
            log(str(error))
            return 1
        return 0
    if len(args) == 2 and args[0] == "remove":
        try:
            print(icon_engine.remove_pack(args[1]))
        except (OSError, ValueError) as error:
            log(str(error))
            return 1
        return 0
    print("usage: fonts state | apply | console-family | import <zip> | remove <theme>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
