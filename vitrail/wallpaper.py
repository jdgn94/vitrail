"""Wallpaper library: one folder per kind and a selection of a single kind
that rotates.

The library lives in the config folder (~/.config/vitrail/wallpapers), apart
from the user's own pictures. The settings window cannot touch files, so it
asks: `wallpaperImport` / `wallpaperRemove` hold "<nonce>|path|path…" and
sync() copies or deletes, then clears the request.

Kinds never mix: the selection holds images or videos, and the colour
extraction follows the wallpaper on screen (a video lends one frame).
"""

from __future__ import annotations

import hashlib
import json
import random
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Callable

from vitrail import colors, effects, fonts, media
from vitrail.prefs import read_prefs, remove_pref, write_pref

KINDS = {
    "image": (".png", ".jpg", ".jpeg", ".webp", ".bmp"),
    "video": (".mp4", ".webm", ".mkv", ".mov", ".m4v", ".avi", ".gif"),
}
FOLDERS = {"image": "images", "video": "videos"}
SEPARATOR = "|"


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


def system_color(prefs: dict[str, str]) -> str:
    """The fixed colour of the whole system ("" = automatic). The old
    `wallpaperSeed` counts until sync migrates it."""
    return prefs.get("systemColor") or prefs.get("wallpaperSeed", "")


def palette_seed(fixed: str) -> str | None:
    """The colour the palette grows from, or None to extract it from the
    image: a fixed system colour wins; automatic follows the image (a video
    lends a frame)."""
    return fixed or None


def library(prefs: dict[str, str], config: Path) -> Path:
    custom = prefs.get("wallpaperDir")
    return Path(custom).expanduser() if custom else config / "wallpapers"


def request_paths(value: str) -> list[str]:
    """The paths of a request; the leading nonce only makes it a new value."""
    return parse_selection(value)[1:]


def parse_monitors(value: str) -> dict[str, dict[str, str]]:
    """The per-output document of `wallpaperMonitors`: the picture one output
    shows instead of the global one. Anything malformed reads as no override;
    the effect is global and applies to whichever picture the output shows."""
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
        out[str(name)] = {"wallpaper": wallpaper if isinstance(wallpaper, str) else ""}
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
    """Brings one wallpaper into its kind folder: images and videos verified
    and optimized. Never overwrites; a file already imported (or whose
    identical copy is there) is skipped."""
    kind = kind_of(source.name)
    if kind is None or not source.is_file():
        return None
    base = folders[kind].parent
    original = hashlib.sha256(source.read_bytes()).hexdigest()
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
    """Forgets wallpapers whose file is gone or whose kind no longer exists;
    a missing one on screen gives way to the first that remains."""
    selection = parse_selection(prefs.get("wallpaperSelection", ""))
    alive = [path for path in selection if kind_of(path) and Path(path).is_file()]
    if alive != selection:
        write_pref(config, "wallpaperSelection", join_selection(alive))
    current = prefs.get("wallpaper", "")
    if current and (kind_of(current) is None or not Path(current).is_file()):
        write_pref(config, "wallpaper", alive[0] if alive else "")
    kind = prefs.get("wallpaperType", "")
    if kind and kind not in KINDS:
        write_pref(config, "wallpaperType", "")


def sync(config: Path, optimize: Optimizer = media.optimize) -> tuple[list[Path], list[Path]]:
    """Carries out the settings window's import and removal requests, then
    drops from the selection whatever no longer exists or is no longer a
    wallpaper kind."""
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


def pick(config: Path, path: str) -> str | None:
    """Shows one wallpaper at once (the launcher's choice). Another kind starts
    a new selection; one of the current kind joins it."""
    if kind_of(path) is None or not Path(path).is_file():
        return None
    prefs = read_prefs(config)
    selection = parse_selection(prefs.get("wallpaperSelection", ""))
    if prefs.get("wallpaperType") != kind_of(path):
        selection = [path]
    elif path not in selection:
        selection.append(path)
    write_pref(config, "wallpaperType", kind_of(path) or "")
    write_pref(config, "wallpaperSelection", join_selection(selection))
    write_pref(config, "wallpaper", path)
    return path


def _shown_copies(cache: Path, path: Path, effect: str, monitors: dict[str, dict[str, str]]) -> list[Path]:
    """The picture files the bar draws for these prefs: the global effect copy
    and one for every output with a picture of its own."""
    copies = []
    if effect not in ("", "none") and effects.is_image(path):
        copies.append(effects.shown(cache))
    for output, entry in monitors.items():
        picture = Path(entry["wallpaper"])
        if entry["wallpaper"] and effect not in ("", "none") and effects.is_image(picture):
            copies.append(effects.shown(cache, output))
    return copies


def _preview_file(cache: Path, path: Path) -> list[Path]:
    """The plain file that proves the picker's previews were published. A
    recipe magick refuses is left out of the grid, so requiring every one of
    them would redo the pass forever."""
    if not effects.is_image(path):
        return []
    return [cache / effects.PREVIEWS / "global" / "none.png"]


def _shown_image(
    picture: Path,
    effect: str,
    cache: Path,
    run: Callable[..., subprocess.CompletedProcess],
    say: Say,
    mode: str = "light",
    detail: str = "normal",
) -> Path | None:
    """The picture the bar draws for one output with `effect`: the derived
    file, or the plain picture when magick refuses it. None when the output
    takes no copy (no effect, a video, a file that is gone)."""
    if effect in ("", "none") or not picture.is_file():
        return None
    try:
        image = effects.derive(picture, effect, cache, run=run, say=say, mode=mode, detail=detail)
    except (subprocess.CalledProcessError, OSError):
        say(f"The {effect} effect was refused for {picture.name}: shown as it is")
        return picture if effects.is_image(picture) else None
    # `derive` answers with the picture itself for a kind that takes no effect.
    return image if effects.is_image(picture) else None


def apply(
    config: Path,
    cache: Path,
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
    force: bool = False,
    say: Say = _no_say,
) -> str | None:
    """Regenerates the palette when the wallpaper, its effect, the per-output
    pictures or the system colour changed (always, with `force`). The effect is
    applied to the picture first: the derived file is what the palette is taken
    from and what the bar draws — each output with a picture of its own gets
    the same effect over it. The settings window's previews are refreshed in
    the same pass.

    Returns the wallpaper it themed, or None when nothing had to change.
    """
    prefs = read_prefs(config)
    ensure_folders(library(prefs, config))
    path = prefs.get("wallpaper", "")
    kind = kind_of(path)
    if not path or kind is None or not Path(path).is_file():
        return None
    effect = prefs.get("wallpaperEffect", "none")
    # Two effects are drawn differently in dark mode; the stamp and the cache
    # must say so, or switching the theme would keep the old picture.
    mode = fonts.active_mode(prefs.get("appearance", "auto"))
    detail = prefs.get("wallpaperEffectDetail", "normal")
    monitors_text = prefs.get("wallpaperMonitors", "")
    monitors = parse_monitors(monitors_text)
    fixed = system_color(prefs)
    scheme, contrast = colors.scheme_settings(prefs)
    key = (
        f"{path}{SEPARATOR}{fixed}{SEPARATOR}{scheme}{SEPARATOR}{contrast:g}"
        f"{SEPARATOR}{effect}{SEPARATOR}{effects.style(effect, mode, detail)}"
        f"{SEPARATOR}{effects.VERSION}{SEPARATOR}{monitors_text}"
    )
    stamp = cache / "wallpaper.applied"
    # A copy the bar points at may have been lost (a cleared cache): rebuild
    # it instead of leaving the layer blank.
    ready = _shown_copies(cache, Path(path), effect, monitors) + _preview_file(cache, Path(path))
    if (
        not force
        and stamp.exists()
        and stamp.read_text(encoding="utf-8") == key
        and all(item.exists() for item in ready)
    ):
        return None

    cache.mkdir(parents=True, exist_ok=True)
    generated = cache / "generated"
    seed = palette_seed(fixed)
    # The bar cannot hash: it draws the stable copy of the derived picture.
    shown = _shown_image(Path(path), effect, cache, run, say, mode, detail)
    # A drawn style repaints the picture over a canvas, so its palette is taken
    # from the photo itself; a recipe tints it, and the palette follows it.
    image = Path(path) if effect in effects.STYLED or shown is None else shown
    if shown is not None:
        shutil.copyfile(shown, effects.shown(cache))
    # Per-output pictures carry the same effect: their own stable copy for the
    # bar's layer.
    for output, entry in monitors.items():
        if not entry["wallpaper"]:
            continue
        one = _shown_image(Path(entry["wallpaper"]), effect, cache, run, say, mode, detail)
        if one is not None:
            shutil.copyfile(one, effects.shown(cache, output))
    # The settings window's picker: a small copy per effect of the picture the
    # whole screen shows. A video takes none. A copy that cannot be made (a
    # refused recipe, no font to draw with) costs the thumbnail, never the
    # wallpaper.
    try:
        effects.publish(Path(path), cache, run=run, mode=mode, detail=detail)
    except (OSError, subprocess.CalledProcessError) as error:
        say(f"The effect previews could not be drawn: {error}")
    if kind == "video" and seed is None:
        image = cache / "wallpaper-frame.png"
        run(["ffmpeg", "-loglevel", "error", "-y", "-ss", "1", "-i", path, "-frames:v", "1", str(image)], check=True)

    colors.write_theme(image, generated, scheme=scheme, contrast=contrast, seed=seed, run=run)
    stamp.write_text(key, encoding="utf-8")
    return path
