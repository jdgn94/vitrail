"""Wallpaper library: one folder per kind, a selection of a single kind that
rotates, and adaptive SVGs whose colours come from the palette.

The library lives next to settings.ini (~/.config/vitrail/wallpapers), apart
from the user's own pictures. The settings window cannot touch files, so it
asks: `wallpaperImport` / `wallpaperRemove` hold "<nonce>|path|path…" and
sync() copies or deletes, then clears the request.

Kinds never mix: the selection holds images, SVGs or videos, and the colour
extraction follows the wallpaper on screen (a video lends one frame, an SVG
its seed colour).
"""

from __future__ import annotations

import configparser
import json
import random
import re
import shutil
import subprocess
from collections import Counter
from pathlib import Path
from typing import Callable

from vitrail import colors

KINDS = {
    "image": (".png", ".jpg", ".jpeg", ".webp", ".bmp"),
    "svg": (".svg",),
    "video": (".mp4", ".webm", ".mkv", ".mov", ".m4v", ".avi"),
}
FOLDERS = {"image": "images", "svg": "svg", "video": "videos"}
SEPARATOR = "|"
# Material baseline purple: the seed of an SVG with no colour of its own.
DEFAULT_SEED = "#6750a4"
PLACEHOLDER = re.compile(r"\{\{\s*([a-z_]+)\s*\}\}")
HEX = re.compile(r"#([0-9a-fA-F]{6})\b")
# Channels closer than this read as grey and say nothing about the art.
GREY_SPREAD = 40


def kind_of(path: str) -> str | None:
    suffix = Path(path).suffix.lower()
    for kind, suffixes in KINDS.items():
        if suffix in suffixes:
            return kind
    return None


def ensure_folders(base: Path) -> dict[str, Path]:
    folders = {kind: base / name for kind, name in FOLDERS.items()}
    for folder in folders.values():
        folder.mkdir(parents=True, exist_ok=True)
    return folders


def parse_selection(value: str) -> list[str]:
    return [path for path in value.split(SEPARATOR) if path]


def join_selection(paths: list[str]) -> str:
    return SEPARATOR.join(paths)


def next_wallpaper(
    selection: list[str], current: str, order: str, rng: random.Random | None = None
) -> str | None:
    if not selection:
        return None
    if len(selection) == 1:
        return selection[0]
    if order == "random":
        return (rng or random).choice([path for path in selection if path != current])
    if current not in selection:
        return selection[0]
    return selection[(selection.index(current) + 1) % len(selection)]


def svg_seed(text: str) -> str | None:
    """The most used colour in the drawing, greys aside."""
    counts: Counter[str] = Counter()
    for match in HEX.finditer(text):
        value = match.group(1).lower()
        channels = [int(value[i:i + 2], 16) for i in (0, 2, 4)]
        if max(channels) - min(channels) >= GREY_SPREAD:
            counts["#" + value] += 1
    return counts.most_common(1)[0][0] if counts else None


def render_svg(text: str, palette: dict[str, str]) -> str:
    """{{role}} placeholders take the palette colour of that role."""
    fallback = palette.get("on_surface", "#ffffff")
    return PLACEHOLDER.sub(lambda match: palette.get(match.group(1), fallback), text)


def read_prefs(settings: Path) -> dict[str, str]:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(settings, encoding="utf-8")
    except configparser.Error:
        return {}
    return dict(parser["appearance"]) if parser.has_section("appearance") else {}


def write_pref(settings: Path, key: str, value: str) -> None:
    """Rewrites one [appearance] key in place, leaving every other line be."""
    lines = settings.read_text(encoding="utf-8").splitlines() if settings.exists() else []
    section, done, out = "", False, []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            if section == "appearance" and not done:
                out.append(f"{key}={value}")
                done = True
            section = stripped[1:-1]
        elif section == "appearance" and stripped.split("=", 1)[0].strip() == key:
            line, done = f"{key}={value}", True
        out.append(line)
    if not done:
        if section != "appearance":
            out.append("[appearance]")
        out.append(f"{key}={value}")
    settings.write_text("\n".join(out) + "\n", encoding="utf-8")


def library(prefs: dict[str, str], settings: Path) -> Path:
    custom = prefs.get("wallpaperDir")
    return Path(custom).expanduser() if custom else settings.parent / "wallpapers"


def request_paths(value: str) -> list[str]:
    """The paths of a request; the leading nonce only makes it a new value."""
    return parse_selection(value)[1:]


def _free_name(target: Path) -> Path:
    counter = 2
    candidate = target
    while candidate.exists():
        candidate = target.with_name(f"{target.stem}-{counter}{target.suffix}")
        counter += 1
    return candidate


def sync(settings: Path) -> tuple[list[Path], list[Path]]:
    """Carries out the settings window's import and removal requests."""
    prefs = read_prefs(settings)
    folders = ensure_folders(library(prefs, settings))
    imported: list[Path] = []
    removed: list[Path] = []
    for path in request_paths(prefs.get("wallpaperImport", "")):
        source, kind = Path(path), kind_of(path)
        if kind and source.is_file():
            target = _free_name(folders[kind] / source.name)
            shutil.copy2(source, target)
            imported.append(target)
    root = library(prefs, settings).resolve()
    for path in request_paths(prefs.get("wallpaperRemove", "")):
        target = Path(path).resolve()
        # Only the library's own copies: never a file of the user's.
        if target.is_file() and target.is_relative_to(root):
            target.unlink()
            removed.append(target)
    for key in ("wallpaperImport", "wallpaperRemove"):
        if prefs.get(key):
            write_pref(settings, key, "")
    return imported, removed


def advance(settings: Path) -> str | None:
    """Moves the wallpaper to the next one of the selection."""
    prefs = read_prefs(settings)
    current = prefs.get("wallpaper", "")
    chosen = next_wallpaper(parse_selection(prefs.get("wallpaperSelection", "")), current,
                            prefs.get("wallpaperOrder", "sequential"))
    if chosen and chosen != current:
        write_pref(settings, "wallpaper", chosen)
        return chosen
    return None


def apply(
    settings: Path,
    cache: Path,
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
) -> str | None:
    """Regenerates the palette when the wallpaper or the SVG seed changed.

    Returns the wallpaper it themed, or None when nothing had to change.
    """
    prefs = read_prefs(settings)
    ensure_folders(library(prefs, settings))
    path = prefs.get("wallpaper", "")
    kind = kind_of(path)
    if not path or kind is None or not Path(path).is_file():
        return None
    seed_pref = prefs.get("wallpaperSeed", "")
    key = f"{path}{SEPARATOR}{seed_pref}" if kind == "svg" else path
    stamp = cache / "wallpaper.applied"
    if stamp.exists() and stamp.read_text(encoding="utf-8") == key:
        return None

    cache.mkdir(parents=True, exist_ok=True)
    generated = cache / "generated"
    image, seed, text = Path(path), None, ""
    if kind == "video":
        image = cache / "wallpaper-frame.png"
        run(["ffmpeg", "-loglevel", "error", "-y", "-ss", "1", "-i", path,
             "-frames:v", "1", str(image)], check=True)
    elif kind == "svg":
        text = Path(path).read_text(encoding="utf-8")
        seed = seed_pref or svg_seed(text) or DEFAULT_SEED

    colors.write_theme(image, generated, seed=seed, run=run)
    if kind == "svg":
        for mode in ("dark", "light"):
            palette = json.loads((generated / f"theme-{mode}.json").read_text(encoding="utf-8"))
            (generated / f"wallpaper-{mode}.svg").write_text(
                render_svg(text, palette["colors"]), encoding="utf-8")
    stamp.write_text(key, encoding="utf-8")
    return path
