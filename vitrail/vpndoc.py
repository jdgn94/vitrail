"""The VPN's own storage: a private folder per system user.

    ~/.config/vitrail-vpn/settings.ini     the document Vitrail keeps (0700/0600)
    ~/.local/share/vitrail-vpn/            the OpenVPN files it owns (0700/0600)

Every path follows `$XDG_CONFIG_HOME` / `$XDG_DATA_HOME` (the home when unset),
so two system users never share a file, an account or a rule: each one gets its
own document in its own home. Everything else the VPN keeps — the connections,
credentials and mode in hypraether's vault, the `enabled` marker — is already
hypraether-vpn's and lives under the same home.

The document is one QSettings value, `vpnSettings` in the `[vpn]` section, the
same text that used to live in `misc.ini`: the settings window writes it with
Qt.labs.settings, and this module reads and writes it for the helpers and the
bar. `migrate()` moves the old key out of misc.ini once.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
from pathlib import Path

from . import prefs

# The file and key of the document, and the directory each one lives in.
SETTINGS = "settings.ini"
SETTINGS_SECTION = "vpn"
KEY = "vpnSettings"
CONFIG_NAME = "vitrail-vpn"
DATA_NAME = "vitrail-vpn"
# The old place of the key, in misc.ini; migrate() moves it and deletes it.
LEGACY_KEY = "vpnSettings"
# A picked config is a .ovpn or a .conf, as hypraether-vpn imports them.
SUFFIXES = (".ovpn", ".conf")
MAX_NAME = 120
CHUNK = 1024 * 1024
# Anything a file name cannot keep: the name comes from a path the user picked.
UNSAFE = re.compile(r"[^A-Za-z0-9._-]")


def _home(kind: str) -> Path:
    """`$XDG_CONFIG_HOME` / `$XDG_DATA_HOME` as a folder, the home as fallback."""
    variable = "XDG_CONFIG_HOME" if kind == "config" else "XDG_DATA_HOME"
    found = os.environ.get(variable)
    if found:
        return Path(found)
    home = Path.home()
    return home / ".config" if kind == "config" else home / ".local" / "share"


def config_dir() -> Path:
    """The private folder of the document (~/.config/vitrail-vpn)."""
    return _home("config") / CONFIG_NAME


def data_dir() -> Path:
    """The private folder of the files Vitrail owns (~/.local/share/vitrail-vpn)."""
    return _home("data") / DATA_NAME


def settings_path(folder: Path | None = None) -> Path:
    return (folder or config_dir()) / SETTINGS


def _private_folder(path: Path) -> Path:
    """The folder, created if it does not exist, readable by its owner only."""
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    # An older install (or a copied folder) may be wider: narrow it.
    if (path.stat().st_mode & 0o777) != 0o700:
        os.chmod(path, 0o700)
    return path


def _private_file(path: Path) -> Path:
    try:
        if (path.stat().st_mode & 0o777) != 0o600:
            os.chmod(path, 0o600)
    except FileNotFoundError:
        pass
    return path


def _write_private(path: Path, text: str) -> None:
    """Replaces a file whole, owner-readable only, never half-written."""
    _private_folder(path.parent)
    partial = path.with_name(f".{path.name}.part")
    handle = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as out:
            out.write(text)
            out.flush()
            os.fsync(out.fileno())
    except BaseException:
        partial.unlink(missing_ok=True)
        raise
    os.replace(partial, path)
    os.chmod(path, 0o600)


def qt_quote(text: str) -> str:
    """A value as Qt.labs.settings reads one back: quoted, with `\\` and `"`
    escaped (a string with a comma would be read as a list otherwise)."""
    escaped = (text.replace("\\", "\\\\").replace('"', '\\"')
               .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))
    return f'"{escaped}"'


def document_text(document: dict) -> str:
    return f"[{SETTINGS_SECTION}]\n{KEY}={qt_quote(json.dumps(document, separators=(',', ':')))}\n"


def parse(text: str) -> dict:
    """The document of a settings.ini text; {} when it is missing or broken."""
    value = ""
    for line in text.splitlines():
        key, found, rest = line.partition("=")
        if found and key.strip() == KEY:
            value = _qt_value(rest.strip())
            break
    try:
        document = json.loads(value) if value else {}
    except ValueError:
        return {}
    return document if isinstance(document, dict) else {}


def _qt_value(raw: str) -> str:
    """What Qt stored: quoted and escaped with several entries, escaped but
    unquoted with one (it has no comma), plain otherwise."""
    if raw.startswith('"'):
        return prefs.unquote(raw)
    if raw.startswith('{\\"'):
        return prefs.unquote(f'"{raw}"')
    return raw


def read_doc(folder: Path | None = None) -> dict:
    """The document, narrowing the folder and file to 0700/0600 on the way."""
    path = settings_path(folder)
    if path.parent.exists():
        _private_folder(path.parent)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    _private_file(path)
    return parse(text)


def write_doc(document: dict, folder: Path | None = None) -> Path:
    """Writes the document where Qt.labs.settings will read it back."""
    path = settings_path(folder)
    _write_private(path, document_text(document))
    return path


def ensure(folder: Path | None = None, data: Path | None = None) -> None:
    """Creates the two private folders (a fresh install, or after a removal)."""
    _private_folder(folder or config_dir())
    _private_folder(data or data_dir())


def migrate(config: Path | None = None, folder: Path | None = None) -> bool:
    """Moves `vpnSettings` out of misc.ini once; creates the private folders.

    The old key is deleted whatever happens — an existing document wins, so a
    second launch applies nothing twice. Returns whether anything changed.
    """
    config = config or prefs.config_dir()
    path = settings_path(folder)
    changed = False
    if not path.exists():
        legacy = prefs.read_prefs(config).get(LEGACY_KEY, "")
        document: dict = {}
        if legacy:
            try:
                found = json.loads(legacy)
            except ValueError:
                found = None
            document = found if isinstance(found, dict) else {}
        write_doc(document, folder)
        changed = True
    if LEGACY_KEY in prefs.read_prefs(config):
        prefs.remove_pref(config, LEGACY_KEY)
        changed = True
    if not data_dir().exists():
        changed = True
    ensure(folder)
    return changed


def _digest(path: Path) -> str:
    found = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(CHUNK), b""):
            found.update(block)
    return found.hexdigest()


def file_name(source: Path) -> str:
    """The name a picked file keeps in the private folder: its own, flattened
    (no separator, no leading dot) and with the suffix the tool expects."""
    if source.suffix.lower() not in SUFFIXES:
        raise ValueError(f"not an OpenVPN config: {source.name}")
    stem, suffix = source.stem, source.suffix.lower()
    stem = UNSAFE.sub("_", stem).lstrip(".")[:MAX_NAME] or "connection"
    return stem + suffix


def _free(folder: Path, name: str) -> Path:
    candidate, counter = folder / name, 1
    while candidate.exists():
        candidate = folder / f"{Path(name).stem}-{counter}{Path(name).suffix}"
        counter += 1
    return candidate


def store_file(source: Path, move: bool = False, folder: Path | None = None) -> Path:
    """Copies a picked .ovpn/.conf into the private data folder (0600), checks
    the copy, and only then removes the original when `move` is set. Returns the
    private path."""
    source = Path(source)
    if not source.is_file():
        raise OSError(f"no such file: {source}")
    name = file_name(source)
    folder = _private_folder(folder or data_dir())
    if source.parent == folder and source.name == name:
        _private_file(source)
        return source
    target = folder / name
    if target.exists():
        target = target if _digest(target) == _digest(source) else _free(folder, name)
    shutil.copyfile(source, target)
    os.chmod(target, 0o600)
    if _digest(target) != _digest(source):
        target.unlink(missing_ok=True)
        raise OSError(f"the copy of {source.name} did not match")
    if move:
        source.unlink()
    return target
