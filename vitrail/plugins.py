"""Plugin discovery for the Vitrail shell.

A plugin is a directory with a `plugin.json` manifest and a QML entry file.
Plugins run inside the Vitrail process, so they are trusted code: there is no
sandbox, exactly like Quickshell or VS Code extensions.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REQUIRED = ("name", "version", "entry")


def plugin_roots() -> list[Path]:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return [data_home / "vitrail" / "plugins", Path("/usr/share/vitrail/plugins")]


def discover() -> list[dict]:
    found: list[dict] = []
    seen: set[str] = set()
    for root in plugin_roots():
        if not root.is_dir():
            continue
        for manifest in sorted(root.glob("*/plugin.json")):
            try:
                data = json.loads(manifest.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if any(key not in data for key in REQUIRED):
                continue
            name = str(data["name"])
            if name in seen:
                continue
            seen.add(name)
            entry = (manifest.parent / str(data["entry"])).resolve()
            if not entry.is_file():
                continue
            found.append(
                {
                    "name": name,
                    "version": str(data.get("version", "")),
                    "description": str(data.get("description", "")),
                    "author": str(data.get("author", "")),
                    "path": str(manifest.parent),
                    "entry": str(entry),
                }
            )
    return found


def lock_path() -> Path:
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config / "vitrail" / "plugins.lock.json"


def write_lock() -> Path:
    target = lock_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": 1,
        "plugins": [
            {key: plugin[key] for key in ("name", "version", "entry")}
            for plugin in discover()
        ],
    }
    target.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return target


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    action = args[0] if args else "index"
    if action == "index":
        print(json.dumps(discover()))
        return 0
    if action == "lock":
        target = write_lock()
        print(f"Lock written to {target}")
        return 0
    print("usage: plugins [index|lock]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
