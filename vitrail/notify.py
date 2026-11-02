"""What the notification centre remembers: history, stats and snooze wake-ups.

The bar keeps the cards, but the panel must survive a reload, so its rows and
the per-app count live in one file of its own:

    ~/.local/state/vitrail/notifications.json  (0700/0600)

    {"history": [{arrived, summary, body, appName, icon, image, conversation,
                  urgent, acted}],
     "stats": {"2026-11-01": {"Telegram Desktop": [seen, acted]}}}

The history is bounded (a few hundred rows) and the stats to the last days, so
the file never grows without end. `send` brings a snoozed notification back as
a new one on the bar's server.

    python3 -m vitrail.notify store <json>   # the bar replaces the file
    python3 -m vitrail.notify show           # print it
    python3 -m vitrail.notify send <json>    # {app, icon, summary, body}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

LIMIT = 300
STATS_DAYS = 30
FIELDS = ("summary", "body", "appName", "icon", "image", "conversation")
MAX_TEXT = 4096
STORE = "notifications.json"


def state_dir() -> Path:
    """`$XDG_STATE_HOME` (the spec's place for what a program remembers)."""
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "vitrail"


def store_path(folder: Path | None = None) -> Path:
    return (folder or state_dir()) / STORE


def _private(folder: Path) -> Path:
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    if (folder.stat().st_mode & 0o777) != 0o700:
        os.chmod(folder, 0o700)
    return folder


def _text(value: object) -> str:
    return str(value)[:MAX_TEXT] if value is not None else ""


def normalise_row(row: object) -> dict | None:
    """One history row, keeping what the panel draws; None for an empty one."""
    if not isinstance(row, dict):
        return None
    found = {key: _text(row.get(key, "")) for key in FIELDS}
    if not found["summary"] and not found["body"]:
        return None
    try:
        arrived = int(row.get("arrived") or 0)
    except (TypeError, ValueError):
        arrived = 0
    return found | {
        "arrived": max(0, arrived),
        "urgent": row.get("urgent") is True,
        "acted": row.get("acted") is True,
    }


def normalise_stats(stats: object) -> dict[str, dict[str, list[int]]]:
    """{day: {app: [seen, acted]}} with whole numbers, the newest days kept."""
    if not isinstance(stats, dict):
        return {}
    found: dict[str, dict[str, list[int]]] = {}
    for day, apps in stats.items():
        if not isinstance(day, str) or not isinstance(apps, dict):
            continue
        per_app = {}
        for app, pair in apps.items():
            if not isinstance(pair, list) or len(pair) != 2:
                continue
            try:
                per_app[_text(app)] = [max(0, int(pair[0])), max(0, int(pair[1]))]
            except (TypeError, ValueError):
                continue
        if per_app:
            found[day] = per_app
    return dict(sorted(found.items())[-STATS_DAYS:])


def normalise(document: object) -> dict:
    """A document the history can be rebuilt from: bounded and safe to draw."""
    if not isinstance(document, dict):
        return {"history": [], "stats": {}}
    rows = [row for row in (normalise_row(one) for one in document.get("history") or [])
            if row is not None]
    return {"history": rows[:LIMIT], "stats": normalise_stats(document.get("stats"))}


def load(folder: Path | None = None) -> dict:
    try:
        text = store_path(folder).read_text(encoding="utf-8")
    except OSError:
        return {"history": [], "stats": {}}
    try:
        return normalise(json.loads(text))
    except ValueError:
        return {"history": [], "stats": {}}


def save(document: dict, folder: Path | None = None) -> Path:
    """Replaces the file whole, readable by its owner only."""
    path = store_path(folder)
    _private(path.parent)
    text = json.dumps(normalise(document), ensure_ascii=False, separators=(",", ":"))
    partial = path.with_name(f".{path.name}.part")
    handle = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        out.write(text)
    os.replace(partial, path)
    os.chmod(path, 0o600)
    return path


def send(payload: dict, notifier=None) -> int:
    """Brings one back as a new notification (a snooze that is due)."""
    if not isinstance(payload, dict):
        raise ValueError("send takes an object")
    if notifier is None:
        from .downloads import Notifier

        notifier = Notifier(app=_text(payload.get("app")) or "Vitrail",
                            icon=_text(payload.get("icon")) or "notifications")
    return notifier.send(_text(payload.get("summary")) or "Vitrail",
                         _text(payload.get("body")), [], {}, 0, 0)


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args[:1] == ["store"] and len(args) <= 2:
        # The bar writes the document on the process's stdin, one line (it is
        # too long for one argument); the command line may pass it directly.
        raw = args[1] if len(args) == 2 else sys.stdin.readline()
        try:
            save(json.loads(raw or "{}"))
        except ValueError:
            print("notify: the store takes a JSON document", file=sys.stderr)
            return 2
        return 0
    if args == ["show"]:
        print(json.dumps(load(), ensure_ascii=False, separators=(",", ":")))
        return 0
    if len(args) == 2 and args[0] == "send":
        try:
            send(json.loads(args[1]))
        except ValueError:
            return 2
        return 0
    print("usage: notify store [json] | show | send <json>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
