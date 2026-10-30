"""Runtime theming: command line entry point for Vitrail."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from vitrail import colors, plugins, style, system_theme, wallpaper


def _say(message: str = "") -> None:
    print(message, flush=True)


def _run(cmd: list[str]) -> bool:
    _say(f"  $ {' '.join(cmd)}")
    try:
        return subprocess.run(cmd).returncode == 0
    except OSError as error:
        _say(f"  ! {error}")
        return False


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vitrail",
        description="Vitrail runtime theming for Wayland on Arch Linux.",
        epilog="To install Vitrail, run ./install.sh",
    )
    sub = parser.add_subparsers(dest="command")

    theme = sub.add_parser("colors", help="generate a theme from an image")
    theme.add_argument("--image", required=True, help="local path or URL")
    theme.add_argument("--scheme", choices=tuple(colors.SCHEMES), default="tonal")
    theme.add_argument("--mode", choices=colors.MODES, default="dark")
    theme.add_argument("--contrast", type=float, default=0.0)
    theme.add_argument("--prefer", choices=colors.PREFERS, default="saturation")
    theme.add_argument("--out", default=None, help="output directory")
    theme.add_argument(
        "--reload", action="store_true", help="reload Hyprland when done"
    )

    style_parser = sub.add_parser("style", help="export or import a style file")
    style_actions = style_parser.add_subparsers(dest="style_action")
    export = style_actions.add_parser("export", help="write the current style")
    export.add_argument("--out", required=True, help="output .json path")
    import_ = style_actions.add_parser("import", help="apply a style file")
    import_.add_argument("path", help="style .json path")
    style_actions.add_parser("show", help="print the current style")

    paper = sub.add_parser("wallpaper", help="theme the wallpaper or rotate to the next one")
    paper.add_argument("action", choices=("apply", "next"))

    mode = sub.add_parser("theme", help="apply light or dark to GTK, Qt and Hyprland")
    mode.add_argument("action", choices=("apply",))
    mode.add_argument("--mode", choices=("dark", "light"), required=True)

    plugin_parser = sub.add_parser("plugins", help="list or lock plugins")
    plugin_parser.add_argument(
        "action", nargs="?", choices=("index", "lock"), default="index"
    )
    return parser


def _colors(args: argparse.Namespace) -> int:
    out_dir = (
        Path(args.out).expanduser() if args.out else colors.cache_dir() / "generated"
    )
    try:
        image = colors.fetch_image(args.image)
    except (OSError, ValueError) as error:
        _say(f"Could not obtain the image: {error}")
        return 1

    _say(f"Image: {image}")
    try:
        theme, written = colors.write_theme(
            image, out_dir, args.scheme, args.mode, args.contrast, args.prefer
        )
    except colors.ColorExtractionError as error:
        _say(f"Could not extract colors: {error}")
        return 1

    _say(f"Scheme {args.scheme} · mode {'dark' if theme.is_dark else 'light'}")
    for role in ("primary", "surface", "surface_container_high", "on_surface"):
        _say(f"  {role}: {theme.colors[role]}")
    _say("")
    _say(f"{len(written)} file(s) written to {out_dir}")
    for path in written:
        _say(f"  {path.relative_to(out_dir)}")

    commands = colors.reload_commands() if args.reload else []
    if commands:
        _say("")
        for command in commands:
            _run(command)
    else:
        _say("")
        _say("To apply it live: hyprctl reload")
    return 0


def _style(args: argparse.Namespace) -> int:
    action = args.style_action or "show"
    if action == "export":
        current = style.read_style()
        target = Path(args.out).expanduser()
        style.dump(current, target)
        _say(f"Style written to {target}")
        return 0
    if action == "import":
        try:
            data = style.load(Path(args.path).expanduser())
        except (OSError, ValueError) as error:
            _say(f"Could not read the style: {error}")
            return 1
        changed = style.write_style(data)
        _say(f"Applied {len(changed)} value(s) from {args.path}")
        return 0
    _say(json.dumps(style.read_style(), indent=2))
    return 0


def _config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def _wallpaper(args: argparse.Namespace) -> int:
    settings = _config_home() / "vitrail" / "settings.ini"
    if args.action == "next":
        chosen = wallpaper.advance(settings)
        _say(f"Wallpaper: {chosen}" if chosen else "Wallpaper: nothing to rotate")
        return 0
    try:
        themed = wallpaper.apply(settings, colors.cache_dir(), Path.home())
    except (colors.ColorExtractionError, OSError, subprocess.CalledProcessError) as error:
        _say(f"Could not theme the wallpaper: {error}")
        return 1
    _say(f"Wallpaper: {themed} (palette regenerated)" if themed else "Wallpaper: unchanged")
    return 0


def _theme(args: argparse.Namespace) -> int:
    generated = colors.cache_dir() / "generated"
    if not (generated / f"theme-{args.mode}.json").exists():
        _say("No palette yet: pick a wallpaper first.")
        return 1
    system_theme.apply(args.mode, generated, _config_home())
    _say(f"System theme: {args.mode}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    if args.command is None:
        parser.print_help()
        return 0
    if args.command == "colors":
        return _colors(args)
    if args.command == "style":
        return _style(args)
    if args.command == "wallpaper":
        return _wallpaper(args)
    if args.command == "theme":
        return _theme(args)
    if args.command == "plugins":
        return plugins.main([args.action])
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
