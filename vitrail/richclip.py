"""The styled variant of copied text, kept beside cliphist.

cliphist stores what `wl-paste --type text` gives: the plain text. When the
source also offers `text/html` (a browser, an editor, an office suite), the
watcher keeps that variant here, keyed by the SHA-256 of the plain bytes, so
any entry of the history finds its style again from its own content, however
the entry got its id and however often the same text was copied:

    $XDG_CACHE_HOME/vitrail/clipboard/<sha256>.html    (0600, folder 0700)

    wl-paste --watch vitrail clipboard store    # on every change
    vitrail clipboard preview <id>              # JSON for the hover card
    vitrail clipboard copy <id> [--trim]        # re-copy, both types at once
    vitrail clipboard forget                    # stdin: the text of a deleted entry
    vitrail clipboard prune | clear

The stored HTML is the original (it is what is offered again on a paste); it is
only ever shown after `sanitize`. `wl-copy` offers one type, so a styled
re-copy is served by a small GTK 4 helper (`serve`) that owns the clipboard
with text and HTML together and exits when something else takes it over.
"""

from __future__ import annotations

import hashlib
import html
import json
import os
import re
import subprocess
import sys
import threading
import time
from html.parser import HTMLParser
from pathlib import Path
from typing import Callable

Runner = Callable[[list[str]], bytes | None]

MAX_HTML = 1_048_576
MAX_FILES = 500
MAX_PREVIEW_TEXT = 20_000
MAX_PREVIEW_HTML = 200_000
# A copy younger than this is never pruned: its history entry may not exist yet.
GRACE = 60
# How long the helper has to take the clipboard before the plain copy is used.
SERVE_WAIT = 3.0

# --- the store -----------------------------------------------------------------


def store_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "vitrail" / "clipboard"


def key(plain: str | bytes) -> str:
    """The name of a text's variant: the SHA-256 of its bytes, as cliphist keeps them."""
    raw = plain if isinstance(plain, bytes) else plain.encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def path_for(plain: str | bytes, directory: Path | None = None) -> Path:
    return (directory or store_dir()) / f"{key(plain)}.html"


def _private(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(directory, 0o700)


def save(plain: str | bytes, markup: str, directory: Path | None = None) -> Path | None:
    """Keeps the original HTML of a text (the newest wins); None when it is too big."""
    data = markup.encode("utf-8")
    if not data or len(data) > MAX_HTML:
        return None
    folder = directory or store_dir()
    _private(folder)
    path = path_for(plain, folder)
    partial = path.with_suffix(".part")
    descriptor = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        os.fchmod(handle.fileno(), 0o600)
        handle.write(data)
    os.replace(partial, path)
    _limit(folder)
    return path


def _limit(folder: Path) -> None:
    """At most MAX_FILES variants: the oldest go first."""
    files = sorted(folder.glob("*.html"), key=lambda one: one.stat().st_mtime)
    for old in files[: max(0, len(files) - MAX_FILES)]:
        old.unlink(missing_ok=True)


def load(plain: str | bytes, directory: Path | None = None) -> str | None:
    try:
        return path_for(plain, directory).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def forget(plain: str | bytes, directory: Path | None = None) -> None:
    path_for(plain, directory).unlink(missing_ok=True)


def clear(directory: Path | None = None) -> None:
    for one in (directory or store_dir()).glob("*.html"):
        one.unlink(missing_ok=True)


def prune(keep: set[str] | None, directory: Path | None = None, now: float | None = None) -> int:
    """Drops the variants whose text the history no longer has; returns how many.

    `keep` None (the history could not be read) drops nothing.
    """
    if keep is None:
        return 0
    moment = time.time() if now is None else now
    removed = 0
    for one in (directory or store_dir()).glob("*.html"):
        if one.stem in keep or moment - one.stat().st_mtime < GRACE:
            continue
        one.unlink(missing_ok=True)
        removed += 1
    return removed


def enabled(values: dict) -> bool:
    """The `clipboardRich` preference (on unless it says otherwise)."""
    return str(values.get("clipboardRich") or "true").strip().lower() not in ("false", "0", "no", "off")


def run_raw(argv: list[str]) -> bytes | None:
    try:
        found = subprocess.run(argv, capture_output=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def history_keys(run: Runner = run_raw) -> set[str] | None:
    """The keys of every text cliphist holds (images are skipped); None if unreadable."""
    listing = run(["cliphist", "list"])
    if listing is None:
        return None
    keys: set[str] = set()
    for line in listing.decode("utf-8", errors="replace").splitlines():
        number, _, preview = line.partition("\t")
        if not number or preview.startswith("[[ binary data"):
            continue
        data = run(["cliphist", "decode", number])
        if data is not None:
            keys.add(key(data))
    return keys


# --- what the watcher stores ---------------------------------------------------


def capture(run: Runner = run_raw, directory: Path | None = None, enabled: bool = True) -> bool:
    """Called when the clipboard changes: keeps its HTML beside its text.

    Only when the source offers both; never for a password manager's copy; and
    only if the clipboard did not change while it was being read.
    """
    if not enabled:
        return False
    listing = run(["wl-paste", "--list-types"])
    if listing is None:
        return False
    types = listing.decode("utf-8", errors="replace").split()
    if "x-kde-passwordManagerHint" in types:
        return False
    markup_type = next((one for one in types if one == "text/html" or one.startswith("text/html;")), None)
    if markup_type is None:
        return False
    first = run(["wl-paste", "--no-newline", "--type", "text"])
    markup = run(["wl-paste", "--no-newline", "--type", markup_type])
    again = run(["wl-paste", "--no-newline", "--type", "text"])
    if not first or markup is None or first != again:
        return False
    return save(first, markup.decode("utf-8", errors="replace"), directory) is not None


# --- sanitizing ----------------------------------------------------------------

KEEP = {
    "a", "abbr", "b", "big", "blockquote", "br", "caption", "center", "cite", "code", "dd", "del", "div", "dl",
    "dt", "em", "font", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "i", "ins", "kbd", "li", "mark", "ol", "p",
    "pre", "q", "s", "samp", "small", "span", "strike", "strong", "sub", "sup", "table", "tbody", "td", "tfoot",
    "th", "thead", "tr", "tt", "u", "ul", "var",
}  # fmt: skip
VOID = {"br", "hr"}
# Dropped with everything inside (and the ones with no inside: img, meta, link, input).
DROP = {
    "applet", "audio", "base", "button", "canvas", "embed", "form", "frame", "frameset", "head", "iframe", "img",
    "input", "link", "math", "meta", "noscript", "object", "option", "script", "select", "style", "svg",
    "template", "textarea", "title", "video",
}  # fmt: skip
NO_INSIDE = {"base", "embed", "img", "input", "link", "meta"}
ATTRIBUTES = {
    "a": {"href"},
    "font": {"color", "face", "size"},
    "td": {"colspan", "rowspan", "align"},
    "th": {"colspan", "rowspan", "align"},
    "ol": {"start", "type"},
}
# What the preview can draw; anything else in `style` is dropped.
PROPERTIES = {
    "background-color", "color", "font-family", "font-size", "font-style", "font-weight", "letter-spacing",
    "line-height", "list-style-type", "margin-bottom", "margin-left", "margin-right", "margin-top",
    "text-align", "text-decoration", "text-indent", "white-space", "word-spacing",
}  # fmt: skip
SAFE_VALUE = re.compile(r"[A-Za-z0-9\s.,#%()'\"\-+/_]*")
WEB = re.compile(r"(?:https?://|mailto:)[^\s\"'<>]*", re.I)


def _style(value: str) -> str:
    """The drawable, harmless declarations of a style attribute, in a normal form."""
    kept = []
    for declaration in value.split(";"):
        name, _, setting = declaration.partition(":")
        name = name.strip().lower()
        setting = " ".join(setting.replace("!important", "").split()).replace('"', "'")
        low = setting.lower()
        if name not in PROPERTIES or not setting or not SAFE_VALUE.fullmatch(setting):
            continue
        if any(bad in low for bad in ("url(", "expression", "javascript", "@import", "image-set")):
            continue
        kept.append(f"{name}: {setting}")
    return "; ".join(kept)


class _Cleaner(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.out: list[str] = []
        self.open: list[str] = []
        self.dropping: list[str] = []

    def _attributes(self, tag: str, pairs: list[tuple[str, str | None]]) -> str:
        found = []
        for name, value in pairs:
            name = name.lower()
            value = value or ""
            if name == "style":
                value = _style(value)
            elif name not in ATTRIBUTES.get(tag, set()):
                continue
            elif name == "href" and not WEB.fullmatch(value.strip()):
                continue
            if value != "" or name not in ("style", "href"):
                found.append(f' {name}="{html.escape(value, quote=True)}"')
        return "".join(found)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if self.dropping:
            if tag in DROP and tag not in NO_INSIDE:
                self.dropping.append(tag)
            return
        if tag in DROP:
            if tag not in NO_INSIDE:
                self.dropping.append(tag)
            return
        if tag not in KEEP:
            return
        self.out.append(f"<{tag}{self._attributes(tag, attrs)}>")
        if tag not in VOID:
            self.open.append(tag)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in KEEP and tag in VOID and not self.dropping:
            self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag: str) -> None:
        if self.dropping:
            if tag == self.dropping[-1]:
                self.dropping.pop()
            return
        if tag in self.open:
            while self.open:
                last = self.open.pop()
                self.out.append(f"</{last}>")
                if last == tag:
                    break

    def handle_data(self, data: str) -> None:
        if not self.dropping:
            self.out.append(html.escape(data, quote=False))

    def result(self) -> str:
        while self.open:
            self.out.append(f"</{self.open.pop()}>")
        return "".join(self.out)


def sanitize(markup: str) -> str:
    """HTML that is safe to draw: an allow-list of tags, attributes and CSS.

    No script, no style sheet, no image, no frame, no event handler, no URL in
    CSS, links only to web addresses; text is escaped and tags are balanced.
    """
    cleaner = _Cleaner()
    cleaner.feed(markup or "")
    cleaner.close()
    return cleaner.result()


# --- preview and re-copy -------------------------------------------------------


def _as_text(data: bytes) -> str | None:
    if b"\x00" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def preview(data: bytes, directory: Path | None = None) -> dict:
    """What the hover card shows for an entry's bytes: {"kind", "text", "html"}."""
    text = _as_text(data)
    if text is None:
        return {"kind": "binary"}
    markup = load(data, directory)
    styled = sanitize(markup) if markup else ""
    if len(styled) > MAX_PREVIEW_HTML or not re.sub(r"<[^>]*>", "", styled).strip():
        styled = ""
    return {"kind": "text", "text": text[:MAX_PREVIEW_TEXT], "html": styled}


def offered_types() -> dict[str, list[str]]:
    """The types a styled copy offers: the text under every name pasting code asks for."""
    return {
        "plain": ["text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "TEXT", "STRING"],
        "html": ["text/html"],
    }


def _kill(child) -> None:
    try:
        child.kill()
    except (OSError, AttributeError):
        pass


def launch(payload: dict, popen=subprocess.Popen, wait: float = SERVE_WAIT) -> bool:
    """Starts the helper and waits until it owns the clipboard (it says "ok")."""
    try:
        child = popen(
            [sys.executable, "-m", "vitrail.richclip", "serve"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            env={**os.environ, "GDK_BACKEND": "wayland"},
        )
        child.stdin.write(json.dumps(payload).encode("utf-8"))
        child.stdin.close()
    except OSError:
        return False
    guard = threading.Timer(wait, lambda: _kill(child))
    guard.daemon = True
    guard.start()
    try:
        answer = child.stdout.readline()
    finally:
        guard.cancel()
    if answer.strip() != b"ok":
        _kill(child)
        return False
    return True


def plain_copy(data: bytes) -> bool:
    """`wl-copy` with the bytes; its output is not piped back (it forks and keeps the pipes)."""
    try:
        found = subprocess.run(
            ["wl-copy"], input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )
    except OSError:
        return False
    return found.returncode == 0


def copy(
    data: bytes,
    directory: Path | None = None,
    enabled: bool = True,
    trim: bool = False,
    serve: Callable[[dict], bool] = launch,
    plain_copy: Callable[[bytes], bool] = plain_copy,
) -> str:
    """Puts an entry on the clipboard: "rich" (text and HTML at once) or "plain".

    The terminal form (`trim`) is always plain, without trailing newlines, so a
    paste does not submit the command. Images and binary data go as they are.
    """
    if trim:
        plain_copy(data.rstrip(b"\n"))
        return "plain"
    text = _as_text(data)
    markup = load(data, directory) if enabled and text is not None else None
    if markup and text is not None and serve({"plain": text, "html": markup}):
        return "rich"
    plain_copy(data)
    return "plain"


# --- the helper that owns the clipboard ----------------------------------------


def serve() -> int:
    """GTK 4: owns the clipboard with text and HTML together until it is replaced."""
    payload = json.loads(sys.stdin.read())
    import gi

    gi.require_version("Gdk", "4.0")
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gdk, GLib, Gtk

    Gtk.init()
    display = Gdk.Display.get_default()
    if display is None:
        return 1
    types = offered_types()
    text = GLib.Bytes.new(payload["plain"].encode("utf-8"))
    markup = GLib.Bytes.new(payload["html"].encode("utf-8"))
    parts = [Gdk.ContentProvider.new_for_bytes(one, text) for one in types["plain"]]
    parts += [Gdk.ContentProvider.new_for_bytes(one, markup) for one in types["html"]]
    clipboard = display.get_clipboard()
    loop = GLib.MainLoop()

    def lost(board) -> None:
        if not board.is_local():
            loop.quit()

    clipboard.connect("changed", lost)
    if not clipboard.set_content(Gdk.ContentProvider.new_union(parts)):
        return 1
    sys.stdout.write("ok\n")
    sys.stdout.flush()
    loop.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(serve() if sys.argv[1:] == ["serve"] else 2)
