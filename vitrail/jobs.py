"""One small API for long tasks in the notification centre.

The same card a download uses serves any long job — a file copy, a package
update, a compression, `rsync` — with the same bar, the same Cancel and the
same finished state:

    from vitrail.jobs import Job

    with Job("Copying photos") as job:
        for done, path in work:
            job.update(done, total)

    python3 -m vitrail.jobs run --name "Updating pacman" -- pacman -Syu

The bar needs nothing of its own: a job is a notification whose
`x-vitrail-state` hint is `live` until it ends, with a `value` hint when the
total is known (indeterminate otherwise) and a `cancel` action while it runs.
On the command line the action stops the child process.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

from .downloads import CANCEL, STATE_HINT, Notifier, t

DEFAULT_APP = "Vitrail"
DEFAULT_ICON = "sync"
POLL = 1.0
# Where a running job leaves its name for the session guard (the bar's power
# menu asks `vitrail.session` before cutting work). The runtime folder goes
# away with the session; a dead pid is pruned.
REGISTRY = "vitrail-jobs"


def job_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(base) / REGISTRY


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def jobs_running(folder: Path | None = None) -> list[dict]:
    """[{pid, name, app, started}] of the jobs still running; a stale file is
    removed on the way."""
    folder = folder or job_dir()
    found: list[dict] = []
    try:
        entries = sorted(folder.glob("*.json"))
    except OSError:
        return found
    for path in entries:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        pid = data.get("pid") if isinstance(data, dict) else None
        if not isinstance(pid, int) or not _alive(pid):
            path.unlink(missing_ok=True)
            continue
        found.append({"pid": pid, "name": str(data.get("name") or ""),
                      "app": str(data.get("app") or ""), "started": data.get("started")})
    return found


class Job:
    """A live notification for one task; call `update` as it progresses. While
    it runs it registers itself in the session's registry, so the power menu
    knows it would cut a job."""

    def __init__(self, name: str, app: str = DEFAULT_APP, icon: str = DEFAULT_ICON, total: int | None = None,
                 notifier=None, language: str | None = None, clock=time.monotonic,
                 registry: Path | None = None):
        self.name = name
        self.app = app
        self.icon = icon
        self.total = total
        self.done = 0
        self.notifier = notifier or Notifier(app=app, icon=icon)
        self.language = language
        self.clock = clock
        self.first = clock()
        self.started_at = 0.0
        self.nid: int | None = None
        self.state = "idle"
        self.registry_dir = registry
        self.registry: Path | None = None

    def _say(self, key: str, *values) -> str:
        return t(key, *values, language=self.language)

    def _hints(self) -> dict:
        found = {STATE_HINT: self.state}
        if self.total and self.total > 0:
            found["value"] = max(0, min(100, int(self.done * 100 / self.total)))
        return found

    def _send(self, summary: str, body: str, actions: list[str]) -> int:
        self.nid = self.notifier.send(summary, body, actions, self._hints(), replace=self.nid or 0)
        return self.nid

    def _running(self, summary: str, body: str) -> int:
        return self._send(summary, body, [CANCEL, self._say("jobs.action.cancel")])

    def start(self) -> int:
        self.first = self.clock()
        self.started_at = time.time()
        self.state = "live"
        self._register()
        return self._running(self.name, self._say("jobs.body.running", _duration(self.clock() - self.first)))

    def _register(self) -> None:
        folder = self.registry_dir or job_dir()
        try:
            folder.mkdir(parents=True, exist_ok=True, mode=0o700)
            path = folder / f"{os.getpid()}-{id(self):x}.json"
            path.write_text(json.dumps({"pid": os.getpid(), "name": self.name, "app": self.app,
                                        "started": self.started_at}), encoding="utf-8")
            os.chmod(path, 0o600)
            self.registry = path
        except OSError:
            self.registry = None

    def _unregister(self) -> None:
        if self.registry is not None:
            self.registry.unlink(missing_ok=True)
            self.registry = None

    def update(self, done: int | None = None, total: int | None = None) -> int:
        if done is not None:
            self.done = max(0, done)
        if total is not None:
            self.total = max(0, total)
        self.state = "live"
        body = self._say("jobs.body.running", _duration(self.clock() - self.first))
        if self.total:
            body += " · " + self._say("downloads.body.of", self.done, self.total)
        return self._running(self.name, body)

    def _end(self, state: str, body: str) -> int:
        self.state = state
        self._unregister()
        return self._send(self.name, body, [])

    def finish(self) -> int:
        return self._end("done", self._say("jobs.body.done", _duration(self.clock() - self.first)))

    def fail(self, message: str = "") -> int:
        body = self._say("jobs.body.failed", _duration(self.clock() - self.first))
        return self._end("failed", f"{body} · {message}" if message else body)

    def cancel(self) -> int:
        return self._end("cancelled", self._say("jobs.body.cancelled", _duration(self.clock() - self.first)))

    def __enter__(self) -> Job:
        self.start()
        return self

    def __exit__(self, kind, value, traceback) -> bool:
        if kind is None:
            self.finish()
        elif issubclass(kind, KeyboardInterrupt):
            self.cancel()
        else:
            self.fail(str(value or ""))
        return False


def _duration(seconds: float) -> str:
    total = max(0, int(seconds))
    minutes, seconds = divmod(total, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours}:{minutes:02d}:{seconds:02d}" if hours else f"{minutes}:{seconds:02d}"


def _session(cancel) -> tuple:
    """(GLib, MainLoop) with Cancel wired to the bar's button, or None when
    there is no session bus to listen on."""
    try:
        import dbus
        import dbus.mainloop.glib
        from gi.repository import GLib
    except ImportError:
        return None
    try:
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SessionBus()
        bus.add_signal_receiver(lambda nid, key: cancel() if str(key) == CANCEL else None,
                                signal_name="ActionInvoked",
                                dbus_interface="org.freedesktop.Notifications",
                                path="/org/freedesktop/Notifications")
    except Exception:
        return None
    return GLib, GLib.MainLoop()


def run(argv: list[str], name: str, app: str = DEFAULT_APP, total: int | None = None,
        notifier=None, language: str | None = None, poll: float = POLL) -> int:
    """Runs a command as a job: live while it runs, Cancel stops it. Returns
    the exit code (130 when cancelled)."""
    if not argv:
        raise ValueError("run needs a command")
    job = Job(name, app=app, total=total, notifier=notifier, language=language)
    job.start()
    process = subprocess.Popen(argv)
    cancelled = {"value": False}

    def cancel(*_args) -> None:
        cancelled["value"] = True
        process.terminate()

    session = _session(cancel)
    if session is None:
        code = process.wait()
    else:
        GLib, loop = session

        def tick() -> bool:
            if process.poll() is not None:
                loop.quit()
            else:
                job.update()
            return True

        GLib.timeout_add(int(poll * 1000), tick)
        loop.run()
        code = process.wait()
    if cancelled["value"]:
        job.cancel()
        return 130
    job.finish() if code == 0 else job.fail(f"exit {code}")
    return code


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args[0] != "run":
        print("usage: jobs run --name NAME [--app APP] [--total N] -- command...", file=sys.stderr)
        return 2
    rest = args[1:]
    name = "Job"
    app = DEFAULT_APP
    total: int | None = None
    command: list[str] = []
    index = 0
    while index < len(rest):
        item = rest[index]
        if item == "--":
            command = rest[index + 1:]
            break
        if item in ("--name", "--app", "--total") and index + 1 < len(rest):
            value = rest[index + 1]
            if item == "--name":
                name = value
            elif item == "--app":
                app = value
            else:
                total = int(value)
            index += 2
            continue
        print(f"jobs: unknown option {item}", file=sys.stderr)
        return 2
    if not command:
        print("jobs: run needs -- followed by a command", file=sys.stderr)
        return 2
    return run(command, name, app=app, total=total)


if __name__ == "__main__":
    raise SystemExit(main())
