"""The first run: a wallpaper, a palette and the window to change them."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from . import prefs

SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}
REPO = Path(__file__).resolve().parent.parent


def first_wallpaper(assets: Path) -> str:
    try:
        candidates = sorted(path for path in assets.iterdir() if path.is_file() and path.suffix.lower() in SUFFIXES)
    except OSError:
        return ""
    return str(candidates[0]) if candidates else ""


def _spawn(argv: list[str]) -> None:
    try:
        subprocess.Popen(
            argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, start_new_session=True
        )
    except OSError:
        pass


def run(assets: Path | None = None, config: Path | None = None, open_window: bool = True, spawn=_spawn) -> dict:
    config = config or prefs.config_dir()
    assets = assets or (REPO / "assets" / "wallpapers")
    values = prefs.read_prefs(config)
    current = values.get("wallpaper") or ""
    chosen = current or first_wallpaper(assets)
    if not chosen:
        return {"error": "no wallpaper to offer"}
    applied = False
    if not current:
        prefs.write_pref(config, "wallpaper", chosen)
        _apply(sys.executable)
        applied = True
    if open_window:
        spawn(["vitrail-settings", "--category", "appearance"])
    return {"wallpaper": chosen, "applied": applied}


def _apply(python: str) -> None:
    try:
        subprocess.run([python, "-m", "vitrail.cli", "wallpaper", "apply"], capture_output=True, check=False)
    except OSError:
        pass


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    result = run(open_window="--no-open" not in args)
    if "error" in result:
        print(result["error"], file=sys.stderr)
        return 1
    print(f"wallpaper: {result['wallpaper']}")
    print("Next: the Appearance page for the theme, Fonts & icons for the type,")
    print("Bar for the edge and the panels. `vitrail doctor` reports the system.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
