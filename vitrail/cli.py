"""Runtime theming: command line entry point for Vitrail."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from vitrail import (
    brightness,
    clipboard,
    colors,
    doctor,
    plugins,
    prefs,
    safe_mode,
    style,
    system_theme,
    snapshot,
    update,
    welcome,
    apps,
    vpndoc,
    wallpaper,
    wallpaperd,
)


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
    theme.add_argument("--reload", action="store_true", help="reload Hyprland when done")

    style_parser = sub.add_parser("style", help="export or import a style file")
    style_actions = style_parser.add_subparsers(dest="style_action")
    export = style_actions.add_parser("export", help="write the current style")
    export.add_argument("--out", required=True, help="output .json path")
    import_ = style_actions.add_parser("import", help="apply a style file")
    import_.add_argument("path", help="style .json path")
    style_actions.add_parser("show", help="print the current style")

    paper = sub.add_parser("wallpaper", help="theme the wallpaper or rotate to the next one")
    paper.add_argument("action", choices=("apply", "next", "sync", "import", "show", "stop", "status"))
    paper.add_argument("paths", nargs="*", help="import: files or folders to add")
    paper.add_argument("--force", action="store_true", help="apply: extract even if unchanged")

    mode = sub.add_parser("theme", help="apply light or dark to GTK, Qt and Hyprland")
    mode.add_argument("action", choices=("apply",))
    mode.add_argument("--mode", choices=("dark", "light"), required=True)

    sub.add_parser("version", help="print the version and how it was installed")

    welcome_parser = sub.add_parser("welcome", help="first run: wallpaper, palette, window")
    welcome_parser.add_argument("--no-open", action="store_true", help="do not open the window")

    snapshots = sub.add_parser("snapshot", help="filesystem snapshots before an update")
    snapshots.add_argument("action", choices=("create", "list"))
    snapshots.add_argument("label", nargs="?", default="")

    updater = sub.add_parser("update", help="update the installed checkout from its branch")
    updater.add_argument("--check", action="store_true", help="only report the commits")
    updater.add_argument("--force", action="store_true", help="discard local changes")
    updater.add_argument("--dry-run", action="store_true", help="show the installer's plan")
    updater.add_argument("--no-snapshot", action="store_true", help="do not snapshot first")
    updater.add_argument(
        "--require-snapshot", action="store_true", help="refuse to update when no snapshot can be taken"
    )

    setter = sub.add_parser("set", help="change one setting (appearance, surfaceStyle)")
    setter.add_argument("key", choices=tuple(prefs.CHOICES))
    setter.add_argument("value")

    sub.add_parser("migrate", help="split a legacy settings.ini into one file per area")

    sub.add_parser("doctor", help="check the system, the services and the preference files")

    safe = sub.add_parser("safe-mode", help="start a minimal session when the config is broken")
    safe.add_argument("action", nargs="?", choices=("status", "enter", "exit", "session"), default="status")

    config = sub.add_parser("config", help="check the preference files")
    config_actions = config.add_subparsers(dest="config_action")
    config_actions.add_parser("validate", help="report unknown, misplaced or future keys")
    config_actions.add_parser("path", help="print the preference folder")
    config_set = config_actions.add_parser("set", help="write one preference key")
    config_set.add_argument("key")
    config_set.add_argument("value")

    clip = sub.add_parser("clipboard", help="the clipboard store")
    clip_actions = clip.add_subparsers(dest="clipboard_action")
    clip_actions.add_parser("apply", help="write the history size into cliphist")

    light = sub.add_parser("brightness", help="list the monitors the OSD can dim, as JSON")
    light.add_argument("action", choices=("list",))

    plugin_parser = sub.add_parser("plugins", help="list or lock plugins")
    plugin_parser.add_argument("action", nargs="?", choices=("index", "lock"), default="index")
    return parser


def _colors(args: argparse.Namespace) -> int:
    out_dir = Path(args.out).expanduser() if args.out else colors.cache_dir() / "generated"
    try:
        image = colors.fetch_image(args.image)
    except (OSError, ValueError) as error:
        _say(f"Could not obtain the image: {error}")
        return 1

    _say(f"Image: {image}")
    try:
        theme, written = colors.write_theme(image, out_dir, args.scheme, args.mode, args.contrast, args.prefer)
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
    settings = prefs.config_dir()
    if args.action == "sync":
        imported, removed = wallpaper.sync(settings)
        _say(f"Wallpapers: {len(imported)} imported, {len(removed)} removed")
        return 0
    if args.action == "import":
        folders = wallpaper.ensure_folders(wallpaper.library(prefs.read_prefs(settings), settings))
        added = wallpaper.import_paths(folders, [Path(path).expanduser() for path in args.paths], say=_say)
        for path in added:
            _say(f"  {path}")
        _say(f"Wallpapers: {len(added)} imported")
        return 0
    if args.action == "next":
        chosen = wallpaper.advance(settings)
        _say(f"Wallpaper: {chosen}" if chosen else "Wallpaper: nothing to rotate")
        return 0
    cache = colors.cache_dir()
    if args.action == "show":
        path = prefs.read_prefs(settings).get("wallpaper", "")
        if not path:
            _say("Wallpaper: none selected")
            return 1
        try:
            state = wallpaperd.show(path, cache)
        except (ValueError, OSError, subprocess.CalledProcessError) as error:
            _say(f"Could not display the wallpaper: {error}")
            return 1
        wallpaper.apply(settings, cache, force=True)
        _say(f"Wallpaper: {path} ({state['engine']})")
        return 0
    if args.action == "stop":
        wallpaperd.stop(cache)
        _say("Wallpaper: daemons stopped")
        return 0
    if args.action == "status":
        state = wallpaperd.read_state(cache)
        _say(json.dumps(state) if state else "Wallpaper: nothing displayed")
        return 0
    try:
        themed = wallpaper.apply(settings, colors.cache_dir(), force=args.force)
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
    apps.apply(args.mode, generated, cache=colors.cache_dir())
    _say(f"System theme: {args.mode}")
    return 0


def _set(args: argparse.Namespace) -> int:
    try:
        prefs.set_pref(args.key, args.value)
    except ValueError as error:
        _say(str(error))
        return 1
    _say(f"{args.key} = {args.value}")
    return 0


def _migrate(args: argparse.Namespace) -> int:
    config = prefs.config_dir()
    if prefs.migrate(config):
        _say("Settings split into one file per area (backup: settings.ini.before-split)")
    if vpndoc.migrate(config):
        _say("VPN settings moved to the private vitrail-vpn folder")
    return 0


def _safe_mode(args: argparse.Namespace) -> int:
    directory = prefs.config_dir()
    action = args.action or "status"
    if action == "enter":
        path = safe_mode.enter(directory)
        _say(f"Safe mode armed: {path}")
        _say("Log out, then run: vitrail safe-mode session")
        return 0
    if action == "exit":
        _say("Safe mode disabled" if safe_mode.exit(directory) else "Safe mode was not armed")
        return 0
    if action == "session":
        safe_mode.run_session()
        return 0
    errors = safe_mode.config_errors()
    _say(f"Safe mode: {'armed' if safe_mode.is_active(directory) else 'off'}")
    if errors:
        _say(f"Hyprland reports {len(errors)} config error(s):")
        for error in errors[:10]:
            _say(f"  - {error}")
        _say("Run: vitrail safe-mode enter")
        return 1
    _say("Hyprland config: no errors")
    return 0


def _clipboard(args: argparse.Namespace) -> int:
    values = prefs.read_prefs(prefs.config_dir())
    size = int(values.get("clipboardMax") or clipboard.DEFAULT_MAX)
    path = clipboard.apply(size)
    _say(f"{path}: -max-items {size}")
    return 0


def _config(args: argparse.Namespace) -> int:
    directory = prefs.config_dir()
    if (args.config_action or "validate") == "path":
        _say(str(directory))
        return 0
    if args.config_action == "set":
        try:
            prefs.write_pref(directory, args.key, args.value)
        except ValueError as error:
            _say(str(error))
            return 2
        if args.key == "clipboardMax":
            clipboard.apply(int(args.value))
        return 0
    issues = prefs.validate(directory)
    if not issues:
        _say(f"{directory}: schema {prefs.SCHEMA}, no problems")
        return 0
    for issue in issues:
        _say(f"- {issue}")
    return 1


def _brightness(args: argparse.Namespace) -> int:
    _say(json.dumps(brightness.collect()))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    if args.command is None:
        parser.print_help()
        return 0
    if args.command == "colors":
        return _colors(args)
    if args.command == "clipboard":
        return _clipboard(args)
    if args.command == "style":
        return _style(args)
    if args.command == "wallpaper":
        return _wallpaper(args)
    if args.command == "welcome":
        return welcome.main(["--no-open"] if args.no_open else [])
    if args.command == "snapshot":
        return snapshot.main([args.action] + ([args.label] if args.label else []))
    if args.command == "version":
        return update.version_command()
    if args.command == "update":
        return update.command(args)
    if args.command == "theme":
        return _theme(args)
    if args.command == "set":
        return _set(args)
    if args.command == "migrate":
        return _migrate(args)
    if args.command == "safe-mode":
        return _safe_mode(args)
    if args.command == "doctor":
        return doctor.main([])
    if args.command == "config":
        return _config(args)
    if args.command == "brightness":
        return _brightness(args)
    if args.command == "plugins":
        return plugins.main([args.action])
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
