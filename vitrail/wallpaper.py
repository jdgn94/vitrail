"""Wallpaper library: one folder per kind, a selection of a single kind that
rotates, and adaptive SVGs whose colours come from the palette.

The library lives in the config folder (~/.config/vitrail/wallpapers), apart
from the user's own pictures. The settings window cannot touch files, so it
asks: `wallpaperImport` / `wallpaperRemove` hold "<nonce>|path|path…" and
sync() copies or deletes, then clears the request.

Kinds never mix: the selection holds images, SVGs or videos, and the colour
extraction follows the wallpaper on screen (a video lends one frame, an SVG
its seed colour).
"""

from __future__ import annotations

import bisect
import colorsys
import hashlib
import json
import random
import re
import shutil
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from typing import Callable

from vitrail import colors, effects, media
from vitrail.prefs import read_prefs, remove_pref, write_pref

KINDS = {
    "image": (".png", ".jpg", ".jpeg", ".webp", ".bmp"),
    "svg": (".svg",),
    "video": (".mp4", ".webm", ".mkv", ".mov", ".m4v", ".avi", ".gif"),
}
FOLDERS = {"image": "images", "svg": "svg", "video": "videos"}
SEPARATOR = "|"
# Material baseline purple: the seed of an SVG with no colour of its own.
DEFAULT_SEED = "#6750a4"
PLACEHOLDER = re.compile(r"\{\{\s*([a-z_]+)\s*\}\}")
HEX = re.compile(r"#([0-9a-fA-F]{6})\b")
SEED_COMMENT = re.compile(r"<!--\s*vitrail-seed:\s*(#[0-9a-fA-F]{6})\s*-->")
# Channels closer than this read as grey and say nothing about the art.
GREY_SPREAD = 40
# A colour in an SVG: #rgb / #rrggbb (not an id: url(#abc), href="#abc") or rgb().
COLOUR = re.compile(
    r"(?<!url\()(?<!href=\")(?<!href=')(?<![\w&#])#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z])"
    r"|\brgb\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)"
)
ICC_HINT = re.compile(r"\s+icc-color\([^)]*\)")
SVG_TAG = re.compile(r"<svg[\s>]")
# Neutral colours climb from the background outwards; the steps end at these
# distances (0 = the background, 1 = the far end of the art's tonal range).
SURFACE_LADDER = (
    "surface_container_lowest",
    "surface",
    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "outline_variant",
    "outline",
    "on_surface_variant",
    "on_surface",
)
SURFACE_EDGES = (0.10, 0.18, 0.26, 0.34, 0.42, 0.50, 0.60, 0.70, 0.82)
ACCENT_FAMILIES = ("primary", "secondary", "tertiary")
ACCENT_EDGES = (0.20, 0.40, 0.62)
# Hues closer than this (degrees) are one accent family.
HUE_GROUP = 45


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


def next_wallpaper(selection: list[str], current: str, order: str, rng: random.Random | None = None) -> str | None:
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
    """The drawing's seed: its vitrail-seed comment, else the most used colour,
    greys aside."""
    comment = SEED_COMMENT.search(text)
    if comment:
        return comment.group(1).lower()
    counts: Counter[str] = Counter()
    for match in HEX.finditer(text):
        value = match.group(1).lower()
        channels = [int(value[i : i + 2], 16) for i in (0, 2, 4)]
        if max(channels) - min(channels) >= GREY_SPREAD:
            counts["#" + value] += 1
    return counts.most_common(1)[0][0] if counts else None


def _colour_hex(match: re.Match) -> str:
    if match.group(1):
        value = match.group(1)
        if len(value) == 3:
            value = "".join(char * 2 for char in value)
        return "#" + value.lower()
    red, green, blue = (min(255, round(float(match.group(i)))) for i in (2, 3, 4))
    return f"#{red:02x}{green:02x}{blue:02x}"


def _traits(value: str) -> tuple[float, float, bool]:
    """Perceptual lightness 0-1 (CIE L*), hue in degrees, and whether it reads
    as grey."""
    red, green, blue = colors._rgb(value)
    hue = colorsys.rgb_to_hls(red / 255, green / 255, blue / 255)[0] * 360
    y = colors.luminance(value)
    lightness = (903.3 * y if y <= 0.008856 else 116 * y ** (1 / 3) - 16) / 100
    return lightness, hue, max(red, green, blue) - min(red, green, blue) < GREY_SPREAD


def _hue_gap(first: float, second: float) -> float:
    gap = abs(first - second) % 360
    return min(gap, 360 - gap)


def adapt_svg(text: str) -> str:
    """Turns an ordinary SVG into an adaptive one: every colour becomes the
    {{role}} that keeps its place in the tonal structure of the art.

    Neutrals climb the surface ladder by their distance from the art's own
    background; saturated colours fall into up to three hue families
    (primary, secondary, tertiary) and pick container / base / on_container by
    the same distance. The dominant saturated colour is kept as the seed.
    SVGs that already have placeholders, or no colours, are left as they are.
    """
    if PLACEHOLDER.search(text):
        return text
    counts = Counter(_colour_hex(match) for match in COLOUR.finditer(text))
    if not counts:
        return text

    traits = {value: _traits(value) for value in counts}
    total = sum(counts.values())
    dark_art = sum(counts[v] * traits[v][0] for v in counts) / total < 0.5

    def distance(value: str) -> float:
        lightness = traits[value][0]
        return lightness if dark_art else 1 - lightness

    saturated = [value for value in counts if not traits[value][2]]
    centres: list[float] = []
    groups: dict[str, int] = {}
    for value in sorted(saturated, key=lambda v: (-counts[v], v)):
        hue = traits[value][1]
        gaps = [_hue_gap(hue, centre) for centre in centres]
        if (not gaps or min(gaps) >= HUE_GROUP) and len(centres) < len(ACCENT_FAMILIES):
            centres.append(hue)
            gaps.append(0.0)
        groups[value] = gaps.index(min(gaps))
    # The hue family with the most colours leads: it is primary and gives the seed.
    weight = [sum(counts[v] for v in groups if groups[v] == group) for group in range(len(centres))]
    rank = {group: place for place, group in enumerate(sorted(range(len(centres)), key=lambda g: -weight[g]))}
    families = {value: rank[group] for value, group in groups.items()}

    roles = {}
    for value in counts:
        if value in families:
            family = ACCENT_FAMILIES[families[value]]
            step = bisect.bisect(ACCENT_EDGES, distance(value))
            roles[value] = (f"on_{family}", f"{family}_container", family, f"on_{family}_container")[step]
        else:
            roles[value] = SURFACE_LADDER[bisect.bisect(SURFACE_EDGES, distance(value))]

    out = COLOUR.sub(lambda match: "{{" + roles[_colour_hex(match)] + "}}", ICC_HINT.sub("", text))
    if saturated:
        leading = [value for value in saturated if families[value] == 0]
        seed = max(leading, key=lambda v: counts[v] * (max(colors._rgb(v)) - min(colors._rgb(v))))
        tag = SVG_TAG.search(out)
        if tag:
            out = f"{out[: tag.start()]}<!-- vitrail-seed: {seed} -->\n{out[tag.start() :]}"
    return out


def render_svg(text: str, palette: dict[str, str]) -> str:
    """{{role}} placeholders take the palette colour of that role."""
    fallback = palette.get("on_surface", "#ffffff")
    return PLACEHOLDER.sub(lambda match: palette.get(match.group(1), fallback), text)


def system_color(prefs: dict[str, str]) -> str:
    """The fixed colour of the whole system ("" = automatic). The old
    `wallpaperSeed` counts until sync migrates it."""
    return prefs.get("systemColor") or prefs.get("wallpaperSeed", "")


def palette_seed(kind: str, fixed: str, svg_text: str = "") -> str | None:
    """The colour the palette grows from, or None to extract it from the
    image: a fixed system colour wins for every kind; automatic follows the
    image (a video lends a frame) and the SVG's own seed."""
    if fixed:
        return fixed
    if kind == "svg":
        return svg_seed(svg_text) or DEFAULT_SEED
    return None


def library(prefs: dict[str, str], config: Path) -> Path:
    custom = prefs.get("wallpaperDir")
    return Path(custom).expanduser() if custom else config / "wallpapers"


def request_paths(value: str) -> list[str]:
    """The paths of a request; the leading nonce only makes it a new value."""
    return parse_selection(value)[1:]


def parse_monitors(value: str) -> dict[str, dict[str, str]]:
    """The per-output document of `wallpaperMonitors`: an output's picture and
    effect, both optional. Anything malformed reads as no overrides."""
    try:
        data = json.loads(value)
    except (TypeError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    out: dict[str, dict[str, str]] = {}
    for name, entry in data.items():
        if not isinstance(entry, dict):
            continue
        wallpaper = entry.get("wallpaper")
        effect = entry.get("effect")
        out[str(name)] = {
            "wallpaper": wallpaper if isinstance(wallpaper, str) else "",
            "effect": effect if isinstance(effect, str) else "",
        }
    return out


def _free_name(target: Path) -> Path:
    counter = 2
    candidate = target
    while candidate.exists():
        candidate = target.with_name(f"{target.stem}-{counter}{target.suffix}")
        counter += 1
    return candidate


SOURCES = ".sources"
Optimizer = Callable[..., media.Result]
Say = Callable[[str], None]


def _no_say(_line: str) -> None:
    pass


def _sources(base: Path) -> set[str]:
    """Hashes of the files already imported (as the user had them)."""
    try:
        return set((base / SOURCES).read_text(encoding="utf-8").split())
    except OSError:
        return set()


def _add(folders: dict[str, Path], source: Path, optimize: Optimizer, say: Say) -> Path | None:
    """Brings one wallpaper into its kind folder: SVGs are made adaptive,
    images and videos verified and optimized. Never overwrites; a file already
    imported (or whose identical copy is there) is skipped."""
    kind = kind_of(source.name)
    if kind is None or not source.is_file():
        return None
    base = folders[kind].parent
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    if kind == "svg":
        data, suffix = adapt_svg(source.read_text(encoding="utf-8")).encode("utf-8"), source.suffix
        return _store(folders[kind], source, data, suffix)
    if original in _sources(base):
        return None
    with tempfile.TemporaryDirectory() as work:
        result = optimize(source, kind, Path(work), say=say)
        say(result.report.line())
        if result.path is None:
            return None
        target = _store(folders[kind], source, result.path.read_bytes(), result.path.suffix)
    with (base / SOURCES).open("a", encoding="utf-8") as record:
        record.write(original + "\n")
    return target


def _store(folder: Path, source: Path, data: bytes, suffix: str) -> Path | None:
    digest = hashlib.sha256(data).digest()
    for existing in folder.iterdir():
        if existing.is_file() and hashlib.sha256(existing.read_bytes()).digest() == digest:
            return None
    target = _free_name(folder / (source.stem + suffix))
    target.write_bytes(data)
    return target


def import_paths(
    folders: dict[str, Path], paths: list[Path], optimize: Optimizer = media.optimize, say: Say = _no_say
) -> list[Path]:
    """Adds files, and the files directly inside folders, to the library."""
    added: list[Path] = []
    for path in paths:
        for source in sorted(path.iterdir()) if path.is_dir() else [path]:
            target = _add(folders, source, optimize, say)
            if target:
                added.append(target)
    return added


def _migrate_system_color(config: Path, prefs: dict[str, str]) -> None:
    if "wallpaperSeed" in prefs:
        if not prefs.get("systemColor"):
            write_pref(config, "systemColor", prefs["wallpaperSeed"])
        remove_pref(config, "wallpaperSeed")


def _prune_selection(config: Path, prefs: dict[str, str]) -> None:
    """Forgets wallpapers whose file is gone; a missing one on screen gives
    way to the first that remains."""
    selection = parse_selection(prefs.get("wallpaperSelection", ""))
    alive = [path for path in selection if Path(path).is_file()]
    if alive != selection:
        write_pref(config, "wallpaperSelection", join_selection(alive))
    current = prefs.get("wallpaper", "")
    if current and not Path(current).is_file():
        write_pref(config, "wallpaper", alive[0] if alive else "")


def sync(config: Path, optimize: Optimizer = media.optimize) -> tuple[list[Path], list[Path]]:
    """Carries out the settings window's import and removal requests, then
    drops from the selection whatever no longer exists."""
    prefs = read_prefs(config)
    folders = ensure_folders(library(prefs, config))
    imported = import_paths(folders, [Path(path) for path in request_paths(prefs.get("wallpaperImport", ""))], optimize)
    removed: list[Path] = []
    root = library(prefs, config).resolve()
    for path in request_paths(prefs.get("wallpaperRemove", "")):
        target = Path(path).resolve()
        # Only the library's own copies: never a file of the user's.
        if target.is_file() and target.is_relative_to(root):
            target.unlink()
            removed.append(target)
    for key in ("wallpaperImport", "wallpaperRemove"):
        if prefs.get(key):
            write_pref(config, key, "")
    _prune_selection(config, prefs)
    _migrate_system_color(config, prefs)
    return imported, removed


def advance(config: Path) -> str | None:
    """Moves the wallpaper to the next one of the selection."""
    prefs = read_prefs(config)
    current = prefs.get("wallpaper", "")
    chosen = next_wallpaper(
        parse_selection(prefs.get("wallpaperSelection", "")), current, prefs.get("wallpaperOrder", "sequential")
    )
    if chosen and chosen != current:
        write_pref(config, "wallpaper", chosen)
        return chosen
    return None


def apply(
    config: Path,
    cache: Path,
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
    force: bool = False,
    say: Say = _no_say,
) -> str | None:
    """Regenerates the palette when the wallpaper, its effect or the system
    colour changed (always, with `force`). The effect is applied to the picture
    first: the derived file is what the palette is taken from and what the bar
    draws.

    Returns the wallpaper it themed, or None when nothing had to change.
    """
    prefs = read_prefs(config)
    ensure_folders(library(prefs, config))
    path = prefs.get("wallpaper", "")
    kind = kind_of(path)
    if not path or kind is None or not Path(path).is_file():
        return None
    effect = prefs.get("wallpaperEffect", "none")
    fixed = system_color(prefs)
    scheme, contrast = colors.scheme_settings(prefs)
    key = f"{path}{SEPARATOR}{fixed}{SEPARATOR}{scheme}{SEPARATOR}{contrast:g}{SEPARATOR}{effect}"
    stamp = cache / "wallpaper.applied"
    if not force and stamp.exists() and stamp.read_text(encoding="utf-8") == key:
        return None

    cache.mkdir(parents=True, exist_ok=True)
    generated = cache / "generated"
    text = Path(path).read_text(encoding="utf-8") if kind == "svg" else ""
    seed = palette_seed(kind, fixed, text)
    image = effects.derive(Path(path), effect, cache, run=run, say=say)
    if image != Path(path):
        # The bar cannot hash: it draws the stable copy of the derived picture.
        shutil.copyfile(image, effects.shown(cache))
    # Per-monitor effects get their own stable copy for the bar's layer.
    for output, entry in parse_monitors(prefs.get("wallpaperMonitors", "")).items():
        chosen = Path(entry["wallpaper"] or path)
        name = entry["effect"] or effect
        if name in ("", "none") or not chosen.is_file():
            continue
        one = effects.derive(chosen, name, cache, run=run, say=say)
        if one != chosen:
            shutil.copyfile(one, effects.shown(cache, output))
    if kind == "video" and seed is None:
        image = cache / "wallpaper-frame.png"
        run(["ffmpeg", "-loglevel", "error", "-y", "-ss", "1", "-i", path, "-frames:v", "1", str(image)], check=True)

    colors.write_theme(image, generated, scheme=scheme, contrast=contrast, seed=seed, run=run)
    if kind == "svg":
        for mode in ("dark", "light"):
            palette = json.loads((generated / f"theme-{mode}.json").read_text(encoding="utf-8"))
            (generated / f"wallpaper-{mode}.svg").write_text(render_svg(text, palette["colors"]), encoding="utf-8")
    stamp.write_text(key, encoding="utf-8")
    return path
