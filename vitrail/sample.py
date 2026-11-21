"""A minimal bar element data module: pattern for new bar elements.

    python3 -m vitrail.sample state

Returns a small JSON snapshot cached for 5 minutes. No network, no programs.
The bar element reads this via a Process in shell.qml (see bar/sample/).
"""

from __future__ import annotations

import json
import os
import time
from pathlib import Path

CACHE_FILE = "sample.json"
CACHE_SECONDS = 5 * 60


def cache_file(folder: Path | None = None) -> Path:
    base = folder or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "vitrail"
    return base / CACHE_FILE


def load_cache(path: Path) -> dict | None:
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return stored if isinstance(stored, dict) else None


def save_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.part")
    partial.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, path)


def state(cache: Path | None = None, now: float | None = None) -> dict:
    """A small state snapshot, cached for CACHE_SECONDS.

    Returns {"message": str, "counter": int, "updated": int}.
    """
    path = cache_file(cache)
    stored = load_cache(path)
    now = time.time() if now is None else now

    if stored and isinstance(stored.get("saved_at"), (int, float)):
        if 0 <= now - stored["saved_at"] < CACHE_SECONDS:
            return stored["state"]

    counter = stored["state"]["counter"] + 1 if stored and isinstance(stored.get("state"), dict) else 1
    result = {
        "message": f"Sample element · run #{counter}",
        "counter": counter,
        "updated": int(now),
    }
    save_cache(path, {"saved_at": now, "state": result})
    return result


def main(argv: list[str] | None = None) -> int:
    import sys

    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(), separators=(",", ":")))
        return 0
    print("usage: sample state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    import sys

    raise SystemExit(main())
