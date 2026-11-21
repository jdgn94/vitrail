"""The sound card's graph: sinks, sources and the applications playing on them.

    python3 -m vitrail.audio state

`pw-dump` prints the whole PipeWire graph as one JSON document, so the snapshot
is one call and no third-party package. A node's `channelVolumes` are cubic
gains: the cube root is the 0-100 the OSD and `wpctl` show. Default devices come
from PipeWire's `default` metadata (the configured one is the fallback).

A stream's sink is the input node of its links, not a property of the stream, so
the links are grouped by their output node. Each stream keeps the PipeWire node
id (`id`, what `wpctl` changes) and the object serial (`serial`, what `pactl`
calls the sink input and needs to move it).

Actions use `wpctl` for volume and mute. WirePlumber has no way to move a stream,
so a move uses `pactl` (libpulse) and reports itself as unsupported when the
program is missing rather than pretending it worked. Everything that parses or
decides is a pure function; the subprocess lives in one injectable runner.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from collections.abc import Callable

Runner = Callable[[list[str]], "str | None"]

# WirePlumber answers at once; a daemon that hangs must not hold the bar.
READ_TIMEOUT = 5
DEFAULT_SINK = "@DEFAULT_AUDIO_SINK@"
DEFAULT_SOURCE = "@DEFAULT_AUDIO_SOURCE@"
# PipeWire's own names, as they appear in `media.class` and the object types.
NODE = "PipeWire:Interface:Node"
LINK = "PipeWire:Interface:Link"
METADATA = "PipeWire:Interface:Metadata"
SINK_CLASS = "Audio/Sink"
SOURCE_CLASS = "Audio/Source"
STREAM_CLASS = "Stream/Output/Audio"
# The default metadata keys: the live choice first, the saved one as a fallback.
DEFAULT_KEYS = {
    "default.audio.sink": "sink",
    "default.audio.source": "source",
    "default.configured.audio.sink": "configured",
}
VOLUME_TEXT = re.compile(r"Volume:\s*([0-9]+(?:\.[0-9]+)?)")
MUTED_TEXT = re.compile(r"\[MUTED\]", re.IGNORECASE)


def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=READ_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def parse_get_volume(text: str) -> dict:
    """`wpctl get-volume` as `{"volume": 0-100 | None, "muted": bool}`.

    The program prints `Volume: 0.50` and adds `[MUTED]` when the node is
    muted; the number is already the OSD's scale, not PipeWire's cubic gain.
    """
    found = VOLUME_TEXT.search(text or "")
    return {
        "volume": clamp_percent(float(found.group(1)) * 100) if found else None,
        "muted": MUTED_TEXT.search(text or "") is not None,
    }


def clamp_percent(value: float) -> int:
    """A number on the 0-100 scale, rounded."""
    return max(0, min(100, round(value)))


def level_percent(level: float) -> int:
    """A PipeWire channel volume (a cubic gain) as the OSD's 0-100."""
    if level <= 0:
        return 0
    return clamp_percent(100 * level ** (1.0 / 3.0))


def _props(obj: dict) -> dict:
    info = obj.get("info")
    props = info.get("props") if isinstance(info, dict) else None
    return props if isinstance(props, dict) else {}


def _params(obj: dict) -> dict:
    info = obj.get("info")
    params = info.get("params") if isinstance(info, dict) else None
    return params if isinstance(params, dict) else {}


def _volume_props(obj: dict) -> dict:
    """The first `Props` entry that carries volume or mute; the later ones are routes."""
    entries = _params(obj).get("Props")
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and ({"volume", "mute", "channelVolumes"} & set(entry)):
                return entry
    return {}


def _volume_mute(obj: dict) -> tuple[int, bool]:
    entry = _volume_props(obj)
    level = 1.0
    volumes = entry.get("channelVolumes")
    if isinstance(volumes, list) and volumes:
        numbers = [value for value in volumes if isinstance(value, (int, float)) and not isinstance(value, bool)]
        if numbers:
            level = sum(numbers) / len(numbers)
    elif isinstance(entry.get("volume"), (int, float)) and not isinstance(entry.get("volume"), bool):
        level = float(entry["volume"])
    return level_percent(level), bool(entry.get("mute", False))


def _serial(obj: dict, props: dict) -> object:
    value = props.get("object.serial", obj.get("id"))
    return value if isinstance(value, int) and not isinstance(value, bool) else obj.get("id")


def _device(obj: dict, media_class: str) -> dict | None:
    if obj.get("type") != NODE:
        return None
    props = _props(obj)
    if props.get("media.class") != media_class:
        return None
    name = str(props.get("node.name") or "")
    volume, muted = _volume_mute(obj)
    return {
        "id": obj.get("id"),
        "serial": _serial(obj, props),
        "name": name,
        "description": str(props.get("node.description") or props.get("node.nick") or name),
        "volume": volume,
        "muted": muted,
    }


def _stream(obj: dict) -> dict | None:
    if obj.get("type") != NODE:
        return None
    props = _props(obj)
    if props.get("media.class") != STREAM_CLASS:
        return None
    volume, muted = _volume_mute(obj)
    return {
        "id": obj.get("id"),
        "serial": _serial(obj, props),
        "app": str(
            props.get("application.name") or props.get("application.process.binary") or props.get("node.name") or ""
        ),
        "name": str(props.get("media.name") or props.get("node.description") or props.get("node.name") or ""),
        "icon": str(props.get("application.icon-name") or props.get("application.icon_name") or ""),
        "volume": volume,
        "muted": muted,
        "corked": bool(props.get("pulse.corked", False)),
        "sink": None,
    }


def _metadata_name(value: object) -> str | None:
    """A metadata value as a node name; WirePlumber has used both shapes."""
    if isinstance(value, dict):
        value = value.get("name")
    if isinstance(value, str) and value.startswith("{"):
        try:
            parsed = json.loads(value)
        except ValueError:
            parsed = None
        if isinstance(parsed, dict):
            value = parsed.get("name")
    return value if isinstance(value, str) and value else None


def _default_names(objects: list[dict]) -> dict[str, str]:
    found: dict[str, str] = {}
    for obj in objects:
        if obj.get("type") != METADATA:
            continue
        props = obj.get("props")
        if not isinstance(props, dict) or props.get("metadata.name") != "default":
            continue
        for entry in obj.get("metadata") or []:
            if not isinstance(entry, dict) or entry.get("key") not in DEFAULT_KEYS:
                continue
            name = _metadata_name(entry.get("value"))
            if name and DEFAULT_KEYS[entry["key"]] not in found:
                found[DEFAULT_KEYS[entry["key"]]] = name
    return found


def _sink_targets(objects: list[dict], sinks: list[dict]) -> dict[int, int]:
    """Stream node id -> its sink's node id, from the link objects."""
    ids = {entry["id"] for entry in sinks}
    targets: dict[int, int] = {}
    for obj in objects:
        if obj.get("type") != LINK:
            continue
        info = obj.get("info")
        if not isinstance(info, dict):
            continue
        output, sink = info.get("output-node-id"), info.get("input-node-id")
        if isinstance(output, int) and isinstance(sink, int) and sink in ids:
            targets.setdefault(output, sink)
    return targets


def parse_dump(text: str) -> dict:
    """A `pw-dump` JSON document as the state the popup and the bar read.

    The shape is `defaultSink`, `defaultSource` (a device or null), the `sinks`
    and `sources` lists, the playback `streams`, and `error` (null when the
    graph could be read). A malformed document raises ValueError.
    """
    try:
        data = json.loads(text)
    except ValueError as error:
        raise ValueError("pw-dump did not return JSON") from error
    if not isinstance(data, list):
        raise ValueError("pw-dump did not return a list")
    objects = [obj for obj in data if isinstance(obj, dict)]

    sinks = [entry for obj in objects if (entry := _device(obj, SINK_CLASS)) is not None]
    sources = [entry for obj in objects if (entry := _device(obj, SOURCE_CLASS)) is not None]
    targets = _sink_targets(objects, sinks)
    streams = []
    for obj in objects:
        entry = _stream(obj)
        if entry is None:
            continue
        entry["sink"] = targets.get(entry["id"])
        streams.append(entry)

    defaults = _default_names(objects)
    by_name = {entry["name"]: entry for entry in sinks}
    sources_by_name = {entry["name"]: entry for entry in sources}
    default_sink = by_name.get(defaults.get("sink") or defaults.get("configured") or "")
    default_source = sources_by_name.get(defaults.get("source") or "")
    return {
        "defaultSink": default_sink,
        "defaultSource": default_source,
        "sinks": sinks,
        "sources": sources,
        "streams": streams,
        "error": None,
    }


def _empty(error: str) -> dict:
    return {"defaultSink": None, "defaultSource": None, "sinks": [], "sources": [], "streams": [], "error": error}


def state(run: Runner = run_text) -> dict:
    """The graph as one JSON-able document; a missing or failed `pw-dump` is an
    empty graph with the reason in `error`, never an exception."""
    text = run(["pw-dump"])
    if text is None:
        return _empty("pw-dump is not installed or did not answer (package pipewire)")
    try:
        return parse_dump(text)
    except ValueError as error:
        return _empty(str(error))


def _unsupported(action: str, program: str, package: str) -> dict:
    return {
        "ok": False,
        "action": action,
        "error": f"unsupported: {program} is not installed or did not answer (package {package})",
    }


def set_volume(value: float, *, target: str = DEFAULT_SINK, delta: bool = False, run: Runner = run_text) -> dict:
    """Set a node's volume on the 0-100 scale, absolutely or by a delta.

    An absolute value is clamped to 0-100; a delta keeps its sign and its
    magnitude is capped at 100. `wpctl --limit 1.0` also stops a delta from
    taking the result past full.
    """
    number = float(value)
    if delta:
        amount = clamp_percent(abs(number))
        argument = f"{amount}%{'+' if number >= 0 else '-'}"
    else:
        amount = clamp_percent(number)
        argument = f"{amount}%"
    command = ["wpctl", "set-volume", "--limit", "1.0", str(target), argument]
    if run(command) is None:
        return _unsupported("set-volume", "wpctl", "wireplumber")
    return {"ok": True, "action": "set-volume", "target": str(target), "value": amount}


def toggle_mute(*, target: str = DEFAULT_SINK, run: Runner = run_text) -> dict:
    """Toggle the mute of the default sink, the default source or an id."""
    command = ["wpctl", "set-mute", str(target), "toggle"]
    if run(command) is None:
        return _unsupported("set-mute", "wpctl", "wireplumber")
    return {"ok": True, "action": "set-mute", "target": str(target)}


def move_stream(stream: int, sink: str, *, run: Runner = run_text) -> dict:
    """Move a playback stream to a sink; `stream` is the stream's `serial`.

    `pactl` names a sink input by its object serial and a sink by its node
    name, which are the `serial` and `name` fields of the snapshot.
    """
    command = ["pactl", "move-sink-input", str(stream), str(sink)]
    if run(command) is None:
        return _unsupported("move-stream", "pactl", "libpulse")
    return {"ok": True, "action": "move-stream", "stream": stream, "sink": str(sink)}


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        data = state(run)
        if data["error"] is not None:
            print(f"audio: {data['error']}", file=sys.stderr)
            return 1
        print(json.dumps(data, separators=(",", ":")))
        return 0
    print("usage: audio state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
