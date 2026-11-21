"""Who is listening, watching or recording: microphone, camera and screen.

    python3 -m vitrail.privacy state [microphone|camera|screen ...]

`pw-dump` prints the whole PipeWire graph as one JSON document, so the snapshot
is one call and no third-party package. Everything that decides is a pure
function of that document; the subprocess lives in one injectable runner.

What counts as a use (a node is only reported while its `info.state` is
`running`, or when it has no state at all):

* microphone: a `Stream/Input/Audio` node, an application's capture stream. A
  stream that reads a sink's monitor (`stream.capture.sink`, or every upstream
  node is an `Audio/Sink`) records what plays, not a microphone, and is left
  out, as is `pw-dump` itself, `wpctl`, the shell and peak meters.
* camera: a `Stream/Input/Video` node that is not fed by a portal screencast.
  A `Video/Source` device alone is a camera that is merely present: only the
  stream consuming it is a use.
* screen: a `Stream/Input/Video` node fed (by a link) from a `Stream/Output/Video`
  or `Video/Source` node owned by the screencast portal. The owner is the
  PipeWire client (or the node's own properties) whose `application.name` or
  `application.process.binary` starts with `xdg-desktop-portal`. Both the portal
  stream and the consumer must be in the graph.

Blind spots: `pw-dump` carries no creation time, so `since` is always null;
a screencast that bypasses PipeWire (X11, `wlr-screencopy`, `grim` loops) is
invisible; a portal that does not name itself in its client properties is not
recognised, so a real screencast then shows up as a camera or not at all; a
sandboxed app that reads the camera through the portal still appears as its own
stream, but under whatever name the portal gave it.

Stopping a use destroys the capture stream node (`pw-cli destroy`); the
application is never killed and may simply reconnect.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from collections.abc import Callable

Runner = Callable[[list[str]], "str | None"]

# PipeWire answers at once; a daemon that hangs must not hold the bar.
READ_TIMEOUT = 5
NODE = "PipeWire:Interface:Node"
CLIENT = "PipeWire:Interface:Client"
LINK = "PipeWire:Interface:Link"
AUDIO_CAPTURE = "Stream/Input/Audio"
VIDEO_CAPTURE = "Stream/Input/Video"
PORTAL_STREAMS = {"Stream/Output/Video", "Video/Source"}
SINK = "Audio/Sink"
KINDS = ("microphone", "camera", "screen")
PORTAL_PREFIX = "xdg-desktop-portal"
# Programs that read the graph or the volume, not people using a device.
IGNORED_APPS = {"pw-dump", "pw-cli", "pw-mon", "pw-top", "pw-metadata", "wpctl", "quickshell"}
PEAK_METER = "peak detect"


def dump_command() -> list[str]:
    return ["pw-dump"]


def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=READ_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def _props(obj: dict) -> dict:
    info = obj.get("info")
    props = info.get("props") if isinstance(info, dict) else None
    return props if isinstance(props, dict) else {}


def _int(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _index(dump: object) -> tuple[dict[int, dict], dict[int, dict], list[tuple[int, int]]]:
    """Nodes and clients by id, and the links as (output node, input node)."""
    nodes: dict[int, dict] = {}
    clients: dict[int, dict] = {}
    links: list[tuple[int, int]] = []
    for obj in dump if isinstance(dump, list) else []:
        if not isinstance(obj, dict):
            continue
        ident = _int(obj.get("id"))
        kind = obj.get("type")
        if kind == NODE and ident is not None:
            nodes[ident] = obj
        elif kind == CLIENT and ident is not None:
            clients[ident] = obj
        elif kind == LINK:
            info = obj.get("info")
            info = info if isinstance(info, dict) else {}
            out, into = _int(info.get("output-node-id")), _int(info.get("input-node-id"))
            if out is not None and into is not None:
                links.append((out, into))
    return nodes, clients, links


def _media_class(node: dict) -> str:
    value = _props(node).get("media.class")
    return value if isinstance(value, str) else ""


def _text(props: dict, key: str) -> str:
    value = props.get(key)
    return value if isinstance(value, str) else ""


def _app(props: dict) -> str:
    return _text(props, "application.name") or _text(props, "application.process.binary") or _text(props, "node.name")


def _running(node: dict) -> bool:
    info = node.get("info")
    state = info.get("state") if isinstance(info, dict) else None
    return state is None or state == "running"


def _ignored(props: dict) -> bool:
    names = {_text(props, "application.name").lower(), _text(props, "application.process.binary").lower()}
    return bool(names & IGNORED_APPS) or _text(props, "media.name").lower() == PEAK_METER


def _is_portal(node: dict, clients: dict[int, dict]) -> bool:
    props = _props(node)
    owner = clients.get(_int(props.get("client.id")) or -1)
    for source in (props, _props(owner) if owner else {}):
        for key in ("application.name", "application.process.binary"):
            if _text(source, key).lower().startswith(PORTAL_PREFIX):
                return True
    return False


def _monitors_a_sink(node: dict, upstream: list[dict]) -> bool:
    flag = _props(node).get("stream.capture.sink")
    if flag is True or flag == "true":
        return True
    return bool(upstream) and all(_media_class(source) == SINK for source in upstream)


def _use(kind: str, node_id: int, node: dict) -> dict:
    props = _props(node)
    return {
        "kind": kind,
        "app": _app(props),
        "label": _text(props, "node.name") or str(node_id),
        "node": node_id,
        "since": None,
    }


def find_uses(dump: object) -> list[dict]:
    """Every use in a `pw-dump` document, microphone first; pure."""
    nodes, clients, links = _index(dump)
    uses: list[dict] = []
    for node_id, node in sorted(nodes.items()):
        media_class = _media_class(node)
        if media_class not in (AUDIO_CAPTURE, VIDEO_CAPTURE) or not _running(node) or _ignored(_props(node)):
            continue
        upstream = [nodes[out] for out, into in links if into == node_id and out in nodes]
        if media_class == AUDIO_CAPTURE:
            if not _monitors_a_sink(node, upstream):
                uses.append(_use("microphone", node_id, node))
            continue
        fed_by_portal = any(
            _media_class(source) in PORTAL_STREAMS and _is_portal(source, clients) for source in upstream
        )
        uses.append(_use("screen" if fed_by_portal else "camera", node_id, node))
    order = {kind: index for index, kind in enumerate(KINDS)}
    return sorted(uses, key=lambda use: (order[use["kind"]], use["app"].lower(), use["node"]))


def state(
    dump_text: str | None = None,
    *,
    watch: tuple[str, ...] | list[str] | None = None,
    runner: Runner = run_text,
) -> dict:
    """The privacy snapshot. `dump_text` skips the runner (the tests); `watch`
    narrows the kinds that count (default: all of them)."""
    watching = {kind: watch is None or kind in watch for kind in KINDS}
    result: dict = {"uses": [], "anyUse": False, "watching": watching, "error": None}
    text = dump_text if dump_text is not None else runner(dump_command())
    if text is None:
        result["error"] = "pw-dump is not available or did not answer"
        return result
    try:
        dump = json.loads(text)
    except ValueError:
        result["error"] = "pw-dump did not print JSON"
        return result
    if not isinstance(dump, list):
        result["error"] = "pw-dump did not print a list"
        return result
    result["uses"] = [use for use in find_uses(dump) if watching[use["kind"]]]
    result["anyUse"] = bool(result["uses"])
    return result


def stop(kind: str, node: object) -> list[str] | None:
    """The command that cuts a use off: destroy its capture stream node.

    Pure: nothing runs here. None for an unknown kind or a node that is not a
    PipeWire id. The application is never killed.
    """
    node_id = _int(node)
    if kind not in KINDS or node_id is None or node_id < 0:
        return None
    return ["pw-cli", "destroy", str(node_id)]


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args[:1] == ["state"] and all(kind in KINDS for kind in args[1:]):
        print(json.dumps(state(watch=args[1:] or None), separators=(",", ":")))
        return 0
    print("usage: privacy state [microphone|camera|screen ...]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
