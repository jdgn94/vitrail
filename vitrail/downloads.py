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

    python3 -m vitrail.downloads watch      # started with the bar
"""

from __future__ import annotations

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
    "firefox": "Firefox", "firefox-bin": "Firefox", "librewolf": "LibreWolf",
    "chrome": "Google Chrome", "google-chrome": "Google Chrome", "chromium": "Chromium",
    "brave": "Brave", "vivaldi-bin": "Vivaldi", "opera": "Opera",
    "wget": "wget", "curl": "curl", "aria2c": "aria2", "transmission-gtk": "Transmission",
    "transmission-qt": "Transmission", "qbittorrent": "qBittorrent", "steam": "Steam",
    "mega-cmd": "MEGA", "yt-dlp": "yt-dlp",
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
        return (say("downloads.summary.done", item.name),
                with_app(say("downloads.body.done", human_size(item.size), human_time(item.duration))))
    if kind == "cancelling":
        return say("downloads.summary.cancelling", item.name), say("downloads.body.cancelling")
    if kind == "cancelled":
        return (say("downloads.summary.cancelled"),
                with_app(say("downloads.body.cancelled", human_time(item.duration), human_size(item.size))))
    if kind == "busy":
        return say("downloads.summary.busy", item.name), say("downloads.body.busy")
    if kind == "deleted":
        return say("downloads.summary.done", item.name), say("downloads.body.deleted")
    return (say("downloads.summary.failed", item.name),
            with_app(say("downloads.body.gone", human_size(item.size))))


def actions_for(kind: str, language: str | None = None) -> list[str]:
    say = lambda key: t(key, language=language)  # noqa: E731
    if kind == "finished":
        return [DELETE, say("downloads.action.delete"),
                FOLDER, say("downloads.action.folder"),
                FILE, say("downloads.action.file")]
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

    def send(self, summary: str, body: str, actions: list[str] | None = None,
             hints: dict | None = None, replace: int = 0, timeout: int = 0) -> int:
        import dbus

        if self.iface is None:
            self.attach(dbus.SessionBus())
        mapped = dbus.Dictionary(signature="sv")
        for key, value in (hints or {}).items():
            mapped[key] = dbus.Int32(value) if isinstance(value, int) else dbus.String(str(value))
        return int(self.iface.Notify(self.app, dbus.UInt32(replace), self.icon, summary, body,
                                     dbus.Array(actions or [], signature="s"), mapped,
                                     dbus.Int32(timeout)))


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
        nid = self.notifier.send(summary, body, actions_for(kind, self.language),
                                 hints_for(item), replace=item.nid or 0)
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
        bus.add_signal_receiver(self.on_action, signal_name="ActionInvoked",
                                dbus_interface=SERVICE, path=PATH)
        GLib.timeout_add(int(poll * 1000), self.tick)
        GLib.MainLoop().run()


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["watch"]:
        Daemon(Watcher(), Notifier()).run()
        return 0
    print("usage: downloads watch", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
