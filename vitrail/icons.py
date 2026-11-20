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
# Bumped when the generated layer changes shape (the SVG tint or the index
# metadata): the stamp then rebuilds themes an older build wrote.
ICON_VERSION = 5
# A generated layer can carry a fill style after `@`: plain (the pack's own
# folder shading, hue-shifted), a light body, or a solid primary body.
STYLES = ("", "light", "solid")
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


def design_name(pack: str, style: str = "") -> str:
    """`vitrail-icons-<pack>` plus `@light` / `@solid` when asked."""
    suffix = f"@{style}" if style in STYLES and style else ""
    return PREFIX + pack + suffix


def split_design(name: str) -> tuple[str, str]:
    """(pack, style) of a generated name; ("", "") for a plain pack."""
    if not name.startswith(PREFIX) or len(name) == len(PREFIX):
        return "", ""
    rest = name[len(PREFIX) :]
    pack, at, style = rest.rpartition("@")
    if at and style in STYLES and style:
        return pack, style
    return rest, ""


def source_of(name: str) -> str:
    return split_design(name)[0]


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


def _layout(infos: list[zipfile.ZipInfo], fallback: str, cursors: bool = False) -> tuple[str, str, str]:
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
    if cursors:
        if not any(name.startswith(base + "cursors/") for name in files):
            raise ValueError("the zip has index.theme but no cursors/ folder")
        return prefix, name, index
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
    cursors: bool = False,
    root: Path | None = None,
) -> Path:
    """Installs one validated theme from `path`; returns where it landed.

    An icon pack needs `<theme>/index.theme` and at least one icon in a size
    folder; a cursor pack needs `<theme>/index.theme` and a `cursors/` folder.
    Paths are checked before anything is written, the archive is unpacked into
    a staging folder inside `root`, and an earlier copy of the same theme moves
    to BACKUP_DIR before the new one takes its place.
    """
    path = Path(path)
    infos = _check_archive(path, max_bytes)
    prefix, theme, index = _layout(infos, path.stem, cursors=cursors)
    root = Path(root) if root is not None else _writable_root(data_home)
    target = root / theme
    with zipfile.ZipFile(path) as archive:
        _index_theme(archive, index)
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


def remove_pack(
    name: str,
    data_home: Path | None = None,
    home: Path | None = None,
    cursors: bool = False,
    roots: list[Path] | None = None,
) -> Path:
    """Deletes one pack from the user's folders; never from /usr/share/icons."""
    theme = _safe_name(name)
    if cursors and theme.startswith("vitrail-"):
        raise ValueError(f"{theme!r} is generated by Vitrail")
    candidates = [Path(root) for root in roots] if roots is not None else user_roots(data_home, home)
    for root in candidates:
        candidate = root / theme
        if not candidate.is_dir() or not (candidate / "index.theme").is_file():
            continue
        if cursors and not (candidate / "cursors").is_dir():
            continue
        # A symlink into the system themes is a view, not the user's copy.
        try:
            candidate.resolve().relative_to(root.resolve())
        except ValueError:
            continue
        shutil.rmtree(candidate)
        return candidate
    kind = "cursor theme" if cursors else "icon pack"
    raise ValueError(f"{theme!r} is not a user-installed {kind}")


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


def tint_svg(text: str, palette: dict, style: str = "") -> str:
    """Recolours the folder body towards `primary`, keeping the outline.

    `""` hue-shifts every body shade (the pack's own light/dark reading is
    preserved). `light` paints the body as a pale tint of `primary`; `solid`
    paints it as `primary` itself. Colours outside the body hue window
    (outlines, symbols) are never touched.
    """
    style = style if style in STYLES else ""
    anchor = body(text)
    primary = palette.get("primary")
    if not primary or not HEX.match(primary):
        return text
    if anchor is None:
        # A symbolic folder fills with `currentColor` and carries its palette
        # in a CSS `color:` rule. Give the path the system colour directly;
        # otherwise the icon keeps the theme's grey/blue.
        target = primary
        if style == "light":
            hue, _lightness, saturation = _hsl(primary)
            target = _hex(hue, 0.85, max(0.35, min(0.60, saturation)))
        return re.sub(
            r"""(?i)(fill\s*[:=]\s*["']?)currentColor""",
            lambda match: f"{match.group(1)}{target}",
            text,
        )
    anchor_hue = _hsl(anchor)[0]
    anchor_lightness = _hsl(anchor)[1]
    target_hue, _primary_light, primary_saturation = _hsl(primary)
    if style == "light":
        flat = _hex(target_hue, 0.85, max(0.35, min(0.60, primary_saturation)))
    elif style == "solid":
        flat = primary
    else:
        flat = ""

    def replace(match: re.Match) -> str:
        value = match.group(3)
        if not HEX.match(value):
            return match.group(0)
        hue, lightness, saturation = _hsl(value)
        # The body shades sit near the anchor's lightness. A dark symbol or a
        # neutral outline is not body: recolouring it would erase the
        # document/download/music symbol of a special folder.
        if saturation < 0.25 or abs(lightness - anchor_lightness) > 0.25:
            return match.group(0)
        distance = abs(hue - anchor_hue)
        distance = min(distance, 1 - distance)
        if distance * 360 > HUE_WINDOW:
            return match.group(0)
        body_colour = flat or _hex(target_hue, lightness, saturation)
        return f"{match.group(1)}{match.group(2)}{body_colour}"

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
    """(source, path inside the theme) for every folder SVG the pack has.

    The pack's own directories win over its parents: a parent theme can carry a
    generic folder under another size directory (`places/64`), and GTK would
    pick it over the pack's special icon (`64x64/places/folder-documents.svg`),
    losing the download/document/music symbol. A parent is used only when the
    pack itself has no folder art, so thin packs still produce a layer.
    """
    wanted = {name.casefold() for name in NAMES}

    def scan(theme: Path) -> dict[str, Path]:
        sections = _sections(theme / "index.theme")
        directories = [
            part.strip() for part in sections.get("Icon Theme", {}).get("Directories", "").split(",") if part.strip()
        ]
        found: dict[str, Path] = {}
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
                found.setdefault(str(path.relative_to(theme)), path)
        return found

    found = scan(pack)
    # A parent can supply folder art the pack does not have (`folder-open`),
    # but it must never shadow a stem the pack defines: that is how a generic
    # `places/64/folder-documents.svg` used to replace the pack's special icon.
    stems = {Path(relative).name[:-4].split("@")[0].casefold() for relative in found}
    for theme in _chain(pack, roots):
        if theme == pack:
            continue
        for relative, path in scan(theme).items():
            stem = Path(relative).name[:-4].split("@")[0].casefold()
            if stem in stems or relative in found:
                continue
            found[relative] = path
    return [(source, relative) for relative, source in sorted(found.items())]


def _directory_sections(pack: Path, roots: list[Path], directories: set[str]) -> dict[str, dict[str, str]]:
    """The `[size/context]` metadata for the directories the layer writes.

    GTK only indexes a directory that has its own section; without them the
    generated theme is skipped and the app falls back to `Inherits`, showing
    the pack's original folder colours.
    """
    found: dict[str, dict[str, str]] = {}
    for theme in _chain(pack, roots):
        for name, values in _sections(theme / "index.theme").items():
            if name == "Icon Theme" or name not in directories or name in found:
                continue
            found[name] = values
    return found


def _fallback_section(name: str) -> dict[str, str]:
    """Enough metadata for a directory the pack did not describe."""
    size = next(
        (part.split("x")[0] for part in name.split("/") if re.fullmatch(r"\d+x\d+", part)),
        "48",
    )
    if "places" in name:
        context = "Places"
    elif "actions" in name:
        context = "Actions"
    else:
        context = "Applications"
    return {"Size": size, "Type": "Threshold", "Context": context}


def build(
    pack: Path,
    target: Path,
    palette: dict,
    cache: Path,
    roots: list[Path],
    force: bool = False,
    style: str = "",
) -> bool:
    """Writes the folder layer of `pack`, tinted; False when already current."""
    files = folder_files(pack, roots)
    if not files:
        return False
    style = style if style in STYLES else ""
    stamp = cache / "stamp"
    current = hashlib.sha256(
        json.dumps(
            {
                "pack": str(pack),
                "primary": palette.get("primary", ""),
                "style": style,
                "version": ICON_VERSION,
            },
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()
    if not force and (target / "index.theme").is_file() and stamp.is_file():
        try:
            if stamp.read_text(encoding="utf-8").strip() == current:
                return False
        except OSError:
            pass

    # The layer is exactly the current pack: stale files from an older build
    # (or a parent theme's generic folder) must not win GTK's lookup.
    if target.is_symlink():
        target.unlink()
    elif target.is_dir():
        shutil.rmtree(target)

    for source, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            text = source.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        destination.write_text(tint_svg(text, palette, style), encoding="utf-8")

    directories = sorted({str(Path(relative).parent) for _s, relative in files})
    sections = _directory_sections(pack, roots, set(directories))
    lines = [
        "[Icon Theme]",
        f"Name=Vitrail icons · {pack.name}" + (f" ({style})" if style else ""),
        f"Comment=Vitrail's palette on the {pack.name} folders",
        f"Inherits={pack.name}",
        "Directories=" + ",".join(directories),
    ]
    for directory in directories:
        lines.extend(("", f"[{directory}]"))
        for key, value in sections.get(directory, _fallback_section(directory)).items():
            lines.append(f"{key}={value}")
    (target / "index.theme").write_text("\n".join(lines) + "\n", encoding="utf-8")
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
