"""System and environment diagnostics for Vitrail.

Checks system prerequisites, preferences, systemd user services,
Hyprland display server state, and theme generation cache.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
import platform
import subprocess
import sys
from typing import Any, Callable

from vitrail import prefs


def _os_release_distro() -> str:
    path = Path("/etc/os-release")
    if not path.exists():
        path = Path("/usr/lib/os-release")
    if not path.exists():
        return "unknown"
    try:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if line.startswith("ID="):
                return line.split("=", 1)[1].strip("\"'")
    except OSError:
        pass
    return "unknown"


def _gpu_vendor(run: Callable[..., Any]) -> str:
    try:
        res = run(["lspci"], capture_output=True, text=True, check=False)
        out = (res.stdout or "") + (res.stderr or "")
    except OSError:
        return "unknown"

    gpu_lines = [
        line
        for line in out.splitlines()
        if any(kw in line.lower() for kw in ("vga compatible controller", "3d controller", "display controller"))
    ]
    target_text = "\n".join(gpu_lines).lower() if gpu_lines else out.lower()

    if "nvidia" in target_text:
        return "nvidia"
    # "compatible" contains "ati", so the brand needs a word boundary.
    if re.search(r"\b(amd|ati)\b|advanced micro devices", target_text):
        return "amd"
    if "intel" in target_text:
        return "intel"
    return "unknown"


def collect(
    config_dir: Path | str | None = None,
    run: Callable[..., Any] = subprocess.run,
) -> dict[str, Any]:
    problems: list[str] = []

    # 1. System
    distro = _os_release_distro()
    kernel = platform.release() or os.uname().release
    gpu = _gpu_vendor(run)
    system_info = {
        "distro": distro,
        "kernel": kernel,
        "gpu": gpu,
    }

    # 2. Config
    resolved_config = Path(config_dir) if config_dir is not None else prefs.config_dir()
    config_issues = prefs.validate(resolved_config)
    for issue in config_issues:
        problems.append(f"config: {issue}")
    config_info = {
        "dir": str(resolved_config),
        "issues": config_issues,
    }

    # 3. Services
    services_info: dict[str, str] = {}
    for service in ("vitrail-settings.path", "vitrail-settings.service"):
        try:
            res = run(
                ["systemctl", "--user", "is-active", service],
                capture_output=True,
                text=True,
                check=False,
            )
            state = (res.stdout or "").strip()
            if not state and res.stderr:
                state = res.stderr.strip()
            state = state or "unknown"
        except OSError:
            state = "unknown"
        services_info[service] = state

    # vitrail-settings.path should be active
    if services_info.get("vitrail-settings.path") != "active":
        problems.append(f"service: vitrail-settings.path is {services_info.get('vitrail-settings.path')}")

    # 4. Display
    hl_sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    try:
        res = run(["hyprctl", "version"], capture_output=True, text=True, check=False)
        hyprctl_exit = res.returncode
    except OSError:
        hyprctl_exit = -1

    display_info = {
        "HYPRLAND_INSTANCE_SIGNATURE": hl_sig,
        "hyprctl_exit": hyprctl_exit,
    }
    if not hl_sig:
        problems.append("display: HYPRLAND_INSTANCE_SIGNATURE is not set")
    if hyprctl_exit != 0:
        problems.append(f"display: hyprctl version failed (exit code {hyprctl_exit})")

    # 5. Color
    cache_base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    theme_file = cache_base / "vitrail" / "generated" / "theme.json"
    color_valid = False
    if not theme_file.exists():
        color_info = {
            "path": str(theme_file),
            "exists": False,
            "valid": False,
            "error": "file not found",
        }
        problems.append(f"color: theme file missing ({theme_file})")
    else:
        try:
            json.loads(theme_file.read_text(encoding="utf-8"))
            color_valid = True
            color_info = {
                "path": str(theme_file),
                "exists": True,
                "valid": True,
            }
        except (OSError, json.JSONDecodeError) as e:
            color_info = {
                "path": str(theme_file),
                "exists": True,
                "valid": False,
                "error": str(e),
            }
            problems.append(f"color: theme file invalid JSON ({e})")

    return {
        "system": system_info,
        "config": config_info,
        "services": services_info,
        "display": display_info,
        "color": color_info,
        "problems": problems,
    }


def render(report: dict[str, Any]) -> str:
    lines: list[str] = []

    # Section: system
    sys_info = report.get("system", {})
    lines.append("[system]")
    lines.append(f"  distro: {sys_info.get('distro', 'unknown')}")
    lines.append(f"  kernel: {sys_info.get('kernel', 'unknown')}")
    lines.append(f"  gpu: {sys_info.get('gpu', 'unknown')}")

    # Section: config
    cfg_info = report.get("config", {})
    lines.append("\n[config]")
    lines.append(f"  dir: {cfg_info.get('dir', '')}")
    issues = cfg_info.get("issues", [])
    if issues:
        lines.append("  issues:")
        for issue in issues:
            lines.append(f"    - {issue}")
    else:
        lines.append("  issues: none")

    # Section: services
    svc_info = report.get("services", {})
    lines.append("\n[services]")
    for svc, state in svc_info.items():
        lines.append(f"  {svc}: {state}")

    # Section: display
    disp_info = report.get("display", {})
    lines.append("\n[display]")
    lines.append(f"  HYPRLAND_INSTANCE_SIGNATURE: {disp_info.get('HYPRLAND_INSTANCE_SIGNATURE')}")
    lines.append(f"  hyprctl version exit code: {disp_info.get('hyprctl_exit')}")

    # Section: color
    col_info = report.get("color", {})
    lines.append("\n[color]")
    lines.append(f"  theme.json: {col_info.get('path', '')}")
    lines.append(f"  exists: {col_info.get('exists')}")
    lines.append(f"  valid: {col_info.get('valid')}")
    if col_info.get("error"):
        lines.append(f"  error: {col_info.get('error')}")

    # Section: problems
    problems = report.get("problems", [])
    lines.append("\n[problems]")
    if problems:
        for p in problems:
            lines.append(f"  - {p}")
    else:
        lines.append("  none")

    # Summary line
    if problems:
        lines.append(f"\nSummary: {len(problems)} problem(s) detected.")
    else:
        lines.append("\nSummary: All checks passed.")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    report = collect()
    output = render(report)
    if "--report" in args:
        index = args.index("--report")
        target = Path(args[index + 1]) if index + 1 < len(args) else Path("vitrail-report.txt")
        # The report travels: no user paths in it.
        output = output.replace(str(Path.home()), "~")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(output + "\n", encoding="utf-8")
        print(f"report: {target}")
    else:
        print(output)
    return 1 if report["problems"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
