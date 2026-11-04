"""The keyboard shortcuts Hyprland reports, ready for the cheatsheet.

    python3 -m vitrail.binds state

`hyprctl binds -j` lists every bind with a bitfield of modifiers and the key as
Hyprland names it. This module spells the modifiers out (`Super+Shift`) and
writes the key the way a person reads it (`←`, `Enter`, `Volume Up`). Without
Hyprland the state is `{"available": false, "rows": []}`: the cheatsheet says
so instead of showing an empty list that looks broken.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections.abc import Callable

# Hyprland's modifier bits, in the order a shortcut is written.
MODIFIERS = (
    (64, "Super"),
    (4, "Ctrl"),
    (8, "Alt"),
    (1, "Shift"),
    (2, "Caps"),
    (16, "Mod2"),
    (32, "Mod3"),
    (128, "Mod5"),
)

# Keys whose Hyprland name is not what the key says.
KEY_NAMES = {
    "return": "Enter",
    "enter": "Enter",
    "tab": "Tab",
    "space": "Space",
    "escape": "Esc",
    "backspace": "Backspace",
    "delete": "Del",
    "insert": "Ins",
    "home": "Home",
    "end": "End",
    "page_up": "Page Up",
    "page_down": "Page Down",
    "left": "←",
    "right": "→",
    "up": "↑",
    "down": "↓",
    "comma": ",",
    "period": ".",
    "slash": "/",
    "backslash": "\\",
    "minus": "-",
    "equal": "=",
    "semicolon": ";",
    "apostrophe": "'",
    "grave": "`",
    "bracketleft": "[",
    "bracketright": "]",
    "print": "Print",
    "mouse_down": "Wheel Down",
    "mouse_up": "Wheel Up",
    "mouse:272": "Left Click",
    "mouse:273": "Right Click",
    "mouse:274": "Middle Click",
    "XF86AudioRaiseVolume": "Volume Up",
    "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic Mute",
    "XF86AudioPlay": "Play",
    "XF86AudioPause": "Pause",
    "XF86AudioNext": "Next",
    "XF86AudioPrev": "Previous",
    "XF86AudioStop": "Stop",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down",
}


def mods_of(mask: int) -> str:
    """The modifier bitfield as `Super+Ctrl+Alt+Shift` (unknown bits ignored)."""
    return "+".join(name for bit, name in MODIFIERS if mask & bit)


def _mask(value: object) -> int:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return 0


def key_label(key: str) -> str:
    """The key as it reads on the cheatsheet."""
    if key in KEY_NAMES:
        return KEY_NAMES[key]
    if len(key) == 1:
        return key.upper()
    if re.fullmatch(r"[Ff]\d{1,2}", key):
        return key.upper()
    if key.startswith("XF86"):
        # A key this table does not know: its own words are better than nothing.
        return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", key[4:])
    return key


def _load(text: str) -> list | None:
    try:
        data = json.loads(text)
    except (TypeError, json.JSONDecodeError):
        return None
    return data if isinstance(data, list) else None


def _rows(data: list) -> list[dict]:
    rows = []
    for item in data:
        if not isinstance(item, dict):
            continue
        key = key_label(str(item.get("key") or ""))
        if key == "":
            continue
        dispatcher = str(item.get("dispatcher") or "")
        description = str(item.get("description") or "").strip() or dispatcher
        rows.append({
            "mods": mods_of(_mask(item.get("modmask"))),
            "key": key,
            "dispatcher": dispatcher,
            "arg": str(item.get("arg") or ""),
            "description": description,
        })
    return rows


def rows(text: str) -> list[dict]:
    """Hyprland's JSON as `[{mods, key, dispatcher, arg, description}]`."""
    data = _load(text)
    return _rows(data) if data is not None else []


def run_text() -> str:
    """`hyprctl binds -j`, or no text when Hyprland is not there."""
    try:
        answer = subprocess.run(
            ["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5, check=False
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return answer.stdout if answer.returncode == 0 else ""


def state(run: Callable[[], str] | None = None) -> dict:
    """`{available, rows}` for the overlay."""
    try:
        text = (run or run_text)()
    except (OSError, subprocess.SubprocessError):
        return {"available": False, "rows": []}
    data = _load(text)
    if data is None:
        return {"available": False, "rows": []}
    return {"available": True, "rows": _rows(data)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="vitrail-binds", description="the keybind cheatsheet's data")
    parser.add_argument("action", nargs="?", choices=("state",), default="state")
    parser.parse_args(sys.argv[1:] if argv is None else argv)
    print(json.dumps(state()), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
