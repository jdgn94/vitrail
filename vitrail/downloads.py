"""Downloads as live notifications.

There is no D-Bus "downloads" API, so this watches the XDG download folders for
the files a downloader is still writing (`.part`, `.crdownload`, `.download`,
`.tmp`), measures them, and keeps one notification per download on the bar's
own notification server, replaced in place as the file grows.

What it can and cannot show: a downloader does not publish its total, so the
percentage is there only when the file was reserved at its final size (the
size is larger than the blocks written, `measure`); otherwise the card shows an
indeterminate bar with the size, the speed and the elapsed time — never a made
up percentage. A finished file is the partial name without its suffix, next to
it.

Actions come back as D-Bus signals: Cancel removes the partial file (that is
what aborts the download; if the app keeps writing it says so rather than
pretending), Delete removes the finished file, Open folder and Open file use
the desktop's own file manager (`vitrail/files.py`).

The bar element does not run the daemon: it asks for one JSON snapshot per
poll and draws it itself, and its Cancel button calls the same rule through
the `cancel` command. Both are one-shot, so the little state a snapshot needs
between polls (when a download started, its last size, the finished ones) is
cached in `~/.cache/vitrail/downloads-state.json`.

    python3 -m vitrail.downloads watch      # started with the bar
    python3 -m vitrail.downloads state      # one snapshot for the bar element
    python3 -m vitrail.downloads cancel PATH  # the partial file, never another
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import sys
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

from . import files, prefs

# The suffixes a downloader writes while it works, and the app that usually
# leaves each one (used when no process can be seen holding the file).
TEMP = (".part", ".crdownload", ".download", ".tmp")
BY_SUFFIX = {".crdownload": "Chromium", ".part": "Firefox", ".download": "Safari", ".tmp": ""}
# Process names worth a nicer label.
BY_PROCESS = {
    "firefox": "Firefox",
    "firefox-bin": "Firefox",
    "librewolf": "LibreWolf",
    "chrome": "Google Chrome",
    "google-chrome": "Google Chrome",
    "chromium": "Chromium",
    "brave": "Brave",
    "vivaldi-bin": "Vivaldi",
    "opera": "Opera",
    "wget": "wget",
    "curl": "curl",
    "aria2c": "aria2",
    "transmission-gtk": "Transmission",
    "transmission-qt": "Transmission",
    "qbittorrent": "qBittorrent",
    "steam": "Steam",
    "mega-cmd": "MEGA",
    "yt-dlp": "yt-dlp",
}

# One scan a second; the speed covers the last few seconds of samples.
POLL = 1.0
WINDOW = 5.0
# A cancelled file may still be written for a moment; after this long the
# answer is real (cancelled, or the app is still writing).
CANCEL_WAIT = 2.0
# A partial file older than this is not being written any more (a leftover).
STALE = 86400.0
# The bar's notification service (Quickshell's NotificationServer).
SERVICE = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"
APP = "Vitrail"
ICON = "folder-download"
# The bar's cards read these.
STATE_HINT = "x-vitrail-state"
# The action keys the card invokes (the bar finds them by identifier).
CANCEL = "cancel"
DELETE = "delete"
FOLDER = "folder"
FILE = "file"
# The bar element's one-shot snapshot keeps a small history between polls: how
# many finished downloads survive, and where it remembers them.
STATE_CACHE = "downloads-state.json"
RECENT_MAX = 20


def human_size(size: float) -> str:
    """Bytes as a downloader prints them: 999 B, 1.0 KB, 12.4 MB."""
    units = ("B", "KB", "MB", "GB", "TB", "PB")
    value = float(max(0, size))
    for index, unit in enumerate(units):
        if value < 1000 or index == len(units) - 1:
            return f"{value:.0f} {unit}" if index == 0 else f"{value:.1f} {unit}"
        value /= 1000
    return "0 B"


def human_time(seconds: float) -> str:
    """0:07, 1:02:03."""
    total = max(0, int(seconds))
    hours, rest = divmod(total, 3600)
    minutes, seconds = divmod(rest, 60)
    return f"{hours}:{minutes:02d}:{seconds:02d}" if hours else f"{minutes}:{seconds:02d}"


def final_of(path: Path) -> Path:
    """The file a partial one becomes: its name without the downloader's suffix."""
    name = path.name
    for suffix in TEMP:
        if name.lower().endswith(suffix) and len(name) > len(suffix):
            return path.with_name(name[: -len(suffix)])
    return path.with_name(name + ".download")


def measure(path: Path) -> tuple[int, int | None]:
    """(bytes written, total when known). A downloader that reserves the final
    size (a sparse file) says the total through the file itself; a growing one
    does not, and no percentage is invented."""
    stat = path.stat()
    written = stat.st_blocks * 512
    if stat.st_size > written:
        return min(written, stat.st_size), stat.st_size
    return stat.st_size, None


def download_dirs(home: Path | None = None, config: Path | None = None) -> list[Path]:
    """The XDG download folders: `user-dirs.dirs` first, `~/Downloads` always.
    The home itself is never watched (it is not a downloads folder)."""
    home = home or Path.home()
    config = config or (Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config"))
    found: list[Path] = []
    try:
        text = (config / "user-dirs.dirs").read_text(encoding="utf-8")
    except OSError:
        text = ""
    for line in text.splitlines():
        if not line.startswith("XDG_DOWNLOAD_DIR="):
            continue
        value = line.partition("=")[2].strip().strip('"').replace("$HOME", str(home))
        if value.startswith("/"):
            found.append(Path(value))
    found.append(home / "Downloads")
    kept: list[Path] = []
    for folder in found:
        if folder in (home, Path("/")) or folder in kept:
            continue
        kept.append(folder)
    return kept


def holder(path: Path) -> str:
    """The process holding the file open (`comm`), "" when none is visible."""
    target = os.path.realpath(path)
    try:
        processes = list(Path("/proc").iterdir())
    except OSError:
        return ""
    for process in processes:
        if not process.name.isdigit():
            continue
        try:
            descriptors = list((process / "fd").iterdir())
        except OSError:
            continue
        for descriptor in descriptors:
            try:
                link = os.readlink(descriptor)
            except OSError:
                continue
            if link == target or link.startswith(target + " (deleted)"):
                try:
                    return (process / "comm").read_text(encoding="utf-8").strip()
                except OSError:
                    return ""
    return ""


def app_name(path: Path, finder=holder) -> str:
    """The app downloading it: the process holding the file, else what its
    suffix usually means; "" when neither says."""
    process = finder(path)
    if process:
        return BY_PROCESS.get(process, process.capitalize())
    return BY_SUFFIX.get(path.suffix.lower(), "")


@dataclass
class Download:
    """One file being downloaded (or just finished)."""

    path: Path
    final: Path
    app: str
    first: float
    size: int = 0
    total: int | None = None
    speed: float = 0.0
    state: str = "live"
    duration: float = 0.0
    nid: int | None = None
    samples: deque = field(default_factory=lambda: deque(maxlen=32))
    reported: str = ""

    @property
    def name(self) -> str:
        return self.final.name

    def percent(self) -> int | None:
        if not self.total or self.total <= 0:
            return None
        return max(0, min(100, int(self.size * 100 / self.total)))


class Watcher:
    """The files on disk, scanned: which started, grew, finished or stopped."""

    def __init__(self, dirs: list[Path] | None = None, clock=time.monotonic, app=app_name):
        self.dirs = download_dirs() if dirs is None else dirs
        self.clock = clock
        self.app_of = app
        self.live: dict[Path, Download] = {}
        self.cancelled: dict[Path, float] = {}

    def temp_files(self) -> list[Path]:
        found: list[Path] = []
        cutoff = time.time() - STALE
        for folder in self.dirs:
            try:
                entries = list(folder.iterdir())
            except OSError:
                continue
            for path in entries:
                if not path.name.lower().endswith(TEMP):
                    continue
                try:
                    if not path.is_file() or path.stat().st_mtime < cutoff:
                        continue
                except OSError:
                    continue
                found.append(path)
        return found

    def scan(self) -> list[tuple[str, Download]]:
        """Every change since the last scan: ("started"|"updated"|"finished"|
        "cancelled"|"gone"|"busy", download)."""
        now = self.clock()
        events: list[tuple[str, Download]] = []
        present = set(self.temp_files())
        for path in present:
            since = self.cancelled.get(path)
            if since is not None and now - since >= CANCEL_WAIT:
                # The app recreated it after the removal: it is being written
                # again, not cancelled.
                self.cancelled.pop(path, None)
            size, total = measure(path)
            item = self.live.get(path)
            if item is None:
                item = Download(path=path, final=final_of(path), app=self.app_of(path), first=now)
                self.live[path] = item
                item.size, item.total = size, total
                item.samples.append((now, size))
                events.append(("started", item))
                continue
            item.size, item.total = size, total
            item.duration = now - item.first
            item.samples.append((now, size))
            while item.samples and now - item.samples[0][0] > WINDOW:
                item.samples.popleft()
            item.speed = self.speed(item, now)
            if item.state == "cancelling" and (since is None or now - since >= CANCEL_WAIT):
                item.state = "busy"
                events.append(("busy", item))
            elif item.state == "busy":
                if item.reported != str(item.size):
                    item.reported = str(item.size)
                    events.append(("updated", item))
            elif item.state != "cancelling":
                events.append(("updated", item))
        for path, item in list(self.live.items()):
            if path in present:
                continue
            since = self.cancelled.get(path)
            if since is not None and now - since < CANCEL_WAIT:
                continue
            del self.live[path]
            item.duration = now - item.first
            if item.final.is_file():
                item.size = item.final.stat().st_size
                item.state = "done"
                events.append(("finished", item))
            elif since is not None:
                item.state = "cancelled"
                events.append(("cancelled", item))
            else:
                item.state = "gone"
                events.append(("gone", item))
        return events

    @staticmethod
    def speed(item: Download, now: float) -> float:
        if len(item.samples) < 2:
            return item.speed
        first_at, first_size = item.samples[0]
        span = now - first_at
        if span < 0.2:
            return item.speed
        return max(0.0, (item.size - first_size) / span)

    def cancel(self, item: Download) -> None:
        """Removes the partial file: that is what aborts the download. The next
        scan says whether it worked (cancelled) or the app kept writing (busy)."""
        self.cancelled[item.path] = self.clock()
        item.state = "cancelling"
        try:
            item.path.unlink()
        except OSError:
            pass


def cancel_partial(path: Path, dirs: list[Path] | None = None) -> bool:
    """Remove one downloader's part file, and nothing else.

    The bar element is read-only: its Cancel button is a click that reaches this
    rule. A path outside the download folders, or a name without one of the
    downloader suffixes (a finished file, a user's document), is refused.
    """
    try:
        target = Path(path)
    except TypeError:
        return False
    if target.suffix.lower() not in TEMP or not target.is_file():
        return False
    folders = [folder.resolve() for folder in (dirs if dirs is not None else download_dirs())]
    try:
        parent = target.resolve().parent
    except OSError:
        return False
    if parent not in folders:
        return False
    try:
        target.unlink()
    except OSError:
        return False
    return True


# --- the bar element's snapshot ---------------------------------------------


def state_cache_file(folder: Path | None = None) -> Path:
    base = folder or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "vitrail"
    return base / STATE_CACHE


def download_id(path: Path) -> str:
    """A stable id for one download: the same on every poll, and after it ends."""
    return hashlib.sha1(str(path).encode("utf-8")).hexdigest()[:16]


def load_state(path: Path) -> dict:
    """The stored history, or an empty one. A broken file is data, not a crash."""
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"active": [], "recent": []}
    if not isinstance(stored, dict):
        return {"active": [], "recent": []}
    active = stored.get("active")
    recent = stored.get("recent")
    return {"active": active if isinstance(active, list) else [], "recent": recent if isinstance(recent, list) else []}


def save_state(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.part")
    partial.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, path)


def _number(value: object, fallback: float = 0.0) -> float:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return fallback


def active_entry(item: Download, first: float, now: float, speed: float) -> dict:
    """One running download: numbers and short codes, no words (the QML has them)."""
    return {
        "id": download_id(item.path),
        "name": item.name,
        "path": str(item.path),
        "final": str(item.final),
        "folder": str(item.final.parent),
        "size": int(item.size),
        "total": int(item.total) if item.total else None,
        "percent": item.percent(),
        "speed": round(max(0.0, speed), 1),
        "elapsed": round(max(0.0, now - first), 1),
        "app": item.app,
        "state": item.state if item.state in ("cancelling", "busy") else "live",
        # A finished name may exist while the part file is still there (a
        # downloader copying into place); Open file waits for it.
        "finalExists": item.final.is_file(),
    }


def recent_entry(path: Path, final: Path, size: int, app: str, finished_at: float) -> dict:
    """One finished download, with the final file the buttons open."""
    return {
        "id": download_id(path),
        "name": final.name,
        "path": str(final),
        "folder": str(final.parent),
        "size": int(size),
        "app": app,
        "finishedAt": round(finished_at, 3),
        "state": "done",
    }


def state(
    dirs: list[Path] | None = None,
    cache: Path | None = None,
    watcher: Watcher | None = None,
    now: float | None = None,
    limit: int = RECENT_MAX,
) -> dict:
    """One snapshot for the bar element: `{"active", "recent", "updated"}`.

    A fresh process every poll, so the few things a one-shot scan cannot know
    are remembered in the cache: when each download started (elapsed), its last
    size and time (speed), and the finished ones (recent). `limit` caps that
    history; the settings window asks for a smaller slice of the same list.
    """
    path = state_cache_file(cache)
    stored = load_state(path)
    now = time.time() if now is None else float(now)
    watcher = watcher or Watcher(dirs)
    error = ""
    try:
        watcher.scan()
    except OSError:
        # A file disappearing between the listing and its measurement is a
        # scan that lost the race: the next poll sees the truth.
        error = "scan"

    previous: dict[str, dict] = {}
    for record in stored["active"]:
        if isinstance(record, dict) and isinstance(record.get("path"), str):
            previous[record["path"]] = record

    active: list[dict] = []
    kept: list[dict] = []
    for item in watcher.live.values():
        before = previous.get(str(item.path))
        first = _number(before.get("first"), now) if before else now
        speed = 0.0
        if before:
            span = now - _number(before.get("at"), now)
            if span > 0:
                speed = max(0.0, (item.size - _number(before.get("size"), item.size)) / span)
        entry = active_entry(item, first, now, speed)
        active.append(entry)
        kept.append(
            {
                "id": entry["id"],
                "path": str(item.path),
                "final": str(item.final),
                "first": first,
                "size": int(item.size),
                "at": now,
                "app": item.app,
            }
        )

    recent = [
        record
        for record in stored["recent"]
        if isinstance(record, dict) and isinstance(record.get("id"), str) and isinstance(record.get("path"), str)
    ]
    seen = {record["id"] for record in recent}
    live = {str(item.path) for item in watcher.live.values()}
    for partial, before in previous.items():
        if partial in live:
            continue
        final = Path(str(before.get("final") or ""))
        if not final.is_file():
            continue
        entry = recent_entry(Path(partial), final, final.stat().st_size, str(before.get("app") or ""), now)
        if entry["id"] not in seen:
            recent.insert(0, entry)
            seen.add(entry["id"])
    recent = recent[: max(0, int(limit))]

    result: dict = {"active": active, "recent": recent, "updated": round(now, 3)}
    if error:
        result["error"] = error
    try:
        save_state(path, {"saved_at": now, "active": kept, "recent": recent})
    except OSError:
        result["error"] = "cache"
    return result


# --- the words (kit/i18n, so the card is translated) -------------------------
I18N = Path(__file__).resolve().parent.parent / "kit" / "i18n"
_TABLES: dict[str, dict] = {}


def table(language: str | None = None, config: Path | None = None) -> dict:
    """The strings of the settings' language, English as the fallback."""
    code = language or prefs.read_prefs(config or prefs.config_dir()).get("language", "en") or "en"
    if code not in _TABLES:
        for candidate in (code, "en"):
            try:
                _TABLES[code] = json.loads((I18N / f"{candidate}.json").read_text(encoding="utf-8"))
                break
            except (OSError, ValueError):
                continue
        else:
            _TABLES[code] = {}
    return _TABLES[code]


def t(key: str, *values: object, language: str | None = None) -> str:
    text = table(language).get(key, key)
    for index, value in enumerate(values, 1):
        text = text.replace(f"%{index}", str(value))
    return text


# --- the notification --------------------------------------------------------


def announce_text(kind: str, item: Download, language: str | None = None) -> tuple[str, str]:
    """(summary, body) of one change, in the user's language. The app, when it
    was recognized, leads the body; the summary is the file."""
    say = lambda key, *values: t(key, *values, language=language)  # noqa: E731

    def with_app(text: str) -> str:
        return f"{item.app} · {text}" if item.app else text

    if kind in ("started", "updated"):
        summary = say("downloads.summary.live", item.name)
        parts = [human_size(item.size)]
        if item.total:
            parts = [say("downloads.body.of", human_size(item.size), human_size(item.total))]
        parts += [say("downloads.speed", human_size(item.speed)), human_time(item.duration or 0)]
        return summary, with_app(" · ".join(parts))
    if kind == "finished":
        return (
            say("downloads.summary.done", item.name),
            with_app(say("downloads.body.done", human_size(item.size), human_time(item.duration))),
        )
    if kind == "cancelling":
        return say("downloads.summary.cancelling", item.name), say("downloads.body.cancelling")
    if kind == "cancelled":
        return (
            say("downloads.summary.cancelled"),
            with_app(say("downloads.body.cancelled", human_time(item.duration), human_size(item.size))),
        )
    if kind == "busy":
        return say("downloads.summary.busy", item.name), say("downloads.body.busy")
    if kind == "deleted":
        return say("downloads.summary.done", item.name), say("downloads.body.deleted")
    return (say("downloads.summary.failed", item.name), with_app(say("downloads.body.gone", human_size(item.size))))


def actions_for(kind: str, language: str | None = None) -> list[str]:
    say = lambda key: t(key, language=language)  # noqa: E731
    if kind == "finished":
        return [
            DELETE,
            say("downloads.action.delete"),
            FOLDER,
            say("downloads.action.folder"),
            FILE,
            say("downloads.action.file"),
        ]
    if kind == "deleted":
        return [FOLDER, say("downloads.action.folder"), FILE, say("downloads.action.file")]
    if kind in ("live", "started", "updated", "cancelling", "busy"):
        return [CANCEL, say("downloads.action.cancel")]
    return []


def hints_for(item: Download) -> dict:
    found = {STATE_HINT: item.state}
    percent = item.percent()
    if percent is not None:
        found["value"] = percent
    return found


class Notifier:
    """Sends to the bar's notification server (Quickshell) over the session bus."""

    def __init__(self, bus=None, app: str = APP, icon: str = ICON):
        self.bus = bus
        self.app = app
        self.icon = icon
        self.iface = None
        if bus is not None:
            self.attach(bus)

    def attach(self, bus) -> None:
        self.bus = bus
        self.iface = self.bus.get_object(SERVICE, PATH)

    def send(
        self,
        summary: str,
        body: str,
        actions: list[str] | None = None,
        hints: dict | None = None,
        replace: int = 0,
        timeout: int = 0,
    ) -> int:
        import dbus

        if self.iface is None:
            self.attach(dbus.SessionBus())
        mapped = dbus.Dictionary(signature="sv")
        for key, value in (hints or {}).items():
            mapped[key] = dbus.Int32(value) if isinstance(value, int) else dbus.String(str(value))
        return int(
            self.iface.Notify(
                self.app,
                dbus.UInt32(replace),
                self.icon,
                summary,
                body,
                dbus.Array(actions or [], signature="s"),
                mapped,
                dbus.Int32(timeout),
            )
        )


class Daemon:
    """The watcher, the notifications and the actions of their buttons."""

    def __init__(self, watcher: Watcher, notifier, open_path=files.open_path, language: str | None = None):
        self.watcher = watcher
        self.notifier = notifier
        self.open_path = open_path
        self.language = language
        self.by_id: dict[int, Download] = {}
        self.order: deque = deque(maxlen=64)

    def step(self) -> list[tuple[str, Download]]:
        events = self.watcher.scan()
        for kind, item in events:
            self.announce(kind, item)
        return events

    def announce(self, kind: str, item: Download) -> int | None:
        item.state = {"started": "live", "updated": "live", "finished": "done"}.get(kind, kind)
        summary, body = announce_text(kind, item, self.language)
        nid = self.notifier.send(
            summary, body, actions_for(kind, self.language), hints_for(item), replace=item.nid or 0
        )
        item.nid = nid
        self.by_id[nid] = item
        self.order.append(nid)
        while len(self.by_id) > self.order.maxlen:
            gone = self.order.popleft()
            self.by_id.pop(gone, None)
        print(f"Downloads: {kind} {item.name} #{nid}", flush=True)
        return nid

    def on_action(self, nid, key) -> None:
        item = self.by_id.get(int(nid))
        if item is None:
            return
        key = str(key)
        if key == CANCEL:
            self.watcher.cancel(item)
            self.announce("cancelling", item)
        elif key == DELETE:
            try:
                item.final.unlink()
            except OSError:
                pass
            self.announce("deleted", item)
        elif key == FOLDER:
            self.open_path(item.final.parent)
        elif key == FILE:
            self.open_path(item.final)

    def tick(self) -> bool:
        try:
            self.step()
        except Exception as error:  # never let one bad file stop the watcher
            print(f"Downloads: {error}", flush=True)
        return True

    def run(self, poll: float = POLL) -> None:
        import dbus
        import dbus.mainloop.glib
        from gi.repository import GLib

        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SessionBus()
        self.notifier.attach(bus)
        bus.add_signal_receiver(self.on_action, signal_name="ActionInvoked", dbus_interface=SERVICE, path=PATH)
        GLib.timeout_add(int(poll * 1000), self.tick)
        GLib.MainLoop().run()


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["watch"]:
        # A reload of the bar can leave the previous watcher alive for a
        # moment: one watcher per session, or every file is announced twice.
        lock = acquire_lock()
        if lock is None:
            return 0
        Daemon(Watcher(), Notifier()).run()
        return 0
    if args == ["state"]:
        data = state()
        print(json.dumps(data, separators=(",", ":")))
        return 1 if "error" in data else 0
    if len(args) == 2 and args[0] == "cancel":
        return 0 if cancel_partial(Path(args[1])) else 1
    print("usage: downloads watch | state | cancel PATH", file=sys.stderr)
    return 2


def acquire_lock(folder: Path | None = None):
    """An exclusive lock on the session's watcher; None when another one holds it."""
    runtime = folder or Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    try:
        handle = (runtime / "vitrail-downloads.lock").open("w")
    except OSError:
        return None
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        handle.close()
        return None
    return handle


if __name__ == "__main__":
    raise SystemExit(main())
