"""The sample bar element's data: the pattern every element's Python side follows.

    python3 -m vitrail.sample state

One JSON object on stdout, always, and never a traceback:

    {"counter": 3, "updated": 1763750000}      a snapshot
    {"error": "cache"}                         what went wrong, as a short code
                                               (a snapshot may carry it too)

The state is cached in ~/.cache/vitrail/sample.json for 5 minutes, so the bar
may poll as often as it likes. There are words only in the QML (translated); the
snapshot holds numbers and codes. Exit status is 0 for a usable snapshot and 1
for one with an `error`. No network, no programs.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

CACHE_FILE = "sample.json"
CACHE_SECONDS = 5 * 60


def cache_file(folder: Path | None = None) -> Path:
    base = folder or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "vitrail"
    return base / CACHE_FILE


def load_cache(path: Path) -> dict | None:
    """The stored entry `{"saved_at": float, "state": {"counter": int, ...}}`, or None."""
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(stored, dict) or not isinstance(stored.get("saved_at"), (int, float)):
        return None
    state = stored.get("state")
    if not isinstance(state, dict) or not isinstance(state.get("counter"), int):
        return None
    return stored


def save_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.part")
    partial.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, path)


def state(cache: Path | None = None, now: float | None = None) -> dict:
    """A snapshot, cached for CACHE_SECONDS: `{"counter", "updated"}`.

    When the cache cannot be written the snapshot still comes back, with
    `error: "cache"`.
    """
    path = cache_file(cache)
    stored = load_cache(path)
    now = time.time() if now is None else now

    if stored and 0 <= now - stored["saved_at"] < CACHE_SECONDS:
        return stored["state"]

    result = {"counter": stored["state"]["counter"] + 1 if stored else 1, "updated": int(now)}
    try:
        save_cache(path, {"saved_at": now, "state": result})
    except OSError:
        result["error"] = "cache"
    return result


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        data = state()
        print(json.dumps(data, separators=(",", ":")))
        return 1 if "error" in data else 0
    print("usage: sample state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
