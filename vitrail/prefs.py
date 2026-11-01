"""Preferences: one INI file per area under ~/.config/vitrail/.

`prefs.map` says which file holds each key (appearance.ini, bar.ini,
wallpaper.ini…); a key it does not list lives in misc.ini. Everything that
reads or writes a preference goes through this module by key, so no caller
knows the file layout. The old single settings.ini is split once by migrate().
"""

from __future__ import annotations

import fcntl
import os
from pathlib import Path

MAP = Path(__file__).with_name("prefs.map")
MISC = "misc"
LEGACY = "settings.ini"
BACKUP = "settings.ini.before-split"

# Bumped when the files change shape. migrate() stamps it; validate() refuses
# to reason about files written by a newer Vitrail.
SCHEMA = 3
SCHEMA_FILE = "schema"

# Key -> the values it may take, for the settings the launcher's actions change.
CHOICES = {
    "appearance": {"light", "dark", "auto"},
    "surfaceStyle": {"glass", "solid"},
}

# Keys that take a number inside a range. `clipboardMax` is what the clipboard
# store keeps: 50 is the least that is still useful, 1000 the most the panel
# can list without a search.
RANGES = {
    "clipboardMax": (50, 1000),
}


def parse_map(text: str) -> list[tuple[str, str]]:
    """The (file, key) pairs of a map; a key listed twice is an error."""
    pairs: list[tuple[str, str]] = []
    seen: set[str] = set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, key = line.split()
        if key in seen:
            raise ValueError(f"{key} is listed in more than one file")
        seen.add(key)
        pairs.append((name, key))
    return pairs


PAIRS = parse_map(MAP.read_text(encoding="utf-8"))
FILES = list(dict.fromkeys([*(name for name, _key in PAIRS), MISC]))
_FILE_OF = {key: name for name, key in PAIRS}


def config_dir() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return base / "vitrail"


def file_of(key: str) -> str:
    return _FILE_OF.get(key, MISC)


def schema_version(config: Path) -> int:
    try:
        return int((config / SCHEMA_FILE).read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return 0


def write_schema(config: Path, version: int = SCHEMA) -> None:
    config.mkdir(parents=True, exist_ok=True)
    (config / SCHEMA_FILE).write_text(f"{version}\n", encoding="utf-8")


def validate(config: Path) -> list[str]:
    """Problems with the preference files: unknown, misplaced or future keys.

    Values are never touched: a key the map does not list is reported, not
    deleted, because it may belong to a plugin or to a newer Vitrail.
    """
    issues: list[str] = []
    version = schema_version(config)
    if version > SCHEMA:
        issues.append(
            f"settings were written by a newer Vitrail (schema {version} > {SCHEMA})"
        )
    for path in sorted(config.glob("*.ini")):
        name = path.stem
        for key, _value in _items(_read_text(path)):
            owner = _FILE_OF.get(key)
            if owner is None:
                if name != MISC:
                    issues.append(f"{key} is not in prefs.map (found in {path.name})")
            elif owner != name:
                issues.append(f"{key} belongs in {owner}.ini, found in {path.name}")
    return issues


def _items(text: str) -> list[tuple[str, str]]:
    """The key=value lines of an INI text, whatever their section."""
    items = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line[0] in "#;[" or "=" not in line:
            continue
        key, _, value = line.partition("=")
        items.append((key.strip(), value.strip()))
    return items


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def read_prefs(config: Path) -> dict[str, str]:
    """Every preference of every file, merged."""
    merged: dict[str, str] = {}
    for name in FILES:
        merged.update(_items(_read_text(config / f"{name}.ini")))
    return merged


def _replace(path: Path, text: str) -> None:
    # The settings watchers must never see a half-written file.
    temporary = path.with_name(f".{path.name}.part")
    temporary.write_text(text, encoding="utf-8")
    os.replace(temporary, path)


def _write_keys(config: Path, name: str, values: dict[str, str]) -> None:
    """Sets keys of one file in one atomic write, leaving other lines be."""
    path = config / f"{name}.ini"
    lines = _read_text(path).splitlines()
    pending = dict(values)
    for index, line in enumerate(lines):
        key = line.partition("=")[0].strip()
        if "=" in line and key in pending and line.strip()[0] not in "#;[":
            lines[index] = f"{key}={pending.pop(key)}"
    if not any(line.strip().startswith("[") for line in lines):
        lines.insert(0, f"[{name}]")
    lines.extend(f"{key}={value}" for key, value in pending.items())
    config.mkdir(parents=True, exist_ok=True)
    _replace(path, "\n".join(lines) + "\n")


def check(key: str, value: str) -> None:
    """Raises ValueError when the key does not take that value."""
    if key not in RANGES:
        return
    low, high = RANGES[key]
    try:
        number = int(str(value).strip())
    except (TypeError, ValueError):
        raise ValueError(f"{key} takes a number between {low} and {high}") from None
    if not low <= number <= high:
        raise ValueError(f"{key} must be between {low} and {high}")


def write_pref(config: Path, key: str, value: str) -> None:
    check(key, value)
    _write_keys(config, file_of(key), {key: value})


def remove_pref(config: Path, key: str) -> None:
    """Drops one key from its file, leaving every other line be."""
    path = config / f"{file_of(key)}.ini"
    lines = _read_text(path).splitlines()
    kept = [line for line in lines if line.partition("=")[0].strip() != key]
    if kept != lines:
        _replace(path, "\n".join(kept) + "\n")


def set_pref(key: str, value: str, config: Path | None = None) -> None:
    """Writes one of the CHOICES, leaving every other key alone."""
    if value not in CHOICES.get(key, set()):
        raise ValueError(f"{key} does not take {value!r}")
    write_pref(config or config_dir(), key, value)


def _unique(path: Path) -> Path:
    candidate, counter = path, 1
    while candidate.exists():
        candidate = path.with_name(f"{path.name}.{counter}")
        counter += 1
    return candidate


def _normalise_positions(config: Path) -> bool:
    """`notificationPosition` is left/right now; old values carried a top/bottom."""
    path = config / "bar.ini"
    text = _read_text(path)
    if not text:
        return False
    changed = False
    for key, value in _items(text):
        if key != "notificationPosition":
            continue
        side = "left" if "left" in value else "right"
        if value != side:
            write_pref(config, key, side)
            changed = True
    return changed


def migrate(config: Path) -> bool:
    """Splits a legacy settings.ini into the per-area files, once.

    Safe to run from several places at the same time and again after an
    interruption: a lock serialises runs, files already split keep their
    values, each file is written atomically, and the legacy file is renamed to
    its backup last. Returns whether there was anything to migrate.
    """
    changed = _normalise_positions(config)
    legacy = config / LEGACY
    if not legacy.exists():
        if changed:
            write_schema(config)
        return changed
    with (config / ".migrate.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not legacy.exists():
            return False
        by_file: dict[str, dict[str, str]] = {}
        for key, value in _items(legacy.read_text(encoding="utf-8")):
            by_file.setdefault(file_of(key), {})[key] = value
        for name, values in by_file.items():
            present = dict(_items(_read_text(config / f"{name}.ini")))
            missing = {key: value for key, value in values.items() if key not in present}
            if missing:
                _write_keys(config, name, missing)
        os.replace(legacy, _unique(config / BACKUP))
        write_schema(config)
    return True
