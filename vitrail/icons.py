"""Palette-adaptive application icons: the folder set, recoloured.

A Vitrail icon theme is a thin layer over an installed pack: it carries only
the folder icons, hue-shifted to the wallpaper's `primary`, and inherits
everything else from the pack. Folders are the icons a desktop shows most, and
the ones a fixed blue looks wrong next to a warm palette.

The shift keeps each colour's saturation and lightness, so the pack's shading
(a darker flap, a lighter highlight) survives; only the hue moves, and only for
colours within a few degrees of the folder body.
"""

from __future__ import annotations

import colorsys
import hashlib
import json
import os
import re
import sys
from pathlib import Path

PREFIX = "vitrail-icons-"
# How far a colour may sit from the body hue and still be considered part of
# the folder (degrees).
HUE_WINDOW = 42
# Folder-like names; a pack may have any subset.
NAMES = (
    "folder",
    "folder-open",
    "folder-documents",
    "folder-download",
    "folder-music",
    "folder-pictures",
    "folder-videos",
    "folder-templates",
    "folder-publicshare",
    "folder-drag-accept",
    "folder-new",
    "folder-remote",
    "user-home",
    "user-desktop",
    "user-trash",
)
COLOUR = re.compile(r"""(?i)\b(fill|stop-color)\s*([:=])\s*["']?\s*(#[0-9a-f]{3,8})""")
HEX = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")


def log(message: str) -> None:
    print(f"vitrail-icons: {message}", file=sys.stderr, flush=True)


def design_name(pack: str) -> str:
    return PREFIX + pack


def source_of(name: str) -> str:
    return name[len(PREFIX) :] if name.startswith(PREFIX) and len(name) > len(PREFIX) else ""


def output_root() -> Path:
    base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(base) / "icons"


def _rgb(value: str) -> tuple[float, float, float]:
    digits = value.lstrip("#")
    if len(digits) == 3:
        digits = "".join(char * 2 for char in digits)
    return tuple(int(digits[index : index + 2], 16) / 255 for index in (0, 2, 4))


def _hsl(value: str) -> tuple[float, float, float]:
    return colorsys.rgb_to_hls(*_rgb(value))


def _hex(hue: float, lightness: float, saturation: float) -> str:
    red, green, blue = colorsys.hls_to_rgb(hue, lightness, saturation)
    return "#{:02x}{:02x}{:02x}".format(round(red * 255), round(green * 255), round(blue * 255))


def colours(text: str) -> list[str]:
    """Every colour a fill or a gradient stop names, in order."""
    return [HEX_ for _kind, _sign, HEX_ in COLOUR.findall(text) if HEX.match(HEX_)]


def body(text: str) -> str | None:
    """The folder's own colour: the most frequent saturated one."""
    counts: dict[str, int] = {}
    for value in colours(text):
        _hue, lightness, saturation = _hsl(value)
        if saturation >= 0.25 and 0.12 <= lightness <= 0.92:
            counts[value.casefold()] = counts.get(value.casefold(), 0) + 1
    if not counts:
        return None
    return max(counts, key=lambda value: (counts[value], _hsl(value)[2]))


def tint_svg(text: str, palette: dict) -> str:
    """Hue-shifts the folder body towards `primary`, keeping its shading."""
    anchor = body(text)
    primary = palette.get("primary")
    if anchor is None or not primary or not HEX.match(primary):
        return text
    anchor_hue = _hsl(anchor)[0]
    target_hue = _hsl(primary)[0]

    def replace(match: re.Match) -> str:
        value = match.group(3)
        if not HEX.match(value):
            return match.group(0)
        hue, lightness, saturation = _hsl(value)
        distance = abs(hue - anchor_hue)
        distance = min(distance, 1 - distance)
        if distance * 360 > HUE_WINDOW:
            return match.group(0)
        return f"{match.group(1)}{match.group(2)}{_hex(target_hue, lightness, saturation)}"

    return COLOUR.sub(replace, text)


# --- building ----------------------------------------------------------------


def _sections(path: Path) -> dict[str, dict[str, str]]:
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


def _chain(pack: Path, roots: list[Path]) -> list[Path]:
    seen: set[str] = set()
    chain: list[Path] = []
    pending = [pack]
    while pending:
        current = pending.pop(0)
        if current.name in seen or not (current / "index.theme").is_file():
            continue
        seen.add(current.name)
        chain.append(current)
        inherits = _sections(current / "index.theme").get("Icon Theme", {}).get("Inherits", "")
        for name in (part.strip() for part in inherits.split(",")):
            if name:
                for root in roots:
                    candidate = root / name
                    if (candidate / "index.theme").is_file():
                        pending.append(candidate)
                        break
    return chain


def folder_files(pack: Path, roots: list[Path]) -> list[tuple[Path, str]]:
    """(source, path inside the theme) for every folder SVG the pack has."""
    wanted = {name.casefold() for name in NAMES}
    found: dict[str, Path] = {}
    for theme in _chain(pack, roots):
        sections = _sections(theme / "index.theme")
        directories = [
            part.strip() for part in sections.get("Icon Theme", {}).get("Directories", "").split(",") if part.strip()
        ]
        for directory in directories:
            places = theme / directory
            if not places.is_dir():
                continue
            for path in sorted(places.glob("*.svg")):
                name = path.name
                if name.casefold().endswith("-symbolic.svg"):
                    continue
                stem = name[:-4].split("@")[0].casefold()
                if stem not in wanted:
                    continue
                relative = str(path.relative_to(theme))
                found.setdefault(relative, path)
    return [(source, relative) for relative, source in sorted(found.items())]


def build(pack: Path, target: Path, palette: dict, cache: Path, roots: list[Path], force: bool = False) -> bool:
    """Writes the folder layer of `pack`, tinted; False when already current."""
    files = folder_files(pack, roots)
    if not files:
        return False
    stamp = cache / "stamp"
    current = hashlib.sha256(
        json.dumps({"pack": str(pack), "primary": palette.get("primary", "")}, sort_keys=True).encode("utf-8")
    ).hexdigest()
    if not force and (target / "index.theme").is_file() and stamp.is_file():
        try:
            if stamp.read_text(encoding="utf-8").strip() == current:
                return False
        except OSError:
            pass

    for source, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            text = source.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        destination.write_text(tint_svg(text, palette), encoding="utf-8")

    (target / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name=Vitrail icons · {pack.name}\n"
        f"Comment=Vitrail's palette on the {pack.name} folders\n"
        f"Inherits={pack.name}\n"
        "Directories=" + ",".join(sorted({str(Path(relative).parent) for _s, relative in files})) + "\n",
        encoding="utf-8",
    )
    try:
        cache.mkdir(parents=True, exist_ok=True)
        stamp.write_text(current, encoding="utf-8")
    except OSError:
        pass
    return True


def main(
    argv: list[str] | None = None,
    roots: list[Path] | None = None,
    palette: dict | None = None,
    output: Path | None = None,
    cache: Path | None = None,
) -> int:
    """`icons build <pack> [--force]`: the folder layer without the window."""
    from . import fonts  # local: fonts imports this module

    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) >= 2 and args[0] == "build":
        roots = roots or fonts.DEFAULT_ROOTS
        pack = fonts.theme_dir(args[1], roots)
        if pack is None:
            log(f"not an installed theme: {args[1]}")
            return 2
        design = design_name(pack.name)
        target = (output / design) if output else (output_root() / design)
        rebuilt = build(
            pack,
            target,
            palette if palette is not None else fonts.active_palette(),
            cache or (fonts.preview_cache() / "icon-themes"),
            roots,
            force="--force" in args,
        )
        print(f"{design}: {'rebuilt' if rebuilt else 'up to date'} at {target}")
        return 0
    print("usage: icons build <pack> [--force]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
