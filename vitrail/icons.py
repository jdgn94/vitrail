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
import shutil
import sys
import tempfile
import time
import zipfile
from pathlib import Path

PREFIX = "vitrail-icons-"
# A pack imported from a zip lands here, in the user's own icon folder; an
# earlier copy moves to BACKUP_DIR first, so replacing is never destructive.
BACKUP_DIR = ".vitrail-backups"
MAX_ZIP_BYTES = 64 * 1024 * 1024
MAX_ZIP_FILES = 10_000
ICON_SUFFIXES = (".svg", ".png", ".xpm", ".jpg", ".jpeg", ".webp")
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
    return _writable_root()


def _data_home(data_home: Path | None = None) -> Path:
    if data_home is not None:
        return Path(data_home)
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")


def _writable_root(data_home: Path | None = None) -> Path:
    return _data_home(data_home) / "icons"


def user_roots(data_home: Path | None = None, home: Path | None = None) -> list[Path]:
    """The folders whose packs Vitrail may remove; never /usr/share/icons."""
    home = Path(home) if home is not None else Path.home()
    return [_writable_root(data_home), home / ".icons"]


def _safe_name(name: str, what: str = "name") -> str:
    """A single folder name: no separators, no traversal, no control chars."""
    name = str(name).strip()
    if (
        not name
        or name in (".", "..")
        or "/" in name
        or "\\" in name
        or "\0" in name
        or any(ord(char) < 32 for char in name)
        or len(name) > 128
    ):
        raise ValueError(f"invalid icon pack {what}: {name!r}")
    return name


def _member(name: str) -> str:
    """A zip member as a safe relative path, or ValueError."""
    raw = name.rstrip("/")
    if not raw or raw.startswith("/") or "\\" in raw or "\0" in raw or re.match(r"^[A-Za-z]:", raw):
        raise ValueError(f"unsafe path in zip: {name!r}")
    parts = raw.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"unsafe path in zip: {name!r}")
    return "/".join(parts)


def _check_archive(path: Path, max_bytes: int) -> list[zipfile.ZipInfo]:
    """The members of a zip, after checking every path and its total size."""
    try:
        archive = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as error:
        raise ValueError(f"not a readable .zip: {error}") from None
    with archive:
        infos = archive.infolist()
        if len(infos) > MAX_ZIP_FILES:
            raise ValueError(f"zip has too many files (max {MAX_ZIP_FILES})")
        total = 0
        for info in infos:
            _member(info.filename)
            if info.flag_bits & 1:
                raise ValueError("encrypted zips are not supported")
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f"unsafe path in zip: {info.filename!r} is a symbolic link")
            total += info.file_size
            if total > max_bytes:
                raise ValueError(f"zip is too large (max {max_bytes // (1024 * 1024)} MiB uncompressed)")
    return infos


def _layout(infos: list[zipfile.ZipInfo], fallback: str) -> tuple[str, str, str]:
    """(theme folder in the zip, install name, index.theme path)."""
    files = [_member(info.filename) for info in infos if not info.is_dir()]
    names = set(files)
    if "index.theme" in names:
        prefix = ""
        name = _safe_name(fallback)
        index = "index.theme"
    else:
        tops = {name.split("/", 1)[0] for name in files if "/" in name}
        candidates = sorted(top for top in tops if f"{top}/index.theme" in names)
        if len(candidates) != 1:
            raise ValueError("the zip needs <theme>/index.theme (one theme) or index.theme at its root")
        prefix = candidates[0]
        name = _safe_name(prefix)
        index = f"{prefix}/index.theme"
        outside = [name for name in files if not name.startswith(prefix + "/")]
        if outside:
            raise ValueError(f"the zip holds files outside {prefix}/: {outside[0]}")
    base = f"{prefix}/" if prefix else ""
    icons = [
        name[len(base) :]
        for name in files
        if name != index and name.startswith(base) and Path(name).suffix.lower() in ICON_SUFFIXES
    ]
    # A pack is found by its subfolders (48x48/apps…), so an icon at the theme
    # root alone would install a theme the machine never lists.
    if not any("/" in relative for relative in icons):
        raise ValueError("the zip has index.theme but no icon files in a size folder (.svg, .png, .xpm, .jpg, .webp)")
    return prefix, name, index


def _index_theme(archive: zipfile.ZipFile, index: str) -> None:
    try:
        text = archive.read(index).decode("utf-8", errors="replace")
    except (KeyError, OSError) as error:
        raise ValueError(f"could not read {index}: {error}") from None
    if "[Icon Theme]" not in text:
        raise ValueError(f"{index} has no [Icon Theme] section")


def _backup(target: Path) -> Path:
    root = target.parent / BACKUP_DIR
    root.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    candidate = root / f"{target.name}-{stamp}"
    counter = 1
    while candidate.exists():
        candidate = root / f"{target.name}-{stamp}-{counter}"
        counter += 1
    shutil.move(str(target), str(candidate))
    return candidate


def import_zip(
    path: Path | str,
    data_home: Path | None = None,
    name: str | None = None,
    max_bytes: int = MAX_ZIP_BYTES,
) -> Path:
    """Installs one validated icon pack from `path`; returns where it landed.

    The zip must hold `<theme>/index.theme` (or a root `index.theme`) and at
    least one icon. Paths are checked before anything is written, the archive
    is unpacked into a staging folder inside the icon root, and an earlier copy
    of the same theme moves to BACKUP_DIR before the new one takes its place.
    """
    path = Path(path)
    infos = _check_archive(path, max_bytes)
    prefix, theme, index = _layout(infos, path.stem)
    target = _writable_root(data_home) / theme
    with zipfile.ZipFile(path) as archive:
        _index_theme(archive, index)
        root = _writable_root(data_home)
        root.mkdir(parents=True, exist_ok=True)
        staging = Path(tempfile.mkdtemp(prefix=".vitrail-import-", dir=root))
        backup: Path | None = None
        try:
            total = 0
            for info in infos:
                relative = _member(info.filename)
                if info.is_dir():
                    continue
                if prefix:
                    relative = relative[len(prefix) + 1 :]
                if not relative:
                    continue
                destination = staging / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as source, destination.open("wb") as output:
                    while chunk := source.read(64 * 1024):
                        total += len(chunk)
                        if total > max_bytes:
                            raise ValueError(f"zip is too large (max {max_bytes // (1024 * 1024)} MiB uncompressed)")
                        output.write(chunk)
            if target.exists():
                backup = _backup(target)
            shutil.move(str(staging), str(target))
            staging = None
        except BaseException:
            if staging is not None:
                shutil.rmtree(staging, ignore_errors=True)
            if backup is not None and not target.exists():
                shutil.move(str(backup), str(target))
            raise
    return target


def remove_pack(name: str, data_home: Path | None = None, home: Path | None = None) -> Path:
    """Deletes one pack from the user's folders; never from /usr/share/icons."""
    theme = _safe_name(name)
    for root in user_roots(data_home, home):
        candidate = root / theme
        if not candidate.is_dir() or not (candidate / "index.theme").is_file():
            continue
        # A symlink into the system themes is a view, not the user's copy.
        try:
            candidate.resolve().relative_to(root.resolve())
        except ValueError:
            continue
        shutil.rmtree(candidate)
        return candidate
    raise ValueError(f"{theme!r} is not a user-installed icon pack")


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
