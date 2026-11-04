"""Every program Vitrail runs is declared in the installer's manifest.

A program the shell, the CLI or a script starts at runtime must come from a
package in `packages/*.txt` (installed by `install.sh`), be part of the base
system, or be an allowlisted external tool. This test scans the sources for
the programs they invoke, so a new `Process { command: ["foo", ...] }` or
`subprocess.run(["foo"])` fails until `foo` is declared (AGENTS.md,
"Dependencies").
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packages"
SCAN = ("bar", "kit", "shell", "lock", "login", "scripts", "vitrail", "bin")
HYPRLAND_CONFIG = ROOT / "dots" / ".config" / "hypr" / "hyprland.lua"

# Programs of the base system (coreutils, util-linux, procps, systemd, shell):
# `base-devel` and the Arch `base` group are always there.
SYSTEM = {
    "sh",
    "bash",
    "env",
    "python3",
    "systemctl",
    "ip",
    "mkdir",
    "mv",
    "cp",
    "rm",
    "cat",
    "printf",
    "echo",
    "dirname",
    "basename",
    "kill",
    "pkill",
    "sleep",
    "date",
    "ln",
    "readlink",
    "mktemp",
    "sort",
    "head",
    "tail",
    "tr",
    "cut",
    "wc",
    "find",
    "grep",
    "sed",
    "awk",
    "paste",
    "test",
    "sudo",
    "git",
    "uname",
    "id",
    "true",
    "false",
    "timedatectl",
    "localectl",
    "sleep",
    "pwd",
    "rfkill",
    "chmod",
    "flock",
    # iputils is in the Arch `base` group: the VPN page's latency probe.
    "ping",
}

# Programs that are not packaged by Vitrail, with the reason.
EXTERNAL = {
    # The VPN module (vpn/) installs it itself, from the Vitrail VPN module.
    "vitrail-vpn",
    # Hyprland's own dialog, replaced by scripts/hyprland-dialog.sh when the
    # bar runs; the real one ships with the hyprland package.
    "hyprland-dialog",
    # Development tools, not needed by the installed desktop: the code graph
    # (graphifyy, from uv) and uv itself (scripts/graphify-refresh.sh).
    "graphify",
    "uv",
}

# Program -> the package that provides it. A program missing here is unknown.
PROVIDED_BY = {
    "hyprctl": "hyprland",
    "hyprlock": "hyprlock",
    "quickshell": "quickshell",
    "qml6": "qt6-declarative",
    "matugen": "matugen",
    "lspci": "pciutils",
    "awww": "awww",
    "awww-daemon": "awww",
    "mpvpaper": "mpvpaper",
    "fc-list": "fontconfig",
    "flatpak": "flatpak",
    "ffmpeg": "ffmpeg",
    "ffprobe": "ffmpeg",
    "magick": "imagemagick",
    "nmcli": "networkmanager",
    "gsettings": "glib2",
    "kitty": "kitty",
    "qalc": "libqalculate",
    "plocate": "plocate",
    "fd": "fd",
    "cliphist": "cliphist",
    "wtype": "wtype",
    "hyprpicker": "hyprpicker",
    "bluetoothctl": "bluez-utils",
    "powerprofilesctl": "power-profiles-daemon",
    "wl-copy": "wl-clipboard",
    "wl-paste": "wl-clipboard",
    "xdg-open": "xdg-utils",
    "xrdb": "xorg-xrdb",
    "xdg-mime": "xdg-utils",
    "wpctl": "wireplumber",
    "playerctl": "playerctl",
    "brightnessctl": "brightnessctl",
    "ddcutil": "ddcutil",
    "grim": "grim",
    "slurp": "slurp",
}

# Shell words that start a command position but are not programs.
SHELL_WORDS = {
    "if",
    "then",
    "else",
    "elif",
    "fi",
    "for",
    "while",
    "until",
    "do",
    "done",
    "case",
    "esac",
    "in",
    "function",
    "return",
    "exit",
    "local",
    "export",
    "readonly",
    "declare",
    "set",
    "unset",
    "shift",
    "source",
    "exec",
    "eval",
    "command",
    "trap",
    "read",
    "cd",
    "wait",
    "break",
    "continue",
    "unlock",
    "mapfile",
    "printf",
    "echo",
    "test",
    "umask",
    "[",
    "[[",
    "!",
    "{",
    "}",
    "(",
    ")",
    "usage",
    "info",
    "warn",
    "die",
    "run",
    "ok",
    "not_ok",
    "flag",
    "read_ini",
    "esac;",
    "fi;",
    "done;",
    "then;",
    "do;",
}

QML_ARRAY = re.compile(
    r"""(?:command\s*[:=]|exec(?:Detached)?\()\s*\[\s*"([^"]+)"\s*(?:,\s*"-c"\s*,\s*"((?:[^"\\]|\\.)*)")?"""
)
JS_RETURN = re.compile(r"""return\s*\[\s*"([^"]+)"\s*(?:,\s*"-c"\s*,\s*"((?:[^"\\]|\\.)*)")?""")
PY_CALL = re.compile(
    r'''\b(?:subprocess\.\w+|_?run|_call|spawn\w*|Popen)\(\s*(?:run\s*,\s*)?\[\s*"([\w.-]+)"|shutil\.which\(\s*"([\w.-]+)"|\b(?:command|cmd)\s*=\s*\[\s*"([\w.-]+)"|\breturn\s*\[\s*"([\w.-]+)"'''
)
LUA_EXEC = re.compile(r"""exec_cmd\(\s*(?:home\s*\.\.\s*)?"((?:[^"\\]|\\.)+)\"""")
COMMAND_V = re.compile(r"\bcommand\s+-v\s+([\w.-]+)")
SEPARATORS = re.compile(r"\|\||&&|[;|&()`]|\$\(|\n")


def command_words(script: str) -> set[str]:
    """First word of every command in a shell string (a heuristic: pipes,
    lists and substitutions split commands)."""
    found: set[str] = set(COMMAND_V.findall(script))
    for part in SEPARATORS.split(re.sub(r"'[^']*'", "''", script)):
        words = part.strip().split()
        while words and re.fullmatch(r"\w+=\S*", words[0]):
            words = words[1:]
        if words and words[0] == "exec":
            words = words[1:]
        if words:
            word = words[0].strip("\"'")
            if re.fullmatch(r"[A-Za-z][A-Za-z0-9.+-]*", word) and word not in SHELL_WORDS:
                found.add(word)
    return found


def qml_programs(text: str) -> set[str]:
    found: set[str] = set()
    for pattern in (QML_ARRAY, JS_RETURN):
        for program, script in pattern.findall(text):
            if program in ("sh", "bash") and script:
                found |= command_words(script.replace('\\"', '"'))
            found.add(program)
    return found


def python_programs(text: str) -> set[str]:
    found = {name for groups in PY_CALL.findall(text) for name in groups if name}
    return found


def shell_programs(text: str) -> set[str]:
    """Commands of a shell script; text inside multi-line quotes is skipped."""
    found: set[str] = set(COMMAND_V.findall(text))
    quoted = False
    heredoc = ""
    functions = set(re.findall(r"(?m)^\s*(?:function\s+)?([\w-]+)\s*\(\)\s*\{", text))
    for line in text.splitlines():
        stripped = line.strip()
        if heredoc:
            heredoc = "" if stripped == heredoc else heredoc
            continue
        if not quoted and (not stripped or stripped.startswith("#")):
            continue
        marker = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", line)
        if marker and not quoted:
            heredoc = marker.group(1)
        if not quoted:
            # `lock) command` is a case branch: its label is not a program.
            found |= command_words(re.sub(r"^[^\s()]+\)\s*", "", stripped)) - functions
        # An odd number of unescaped quotes opens or closes a multi-line string.
        if len(re.findall(r'(?<!\\)"', re.sub(r"'[^']*'", "", line))) % 2:
            quoted = not quoted
    return found


def lua_programs(text: str) -> set[str]:
    found: set[str] = set()
    for command in LUA_EXEC.findall(text):
        found |= command_words(command.replace('\\"', '"'))
        first = command.split()[0] if command.split() else ""
        found.add(first.rsplit("/", 1)[-1])
    return found


def sources() -> list[Path]:
    files: list[Path] = []
    for folder in SCAN:
        for path in sorted((ROOT / folder).rglob("*")):
            parts = path.relative_to(ROOT).parts
            if not path.is_file() or any((ROOT.joinpath(*parts[: i + 1])).is_symlink() for i in range(len(parts))):
                continue
            if "__pycache__" in parts or path.suffix in (".png", ".json", ".svg", ".pyc"):
                continue
            files.append(path)
    return files


def used_programs() -> dict[str, set[str]]:
    """Program -> files that invoke it."""
    used: dict[str, set[str]] = {}
    for path in sources():
        text = path.read_text(encoding="utf-8", errors="ignore")
        if path.suffix in (".qml", ".js"):
            found = qml_programs(text)
        elif path.suffix == ".py":
            found = python_programs(text)
        elif path.suffix == ".sh" or path.parent.name == "bin" or text.startswith("#!/usr/bin/env bash"):
            found = shell_programs(text)
        else:
            continue
        for program in found:
            used.setdefault(program, set()).add(str(path.relative_to(ROOT)))
    for program in lua_programs(HYPRLAND_CONFIG.read_text(encoding="utf-8")):
        used.setdefault(program, set()).add(str(HYPRLAND_CONFIG.relative_to(ROOT)))
    return used


def manifest() -> set[str]:
    names: set[str] = set()
    for path in PACKAGES.glob("*.txt"):
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                names.add(line)
    return names


def is_own(program: str) -> bool:
    """Programs Vitrail installs itself (bin/, ~/.local/bin)."""
    return program.startswith("vitrail-") or (ROOT / "bin" / program).exists()


class ScannerTests(unittest.TestCase):
    def test_qml_command_arrays(self) -> None:
        text = 'Process { command: ["ip", "-j"] }\nx.exec(["python3", "-m", "x"])\nexecDetached(["qalc", "-t"])'
        self.assertEqual(qml_programs(text), {"ip", "python3", "qalc"})

    def test_qml_shell_scripts_are_read(self) -> None:
        text = 'command: ["sh", "-c", "pkill -x foo || foo; mkdir -p \\"$1\\" && cliphist list | wl-copy", "x"]'
        self.assertEqual(qml_programs(text), {"sh", "pkill", "foo", "mkdir", "cliphist", "wl-copy"})

    def test_js_builders(self) -> None:
        self.assertEqual(qml_programs('function f() {\n    return ["qalc", "-t", x]\n}'), {"qalc"})

    def test_python_calls(self) -> None:
        text = 'subprocess.run(["magick", "x"])\n_run(run, ["ffprobe", "-v"])\nshutil.which("hyprctl")\ncommand = ["foo", 1]'
        self.assertEqual(python_programs(text), {"magick", "ffprobe", "hyprctl", "foo"})

    def test_shell_commands_skip_strings_and_comments(self) -> None:
        text = '# nmcli in a comment\nif ! command -v nmcli >/dev/null; then\n  foo "bar\n  baz = 1\n"\nfi\nx=$(wl-paste | grep y)\n'
        found = shell_programs(text)
        self.assertIn("nmcli", found)
        self.assertIn("wl-paste", found)
        self.assertIn("foo", found)
        self.assertNotIn("baz", found)

    def test_lua_exec_commands(self) -> None:
        text = 'hl.exec_cmd("wl-paste --watch cliphist store")\nhl.exec_cmd(home .. "/.local/bin/vitrail-bar")'
        found = lua_programs(text)
        self.assertTrue({"wl-paste", "vitrail-bar"} <= found)


class DependencyTests(unittest.TestCase):
    def test_the_scan_sees_what_the_repo_runs(self) -> None:
        used = used_programs()
        for program in (
            "hyprctl",
            "matugen",
            "ffmpeg",
            "magick",
            "nmcli",
            "gsettings",
            "kitty",
            "hyprlock",
            "vitrail-vpn",
            "qalc",
            "xdg-open",
            "wl-copy",
            "cliphist",
        ):
            with self.subTest(program=program):
                self.assertIn(program, used)

    def test_every_program_is_declared(self) -> None:
        declared = manifest()
        undeclared: dict[str, str] = {}
        for program, files in sorted(used_programs().items()):
            if program in SYSTEM or program in EXTERNAL or is_own(program):
                continue
            package = PROVIDED_BY.get(program)
            if package is None:
                undeclared[program] = f"unknown program, used in {sorted(files)}: add it to PROVIDED_BY"
            elif package not in declared:
                undeclared[program] = f"package {package!r} is not in packages/*.txt (used in {sorted(files)})"
        self.assertEqual(undeclared, {}, "declare these in the installer's manifest")

    def test_every_provider_entry_is_used(self) -> None:
        used = used_programs()
        self.assertEqual(sorted(set(PROVIDED_BY) - set(used)), [], "drop programs Vitrail no longer runs")

    def test_manifest_programs_are_documented(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for package in sorted({PROVIDED_BY[p] for p in used_programs() if p in PROVIDED_BY}):
            with self.subTest(package=package):
                self.assertIn(package, readme, "list it in README.md, Runtime dependencies")


if __name__ == "__main__":
    unittest.main()
